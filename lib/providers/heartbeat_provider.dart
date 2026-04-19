import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/heartbeat_model.dart';
import '../services/supabase_heartbeat_service.dart';

class HeartbeatProvider extends ChangeNotifier {
  final SupabaseHeartbeatService _service;

  HeartbeatProvider(this._service);

  final List<HeartbeatModel> _heartbeats = [];
  StreamSubscription<List<HeartbeatModel>>? _heartbeatSubscription;

  String? _userId;
  String? _coupleId;
  String? _partnerId;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<HeartbeatModel> get heartbeats => List.unmodifiable(_heartbeats);
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
    });
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
    _heartbeats.clear();
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
    _heartbeatSubscription?.cancel();
    super.dispose();
  }
}
