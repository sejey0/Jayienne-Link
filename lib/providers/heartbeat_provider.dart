import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/heartbeat_model.dart';
import '../models/heartbeat_reaction_model.dart';
import '../models/heartbeat_read_model.dart';
import '../models/heartbeat_typing_model.dart';
import '../services/supabase_heartbeat_service.dart';

class HeartbeatProvider extends ChangeNotifier {
  final SupabaseHeartbeatService _service;

  HeartbeatProvider(this._service);

  final List<HeartbeatModel> _heartbeats = [];
  StreamSubscription<List<HeartbeatModel>>? _heartbeatSubscription;
  StreamSubscription<List<HeartbeatReactionModel>>? _reactionSubscription;
  StreamSubscription<List<HeartbeatReadModel>>? _readSubscription;
  StreamSubscription<List<HeartbeatTypingModel>>? _typingSubscription;
  Timer? _pollingTimer;
  Timer? _typingStopTimer;
  Timer? _typingExpiryTimer;
  Timer? _markReadTimer;
  bool _isRefreshing = false;
  bool _isTyping = false;
  bool _isPartnerTyping = false;
  DateTime? _lastTypingSentAt;

  final Map<String, Set<String>> _reactionsByHeartbeat = {};
  final Map<String, Set<String>> _readsByHeartbeat = {};

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

  int reactionCount(String heartbeatId) {
    return _reactionsByHeartbeat[heartbeatId]?.length ?? 0;
  }

  bool hasReaction(String heartbeatId) {
    return reactionCount(heartbeatId) > 0;
  }

  bool hasMyReaction(String heartbeatId) {
    if (_userId == null) return false;
    return _reactionsByHeartbeat[heartbeatId]?.contains(_userId) ?? false;
  }

  bool isSeenByPartner(String heartbeatId) {
    if (_partnerId == null) return false;
    return _readsByHeartbeat[heartbeatId]?.contains(_partnerId) ?? false;
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
    _subscribeToReactionStream();
    _subscribeToReadStream();
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
      await _loadReactions();
      await _loadReads();
      _scheduleMarkReads();
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
      await _loadReactions();
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
    _heartbeatSubscription?.cancel();
    if (_coupleId == null) return;

    _heartbeatSubscription =
        _service.streamHeartbeats(_coupleId!).listen((events) {
      _handleHeartbeatsUpdate(events);
    }, onError: (error) {
      _error = 'Live updates unavailable: $error';
      notifyListeners();
      _startPolling();
    });

    _startPolling();
  }

  void _handleHeartbeatsUpdate(List<HeartbeatModel> events) {
    _heartbeats
      ..clear()
      ..addAll(events);
    notifyListeners();
    _scheduleMarkReads();
  }

  void _subscribeToReactionStream() {
    _reactionSubscription?.cancel();
    if (_coupleId == null) return;

    _reactionSubscription =
        _service.streamReactions(_coupleId!).listen((reactions) {
      _reactionsByHeartbeat
        ..clear()
        ..addAll(_groupByHeartbeat(reactions));
      notifyListeners();
    }, onError: (error) {
      debugPrint('Reaction stream error: $error');
    });
  }

  void _subscribeToReadStream() {
    _readSubscription?.cancel();
    if (_coupleId == null) return;

    _readSubscription = _service.streamReads(_coupleId!).listen((reads) {
      _readsByHeartbeat
        ..clear()
        ..addAll(_groupReadsByHeartbeat(reads));
      notifyListeners();
      _scheduleMarkReads();
    }, onError: (error) {
      debugPrint('Read stream error: $error');
    });
  }

  Future<void> _loadReactions() async {
    if (_coupleId == null) return;
    try {
      final heartbeatIds = _heartbeats
          .map((heartbeat) => heartbeat.id)
          .whereType<String>()
          .toList();
      final reactions = heartbeatIds.isEmpty
          ? await _service.getReactions(_coupleId!)
          : await _service.getReactionsForHeartbeats(
              coupleId: _coupleId!,
              heartbeatIds: heartbeatIds,
            );
      _reactionsByHeartbeat
        ..clear()
        ..addAll(_groupByHeartbeat(reactions));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load reactions: $e');
    }
  }

