import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/heartbeat_model.dart';
import '../models/heartbeat_typing_model.dart';
import '../services/supabase_heartbeat_service.dart';

class HeartbeatProvider extends ChangeNotifier {
  final SupabaseHeartbeatService _service;

  HeartbeatProvider(this._service);

  final List<HeartbeatModel> _heartbeats = [];
  StreamSubscription<List<HeartbeatModel>>? _heartbeatSubscription;
  StreamSubscription<List<HeartbeatTypingModel>>? _typingSubscription;
  Timer? _pollingTimer;
  Timer? _typingStopTimer;
  Timer? _typingExpiryTimer;
  bool _isRefreshing = false;
  bool _isTyping = false;
  bool _isPartnerTyping = false;
  DateTime? _lastTypingSentAt;

  static const Duration _typingStaleThreshold = Duration(seconds: 6);
  static const Duration _typingPingInterval = Duration(seconds: 2);

  String? _userId;
  String? _coupleId;
  String? _partnerId;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<HeartbeatModel> get heartbeats => List.unmodifiable(_heartbeats);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSending => _isSending;
  bool get isPartnerTyping => _isPartnerTyping;
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
    _subscribeToTypingStream();
  }

  Future<void> _loadInitial() async {
    if (_coupleId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _service.getHeartbeats(_coupleId!);
      _heartbeats
        ..clear()
        ..addAll(results);
    } catch (e) {
      _error = 'Failed to load heartbeats: $e';
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
      final results = await _service.getHeartbeats(_coupleId!);
      _heartbeats
        ..clear()
        ..addAll(results);
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
    _heartbeatSubscription?.cancel();
    if (_coupleId == null) return;

    _heartbeatSubscription =
        _service.streamHeartbeats(_coupleId!).listen((events) {
      _heartbeats
        ..clear()
        ..addAll(events);
      notifyListeners();
    }, onError: (error) {
      _error = 'Live updates unavailable: $error';
      notifyListeners();
      _startPolling();
    });

    _startPolling();
  }

  void _subscribeToTypingStream() {
    _typingSubscription?.cancel();
    if (_coupleId == null) return;

    _typingSubscription =
        _service.streamTypingStatuses(_coupleId!).listen((statuses) {
      _updatePartnerTyping(statuses);
    }, onError: (error) {
      _setPartnerTyping(false);
    });
  }

  void handleTypingChanged(String text) {
    if (!canSend) return;
    final isTyping = text.trim().isNotEmpty;
    if (!isTyping) {
      _typingStopTimer?.cancel();
      _setTyping(false);
      return;
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(
      const Duration(seconds: 2),
      () => _setTyping(false),
    );

    final now = DateTime.now();
    final shouldPing = !_isTyping ||
        _lastTypingSentAt == null ||
        now.difference(_lastTypingSentAt!) >= _typingPingInterval;
    if (shouldPing) {
      _setTyping(true, force: true);
    }
  }

  void stopTyping() {
    _typingStopTimer?.cancel();
    _setTyping(false);
  }

  Future<void> _setTyping(bool isTyping, {bool force = false}) async {
    if (_coupleId == null || _userId == null) return;
    if (!force && _isTyping == isTyping) return;

    _isTyping = isTyping;
    _lastTypingSentAt = DateTime.now();

    try {
      await _service.upsertTypingStatus(
        coupleId: _coupleId!,
        userId: _userId!,
        isTyping: isTyping,
      );
    } catch (e) {
      debugPrint('Failed to update typing status: $e');
    }
  }

  void _updatePartnerTyping(List<HeartbeatTypingModel> statuses) {
    if (_partnerId == null) return;
    HeartbeatTypingModel? partnerStatus;
    for (final status in statuses) {
      if (status.userId == _partnerId) {
        partnerStatus = status;
        break;
      }
    }

    if (partnerStatus == null || !partnerStatus.isTyping) {
      _setPartnerTyping(false);
      return;
    }

    final age = DateTime.now().difference(partnerStatus.updatedAt);
    final remaining = _typingStaleThreshold - age;
    if (remaining.isNegative || remaining.inMilliseconds == 0) {
      _setPartnerTyping(false);
      return;
    }

    _setPartnerTyping(true);
    _typingExpiryTimer?.cancel();
    _typingExpiryTimer = Timer(remaining, () {
      _setPartnerTyping(false);
    });
  }

  void _setPartnerTyping(bool isTyping) {
    if (_isPartnerTyping == isTyping) return;
    _isPartnerTyping = isTyping;
    if (!isTyping) {
      _typingExpiryTimer?.cancel();
      _typingExpiryTimer = null;
    }
    notifyListeners();
  }

  Future<bool> sendHeartbeat({String? message}) async {
    if (!canSend) {
      _error = 'Link your partner to send a heartbeat.';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final trimmedMessage = message?.trim();
      final result = await _service.sendHeartbeat(
        coupleId: _coupleId!,
        senderId: _userId!,
        receiverId: _partnerId!,
        message: trimmedMessage?.isNotEmpty == true ? trimmedMessage : null,
      );
      _heartbeats.insert(0, result);
      stopTyping();
      await _refreshSilently();
      return true;
    } catch (e) {
      _error = 'Failed to send heartbeat: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clear() {
    _heartbeatSubscription?.cancel();
    _heartbeatSubscription = null;
    _typingSubscription?.cancel();
    _typingSubscription = null;
    _stopPolling();
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    _typingExpiryTimer?.cancel();
    _typingExpiryTimer = null;
    _heartbeats.clear();
    _userId = null;
    _coupleId = null;
    _partnerId = null;
    _error = null;
    _isLoading = false;
    _isSending = false;
    _isTyping = false;
    _isPartnerTyping = false;
    _lastTypingSentAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeatSubscription?.cancel();
    _typingSubscription?.cancel();
    _stopPolling();
    _typingStopTimer?.cancel();
    _typingExpiryTimer?.cancel();
    super.dispose();
  }
}
