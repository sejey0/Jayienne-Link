import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mood_message_model.dart';
import '../models/mood_read_model.dart';
import '../services/supabase_mood_service.dart';

class MoodProvider extends ChangeNotifier {
  final SupabaseMoodService _service;
  bool _disposed = false;

  MoodProvider(this._service);

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  final List<MoodMessageModel> _moods = [];
  StreamSubscription<List<MoodMessageModel>>? _moodSubscription;
  StreamSubscription<List<MoodReadModel>>? _readSubscription;
  Timer? _pollingTimer;
  Timer? _markReadTimer;
  bool _isRefreshing = false;

  final Map<String, Set<String>> _readsByMood = {};

  String? _userId;
  String? _coupleId;
  String? _partnerId;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<MoodMessageModel> get moods => List.unmodifiable(_moods);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get canSend =>
      _partnerId != null && _coupleId != null && _userId != null;

  bool isSeenByPartner(String moodMessageId) {
    if (_partnerId == null) return false;
    return _readsByMood[moodMessageId]?.contains(_partnerId) ?? false;
  }

  Future<void> initialize({
    required String userId,
    required String coupleId,
    required String partnerId,
  }) async {
    final needsRefresh = _userId != userId || _coupleId != coupleId;
    _userId = userId;
    _coupleId = coupleId;
    _partnerId = partnerId;

    if (!needsRefresh) return;

    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_coupleId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _service.getMoodMessages(_coupleId!);
      _moods
        ..clear()
        ..addAll(results);
      await _loadReads();
      _scheduleMarkReads();
    } catch (e) {
      _error = 'Failed to load moods: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshSilently() async {
    if (_coupleId == null || _isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();

    try {
      final results = await _service.getMoodMessages(_coupleId!);
      _moods
        ..clear()
        ..addAll(results);
      await _loadReads();
      _scheduleMarkReads();
      notifyListeners();
    } catch (e) {
      _error = 'Live refresh failed: $e';
      notifyListeners();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshNow() async {
    _error = null;
    await _refreshSilently();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Map<String, Set<String>> _groupReadsByMood(List<MoodReadModel> reads) {
    final Map<String, Set<String>> grouped = {};
    for (final read in reads) {
      grouped.putIfAbsent(read.moodMessageId, () => <String>{});
      grouped[read.moodMessageId]!.add(read.readerId);
    }
    return grouped;
  }

  Future<void> _loadReads() async {
    if (_coupleId == null) return;
    try {
      final moodIds =
          _moods.map((mood) => mood.id).whereType<String>().toList();
      final reads = moodIds.isEmpty
          ? await _service.getReads(_coupleId!)
          : await _service.getReadsForMoodMessages(
              coupleId: _coupleId!,
              moodMessageIds: moodIds,
            );
      _readsByMood
        ..clear()
        ..addAll(_groupReadsByMood(reads));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load mood reads: $e');
    }
  }

  void _scheduleMarkReads() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(
      const Duration(milliseconds: 300),
      _markUnreadAsRead,
    );
  }

  Future<void> _markUnreadAsRead() async {
    if (_userId == null || _coupleId == null) return;
    final unread = _moods.where((mood) {
      final id = mood.id;
      return mood.receiverId == _userId &&
          id != null &&
          !(_readsByMood[id]?.contains(_userId) ?? false);
    }).toList();

    if (unread.isEmpty) return;

    try {
      await Future.wait(unread.map((mood) {
        return _service.upsertRead(
          coupleId: _coupleId!,
          moodMessageId: mood.id!,
          readerId: _userId!,
        );
      }));
    } catch (e) {
      debugPrint('Failed to mark mood reads: $e');
    }
  }

  Future<bool> sendMood(
      {required String mood, required String callSign}) async {
    if (!canSend) {
      _error = 'Link your partner to send moods.';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.sendMoodMessage(
        coupleId: _coupleId!,
        senderId: _userId!,
        receiverId: _partnerId!,
        mood: mood,
        callSign: callSign,
      );
      _moods.insert(0, result);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to send mood: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> updateMoodMessage({
    required String moodMessageId,
    required String mood,
    required String callSign,
  }) async {
    if (_userId == null || _coupleId == null) {
      _error = 'Please log in again to edit moods.';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateMoodMessage(
        moodMessageId: moodMessageId,
        coupleId: _coupleId!,
        mood: mood,
        callSign: callSign.trim(),
      );

      final index = _moods.indexWhere((item) => item.id == moodMessageId);
      if (index != -1) {
        final current = _moods[index];
        _moods[index] = MoodMessageModel(
          id: current.id,
          coupleId: current.coupleId,
          senderId: current.senderId,
          receiverId: current.receiverId,
          mood: mood,
          callSign: callSign.trim(),
          sentAt: current.sentAt,
          createdAt: current.createdAt,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to edit mood: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMood(String moodMessageId) async {
    if (_coupleId == null) return false;
    try {
      await _service.deleteMoodMessage(
        moodMessageId: moodMessageId,
        coupleId: _coupleId!,
      );
      _moods.removeWhere((m) => m.id == moodMessageId);
      _readsByMood.remove(moodMessageId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete mood: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMoods(List<String> moodMessageIds) async {
    if (_coupleId == null || moodMessageIds.isEmpty) return false;
    try {
      await _service.deleteMoodMessages(
        moodMessageIds: moodMessageIds,
        coupleId: _coupleId!,
      );
      _moods.removeWhere((m) => m.id != null && moodMessageIds.contains(m.id));
      for (final id in moodMessageIds) {
        _readsByMood.remove(id);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete moods: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _moodSubscription?.cancel();
    _moodSubscription = null;
    _readSubscription?.cancel();
    _readSubscription = null;
    _stopPolling();
    _markReadTimer?.cancel();
    _markReadTimer = null;
    _moods.clear();
    _readsByMood.clear();
    _userId = null;
    _coupleId = null;
    _partnerId = null;
    _error = null;
    _isLoading = false;
    _isRefreshing = false;
    _isSending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _moodSubscription?.cancel();
    _readSubscription?.cancel();
    _stopPolling();
    _markReadTimer?.cancel();
    super.dispose();
  }
}
