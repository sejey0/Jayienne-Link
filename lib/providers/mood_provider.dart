import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mood_message_model.dart';
import '../services/supabase_mood_service.dart';

class MoodProvider extends ChangeNotifier {
  final SupabaseMoodService _service;

  MoodProvider(this._service);

  final List<MoodMessageModel> _moods = [];
  StreamSubscription<List<MoodMessageModel>>? _moodSubscription;

  String? _userId;
  String? _coupleId;
  String? _partnerId;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<MoodMessageModel> get moods => List.unmodifiable(_moods);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get canSend =>
      _partnerId != null && _coupleId != null && _userId != null;

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
    } catch (e) {
      _error = 'Failed to load moods: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToStream() {
    _moodSubscription?.cancel();
    if (_coupleId == null) return;

    _moodSubscription =
        _service.streamMoodMessages(_coupleId!).listen((events) {
      _moods
        ..clear()
        ..addAll(events);
      notifyListeners();
    }, onError: (error) {
      _error = 'Live updates unavailable: $error';
      notifyListeners();
    });
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
    _moods.clear();
    _userId = null;
    _coupleId = null;
    _partnerId = null;
    _error = null;
    _isLoading = false;
    _isSending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _moodSubscription?.cancel();
    super.dispose();
  }
}
