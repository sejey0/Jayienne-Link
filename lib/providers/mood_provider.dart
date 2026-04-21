import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mood_message_model.dart';
import '../models/mood_read_model.dart';
import '../services/supabase_mood_service.dart';

class MoodProvider extends ChangeNotifier {
  final SupabaseMoodService _service;

  MoodProvider(this._service);

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
    _subscribeToStream();
    _subscribeToReadStream();
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

  void _startPolling() {
    if (_pollingTimer != null) return;
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _refreshSilently(),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _subscribeToStream() {
    _moodSubscription?.cancel();
    if (_coupleId == null) return;

    _moodSubscription =
        _service.streamMoodMessages(_coupleId!).listen((events) {
      _handleMoodUpdate(events);
    }, onError: (error) {
      _error = 'Live updates unavailable: $error';
      notifyListeners();
      _startPolling();
    });

    _startPolling();
  }

  void _handleMoodUpdate(List<MoodMessageModel> events) {
    _moods
      ..clear()
      ..addAll(events);
    notifyListeners();
    _scheduleMarkReads();
  }

  void _subscribeToReadStream() {
    _readSubscription?.cancel();
    if (_coupleId == null) return;

    _readSubscription = _service.streamReads(_coupleId!).listen((reads) {
      _readsByMood
        ..clear()
        ..addAll(_groupReadsByMood(reads));
      notifyListeners();
      _scheduleMarkReads();
    }, onError: (error) {
      debugPrint('Mood read stream error: $error');
    });
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
      await _refreshSilently();
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
    _moodSubscription?.cancel();
    _readSubscription?.cancel();
    _stopPolling();
    _markReadTimer?.cancel();
    super.dispose();
  }
}
