import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../models/heartbeat_model.dart';
import '../models/heartbeat_reaction_model.dart';
import '../models/heartbeat_read_model.dart';
import '../services/supabase_heartbeat_service.dart';

/// Representation of a touch point along a fading touch trail
class TouchTrailPoint {
  final Offset position;
  final DateTime timestamp;
  final double intensity;

  TouchTrailPoint({
    required this.position,
    required this.timestamp,
    this.intensity = 1.0,
  });

  double get opacity {
    final ageMs = DateTime.now().difference(timestamp).inMilliseconds;
    const maxAgeMs = 400; // Trail fades over 400ms
    if (ageMs >= maxAgeMs) return 0.0;
    return (1.0 - (ageMs / maxAgeMs)).clamp(0.0, 1.0);
  }
}

/// Particle types for collision explosion effect
enum TouchParticleType { heart, sparkle }

/// Representation of an animated physics particle bursting from touch collision
class TouchParticle {
  Offset position;
  Offset velocity;
  double scale;
  double opacity;
  double rotation;
  double rotationSpeed;
  Color color;
  final TouchParticleType type;
  final int maxAgeMs;
  final DateTime createdAt;

  TouchParticle({
    required this.position,
    required this.velocity,
    required this.scale,
    required this.color,
    this.type = TouchParticleType.heart,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.rotationSpeed = 0.05,
    this.maxAgeMs = 700,
  }) : createdAt = DateTime.now();

  double get currentOpacity {
    final ageMs = DateTime.now().difference(createdAt).inMilliseconds;
    if (ageMs >= maxAgeMs) return 0.0;
    return (1.0 - (ageMs / maxAgeMs)).clamp(0.0, 1.0);
  }
}

class HeartbeatProvider extends ChangeNotifier {
  final SupabaseHeartbeatService _service;
  bool _disposed = false;

  HeartbeatProvider(this._service);

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  final List<HeartbeatModel> _heartbeats = [];
  StreamSubscription<List<HeartbeatModel>>? _heartbeatSubscription;
  StreamSubscription<List<HeartbeatReactionModel>>? _reactionSubscription;
  StreamSubscription<List<HeartbeatReadModel>>? _readSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<TouchPayload>? _touchSubscription;

  Timer? _pollingTimer;
  Timer? _typingStopTimer;
  Timer? _typingExpiryTimer;
  Timer? _markReadTimer;

  bool _isRefreshing = false;
  bool _isTyping = false;
  bool _isPartnerTyping = false;

  final Map<String, Set<String>> _reactionsByHeartbeat = {};
  final Map<String, Set<String>> _readsByHeartbeat = {};

  String? _userId;
  String? _coupleId;
  String? _partnerId;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  // ===================================================
  // REALTIME TOUCH & GRAPHICS STATE
  // ===================================================
  Size _screenSize = Size.zero;
  Offset? _localCurrentTouch;
  Offset? _partnerCurrentTouch;
  Offset? _partnerTargetTouch;
  bool _isLocalTouching = false;
  bool _isPartnerTouching = false;

  final List<TouchTrailPoint> _localTouchTrail = [];
  final List<TouchTrailPoint> _partnerTouchTrail = [];
  final List<TouchParticle> _collisionParticles = [];

  // Proximity & Collision State
  bool _isColliding = false;
  Offset? _collisionPoint;
  double _collisionRippleRadius = 0.0;
  DateTime? _lastCollisionHapticTime;
  DateTime? _lastGeneralHapticTime;

  static const double _collisionThreshold = 30.0; // Logical pixels
  static const Duration _minHapticInterval = Duration(milliseconds: 70); // Rate-limited ~14Hz

  // Getters
  List<HeartbeatModel> get heartbeats => List.unmodifiable(_heartbeats);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSending => _isSending;
  bool get isPartnerTyping => _isPartnerTyping;
  String? get error => _error;
  bool get canSend => _partnerId != null && _coupleId != null && _userId != null;