  Future<void> _loadReads() async {
    if (_coupleId == null) return;
    try {
      final heartbeatIds = _heartbeats
          .map((heartbeat) => heartbeat.id)
          .whereType<String>()
          .toList();
      final reads = heartbeatIds.isEmpty
          ? await _service.getReads(_coupleId!)
          : await _service.getReadsForHeartbeats(
              coupleId: _coupleId!,
              heartbeatIds: heartbeatIds,
            );
      _readsByHeartbeat
        ..clear()
        ..addAll(_groupReadsByHeartbeat(reads));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load reads: $e');
    }
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

  Map<String, Set<String>> _groupByHeartbeat(
    List<HeartbeatReactionModel> reactions,
  ) {
    final Map<String, Set<String>> grouped = {};
    for (final reaction in reactions) {
      grouped.putIfAbsent(reaction.heartbeatId, () => <String>{});
      grouped[reaction.heartbeatId]!.add(reaction.userId);
    }
    return grouped;
  }

  Map<String, Set<String>> _groupReadsByHeartbeat(
    List<HeartbeatReadModel> reads,
  ) {
    final Map<String, Set<String>> grouped = {};
    for (final read in reads) {
      grouped.putIfAbsent(read.heartbeatId, () => <String>{});
      grouped[read.heartbeatId]!.add(read.readerId);
    }
    return grouped;
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

  Future<void> toggleReaction(String heartbeatId) async {
    if (_coupleId == null || _userId == null) return;
    final hadReaction = hasMyReaction(heartbeatId);
    _applyLocalReaction(heartbeatId, userId: _userId!, add: !hadReaction);

    try {
      if (hadReaction) {
        await _service.deleteReaction(
          heartbeatId: heartbeatId,
          userId: _userId!,
        );
      } else {
        await _service.upsertReaction(
          coupleId: _coupleId!,
          heartbeatId: heartbeatId,
          userId: _userId!,
        );
      }
    } catch (e) {
      _applyLocalReaction(heartbeatId, userId: _userId!, add: hadReaction);
      debugPrint('Failed to toggle reaction: $e');
    }
  }

  void _applyLocalReaction(
    String heartbeatId, {
    required String userId,
    required bool add,
  }) {
    final reactions = _reactionsByHeartbeat.putIfAbsent(
      heartbeatId,
      () => <String>{},
    );
    if (add) {
      reactions.add(userId);
    } else {
      reactions.remove(userId);
      if (reactions.isEmpty) {
        _reactionsByHeartbeat.remove(heartbeatId);
      }
    }
    notifyListeners();
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
    final unread = _heartbeats.where((heartbeat) {
      final id = heartbeat.id;
      return heartbeat.receiverId == _userId &&
          id != null &&
          !(_readsByHeartbeat[id]?.contains(_userId) ?? false);
    }).toList();

    if (unread.isEmpty) return;

    try {
      await Future.wait(unread.map((heartbeat) {
        return _service.upsertRead(
          coupleId: _coupleId!,
          heartbeatId: heartbeat.id!,
          readerId: _userId!,
        );
      }));
    } catch (e) {
      debugPrint('Failed to mark reads: $e');
    }
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
    _reactionSubscription?.cancel();
    _reactionSubscription = null;
    _readSubscription?.cancel();
    _readSubscription = null;
    _typingSubscription?.cancel();
    _typingSubscription = null;
    _stopPolling();
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    _typingExpiryTimer?.cancel();
    _typingExpiryTimer = null;
    _markReadTimer?.cancel();
    _markReadTimer = null;
    _heartbeats.clear();
    _reactionsByHeartbeat.clear();
    _readsByHeartbeat.clear();
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
    _reactionSubscription?.cancel();
    _readSubscription?.cancel();
    _typingSubscription?.cancel();
    _stopPolling();
    _typingStopTimer?.cancel();
    _typingExpiryTimer?.cancel();
    _markReadTimer?.cancel();
    super.dispose();
  }
}