  // Touch getters
  Size get screenSize => _screenSize;
  Offset? get localCurrentTouch => _localCurrentTouch;
  Offset? get partnerCurrentTouch => _partnerCurrentTouch;
  bool get isLocalTouching => _isLocalTouching;
  bool get isPartnerTouching => _isPartnerTouching;
  List<TouchTrailPoint> get localTouchTrail => List.unmodifiable(_localTouchTrail);
  List<TouchTrailPoint> get partnerTouchTrail => List.unmodifiable(_partnerTouchTrail);
  List<TouchParticle> get collisionParticles => List.unmodifiable(_collisionParticles);
  bool get isColliding => _isColliding;
  Offset? get collisionPoint => _collisionPoint;
  double get collisionRippleRadius => _collisionRippleRadius;

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
  }

  // ===================================================
  // REALTIME TOUCH BROADCAST & INTERPOLATION LOGIC
  // ===================================================

  /// Update active screen dimensions for aspect ratio normalization
  void updateScreenSize(Size size) {
    if (_screenSize != size && size.width > 0 && size.height > 0) {
      _screenSize = size;
    }
  }

  /// Start Realtime Touch & Typing Subscription Session
  void startTouchSession() {
    if (_coupleId == null) return;
    _touchSubscription?.cancel();
    _touchSubscription = _service.subscribeToTouchBroadcast(_coupleId!).listen((payload) {
      if (payload.userId != _userId) {
        _onPartnerTouchReceived(payload);
      }
    });

    _typingSubscription?.cancel();
    _typingSubscription = _service.subscribeToTypingBroadcast(_coupleId!).listen((payload) {
      final senderId = payload['user_id'] as String?;
      if (senderId != null && senderId != _userId) {
        _onPartnerTypingReceived(payload);
      }
    });
  }

  /// Stop Realtime Touch & Typing Subscription Session
  void stopTouchSession() {
    _touchSubscription?.cancel();
    _touchSubscription = null;
    _typingSubscription?.cancel();
    _typingSubscription = null;
    _typingExpiryTimer?.cancel();
    _typingExpiryTimer = null;
    _service.unsubscribeTouchBroadcast();
    _localCurrentTouch = null;
    _partnerCurrentTouch = null;
    _partnerTargetTouch = null;
    _isLocalTouching = false;
    _isPartnerTouching = false;
    _isPartnerTyping = false;
    _isTyping = false;
    _localTouchTrail.clear();
    _partnerTouchTrail.clear();
    _collisionParticles.clear();
  }

  /// Broadcast typing status update to partner
  void sendTypingStatus(bool isTyping) {
    if (_coupleId == null || _userId == null) return;
    if (_isTyping == isTyping) return;
    _isTyping = isTyping;

    _service.broadcastTypingStatus(
      coupleId: _coupleId!,
      userId: _userId!,
      isTyping: isTyping,
    );
  }

  /// Stop user typing
  void stopTyping() {
    _typingStopTimer?.cancel();
    if (_isTyping) {
      sendTypingStatus(false);
    }
  }

  /// Handle typing input changes with 2.5-second debounce
  void handleTypingChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    if (hasText) {
      sendTypingStatus(true);
      _typingStopTimer?.cancel();
      _typingStopTimer = Timer(const Duration(milliseconds: 2500), () {
        sendTypingStatus(false);
      });
    } else {
      _typingStopTimer?.cancel();
      sendTypingStatus(false);
    }
  }

  /// Partner typing event handler with 4-second safety timeout
  void _onPartnerTypingReceived(Map<String, dynamic> payload) {
    final isTyping = payload['is_typing'] as bool? ?? false;
    _isPartnerTyping = isTyping;

    _typingExpiryTimer?.cancel();
    if (isTyping) {
      _typingExpiryTimer = Timer(const Duration(seconds: 4), () {
        if (_isPartnerTyping) {
          _isPartnerTyping = false;
          notifyListeners();
        }
      });
    }

    notifyListeners();
  }

  /// Send Local User Touch Update with normalized coordinates
  void sendLocalTouch(Offset position, String state, {double intensity = 1.0, Size? screenSize}) {
    if (_coupleId == null || _userId == null) return;

    if (screenSize != null && screenSize.width > 0 && screenSize.height > 0) {
      _screenSize = screenSize;
    }

    _localCurrentTouch = position;
    _isLocalTouching = state != 'up';

    if (_isLocalTouching) {
      _localTouchTrail.add(TouchTrailPoint(
        position: position,
        timestamp: DateTime.now(),
        intensity: intensity,
      ));
    }

    // Calculate normalized 0.0 - 1.0 coordinates to prevent screen size mismatch
    double normX = position.dx;
    double normY = position.dy;
    if (_screenSize.width > 0 && _screenSize.height > 0) {
      normX = (position.dx / _screenSize.width).clamp(0.0, 1.0);
      normY = (position.dy / _screenSize.height).clamp(0.0, 1.0);
    }

    // Broadcast over WebSocket (Throttled at 30 FPS)
    _service.broadcastTouchThrottled(
      coupleId: _coupleId!,
      userId: _userId!,
      x: normX,
      y: normY,
      state: state,
      intensity: intensity,
    );

    _checkProximityAndHaptics();
    notifyListeners();
  }

  /// Partner touch event handler (Denormalizes coordinates to local screen size)
  void _onPartnerTouchReceived(TouchPayload payload) {
    double localX = payload.x;
    double localY = payload.y;

    // Denormalize if coordinates are normalized (0.0 - 1.0) and local size is known
    if (_screenSize.width > 0 && _screenSize.height > 0 && payload.x <= 1.0 && payload.y <= 1.0) {
      localX = payload.x * _screenSize.width;
      localY = payload.y * _screenSize.height;
    }

    final newPos = Offset(localX, localY);
    _partnerTargetTouch = newPos;
    _isPartnerTouching = payload.state != 'up';

    if (payload.state == 'down' || _partnerCurrentTouch == null) {
      _partnerCurrentTouch = newPos;
    }

    if (_isPartnerTouching) {
      _partnerTouchTrail.add(TouchTrailPoint(
        position: newPos,
        timestamp: DateTime.now(),
        intensity: payload.intensity,
      ));
    }

    _triggerRateLimitedHaptic();
    _checkProximityAndHaptics();
    notifyListeners();
  }

  /// 60 FPS Interpolation Step called by CustomPainter Ticker
  void tickInterpolation(double deltaRatio) {
    // 1. Interpolate Partner Position smoothly using lerp
    if (_partnerTargetTouch != null && _partnerCurrentTouch != null) {
      _partnerCurrentTouch = Offset.lerp(_partnerCurrentTouch!, _partnerTargetTouch!, deltaRatio.clamp(0.1, 0.4));
    }

    // 2. Clean up expired trail points
    _localTouchTrail.removeWhere((p) => p.opacity <= 0.0);
    _partnerTouchTrail.removeWhere((p) => p.opacity <= 0.0);

    // 3. Animate collision ripple pulse radius
    if (_isColliding) {
      _collisionRippleRadius += 3.5;
      if (_collisionRippleRadius > 60.0) {
        _isColliding = false;
        _collisionRippleRadius = 0.0;
      }
    }

    // 4. Update collision particles physics & decay
    if (_collisionParticles.isNotEmpty) {
      for (final p in _collisionParticles) {
        p.position += p.velocity;
        p.velocity *= 0.93; // Air friction damping
        p.rotation += p.rotationSpeed;
        p.opacity = p.currentOpacity;
      }
      _collisionParticles.removeWhere((p) => p.opacity <= 0.0);
    }

    notifyListeners();
  }

  /// Proximity & Collision Calculation (Proximity < 30 logical pixels)
  void _checkProximityAndHaptics() {
    if (_isLocalTouching && _isPartnerTouching && _localCurrentTouch != null && _partnerCurrentTouch != null) {
      final distance = (_localCurrentTouch! - _partnerCurrentTouch!).distance;

      if (distance <= _collisionThreshold) {
        final now = DateTime.now();
        if (_lastCollisionHapticTime == null || now.difference(_lastCollisionHapticTime!) >= const Duration(milliseconds: 150)) {
          _lastCollisionHapticTime = now;
          _isColliding = true;
          final midpoint = Offset(
            (_localCurrentTouch!.dx + _partnerCurrentTouch!.dx) / 2,
            (_localCurrentTouch!.dy + _partnerCurrentTouch!.dy) / 2,
          );
          _collisionPoint = midpoint;
          _collisionRippleRadius = 5.0;

          // Spawn Heart & Sparkle Particle Explosion
          _spawnCollisionParticles(midpoint);

          // Intense heartbeat vibration pulse on intersection
          HapticFeedback.heavyImpact();
        }
      }
    }
  }

  /// Spawns 16-22 hearts and sparkles bursting outward from collision point
  void _spawnCollisionParticles(Offset origin) {
    final rng = math.Random();
    final count = 16 + rng.nextInt(6); // 16 - 21 particles
    final colors = [
      AppColors.softRose,
      AppColors.lavender,
      Colors.amberAccent,
      Colors.pinkAccent.shade100,
      Colors.white,
    ];

    for (int i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 2.5 + rng.nextDouble() * 4.5;
      final velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed);
      final color = colors[rng.nextInt(colors.length)];
      final scale = 0.8 + rng.nextDouble() * 0.9;
      final type = rng.nextBool() ? TouchParticleType.heart : TouchParticleType.sparkle;
      final rotation = rng.nextDouble() * 2 * math.pi;
      final rotationSpeed = (rng.nextDouble() - 0.5) * 0.15;
      final maxAgeMs = 500 + rng.nextInt(350); // 500ms - 850ms lifetime

      _collisionParticles.add(TouchParticle(
        position: origin,
        velocity: velocity,
        scale: scale,
        color: color,
        type: type,
        rotation: rotation,
        rotationSpeed: rotationSpeed,
        maxAgeMs: maxAgeMs,
      ));
    }
  }

  /// Rate-limited general touch haptic feedback (Max 14 Hz)
  void _triggerRateLimitedHaptic() {
    final now = DateTime.now();
    if (_lastGeneralHapticTime == null || now.difference(_lastGeneralHapticTime!) >= _minHapticInterval) {
      _lastGeneralHapticTime = now;
      HapticFeedback.selectionClick();
    }
  }

  // ===================================================
  // DATABASE MESSAGING & REACTION METHODS
  // ===================================================

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

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
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

  Future<bool> sendHeartbeat({String? message}) async {
    if (!canSend) {
      _error = 'Link your love to send a heartbeat.';
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
    stopTouchSession();
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
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopTouchSession();
    _service.unsubscribeTouchBroadcast();
    _heartbeatSubscription?.cancel();
    _reactionSubscription?.cancel();
    _readSubscription?.cancel();
    _typingSubscription?.cancel();
    _touchSubscription?.cancel();
    _stopPolling();
    _typingStopTimer?.cancel();
    _typingExpiryTimer?.cancel();
    _markReadTimer?.cancel();
    super.dispose();
  }
}
