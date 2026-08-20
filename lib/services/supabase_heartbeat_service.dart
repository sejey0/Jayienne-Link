import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/heartbeat_model.dart';
import '../models/heartbeat_reaction_model.dart';
import '../models/heartbeat_read_model.dart';
import '../models/heartbeat_typing_model.dart';
import 'supabase_data_service.dart';

/// Data payload representation for transient realtime touch events
class TouchPayload {
  final String userId;
  final double x;
  final double y;
  final String state; // 'down', 'move', 'up'
  final double intensity;
  final int timestamp;

  TouchPayload({
    required this.userId,
    required this.x,
    required this.y,
    required this.state,
    required this.intensity,
    required this.timestamp,
  });

  factory TouchPayload.fromMap(Map<String, dynamic> map) {
    return TouchPayload(
      userId: map['user_id'] as String? ?? '',
      x: (map['x'] as num? ?? 0.0).toDouble(),
      y: (map['y'] as num? ?? 0.0).toDouble(),
      state: map['state'] as String? ?? 'move',
      intensity: (map['intensity'] as num? ?? 1.0).toDouble(),
      timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'x': x,
      'y': y,
      'state': state,
      'intensity': intensity,
      'timestamp': timestamp,
    };
  }
}

class SupabaseHeartbeatService {
  static const String _tableName = 'heartbeats';
  static const String _reactionTableName = 'heartbeat_reactions';
  static const String _readTableName = 'heartbeat_reads';
  static const String _typingTableName = 'heartbeat_typing';

  // Realtime Broadcast Channel State
  RealtimeChannel? _touchChannel;
  String? _activeChannelCoupleId;
  StreamController<TouchPayload>? _touchStreamController;
  StreamController<Map<String, dynamic>>? _typingStreamController;

  // Throttling state for 30 FPS touch streaming
  Timer? _touchThrottleTimer;
  Map<String, dynamic>? _pendingTouchPayload;

  // ===================================================
  // REALTIME TOUCH & TYPING BROADCAST ENGINE (Ephemeral)
  // ===================================================

  /// Subscribe to ephemeral touch broadcast channel for a couple
  Stream<TouchPayload> subscribeToTouchBroadcast(String coupleId) {
    if (_touchChannel != null && _activeChannelCoupleId == coupleId && _touchStreamController != null) {
      return _touchStreamController!.stream;
    }

    unsubscribeTouchBroadcast();

    _activeChannelCoupleId = coupleId;
    _touchStreamController = StreamController<TouchPayload>.broadcast();
    _typingStreamController = StreamController<Map<String, dynamic>>.broadcast();
    final client = SupabaseDataService.client;

    _touchChannel = client.channel('heartbeat:$coupleId');
    _touchChannel!.onBroadcast(
      event: 'touch',
      callback: (payload) {
        try {
          final touch = TouchPayload.fromMap(payload);
          _touchStreamController?.add(touch);
        } catch (e) {
          debugPrint('[SupabaseHeartbeatService] Error parsing touch payload: $e');
        }
      },
    );

    _touchChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        try {
          _typingStreamController?.add(payload);
        } catch (e) {
          debugPrint('[SupabaseHeartbeatService] Error parsing typing payload: $e');
        }
      },
    );

    try {
      _touchChannel!.subscribe();
    } catch (e) {
      debugPrint('[SupabaseHeartbeatService] Error subscribing to touch channel: $e');
    }

    return _touchStreamController!.stream;
  }

  /// Subscribe to ephemeral partner typing events for a couple
  Stream<Map<String, dynamic>> subscribeToTypingBroadcast(String coupleId) {
    if (_touchChannel == null || _activeChannelCoupleId != coupleId) {
      subscribeToTouchBroadcast(coupleId);
    }
    _typingStreamController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _typingStreamController!.stream;
  }

  /// Broadcast typing status update to partner
  Future<void> broadcastTypingStatus({
    required String coupleId,
    required String userId,
    required bool isTyping,
  }) async {
    final payload = {
      'user_id': userId,
      'is_typing': isTyping,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (_touchChannel == null || _activeChannelCoupleId != coupleId) {
      subscribeToTouchBroadcast(coupleId);
    }

    try {
      await _touchChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: payload,
      );
    } catch (e) {
      debugPrint('[SupabaseHeartbeatService] Typing broadcast failed: $e');
    }
  }

  /// Broadcast touch event throttled at ~30 FPS (~33ms intervals)
  void broadcastTouchThrottled({
    required String coupleId,
    required String userId,
    required double x,
    required double y,
    required String state, // 'down', 'move', 'up'
    double intensity = 1.0,
  }) {
    final payload = {
      'user_id': userId,
      'x': x,
      'y': y,
      'state': state,
      'intensity': intensity,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 'down' and 'up' events are sent immediately for zero perceived latency on touch start/end
    if (state == 'down' || state == 'up') {
      _touchThrottleTimer?.cancel();
      _pendingTouchPayload = null;
      _sendBroadcastNow(coupleId, payload);
      return;
    }

    // 'move' events are buffered at 33ms (30 FPS)
    _pendingTouchPayload = payload;
    if (_touchThrottleTimer == null || !_touchThrottleTimer!.isActive) {
      _touchThrottleTimer = Timer(const Duration(milliseconds: 33), () {
        if (_pendingTouchPayload != null) {
          _sendBroadcastNow(coupleId, _pendingTouchPayload!);
          _pendingTouchPayload = null;
        }
      });
    }
  }

  void _sendBroadcastNow(String coupleId, Map<String, dynamic> payload) async {
    if (_touchChannel == null || _activeChannelCoupleId != coupleId) {
      subscribeToTouchBroadcast(coupleId);
    }
    try {
      await _touchChannel?.sendBroadcastMessage(
        event: 'touch',
        payload: payload,
      );
    } catch (e) {
      debugPrint('[SupabaseHeartbeatService] Broadcast send failed: $e');
    }
  }

  /// Unsubscribe and dispose realtime channel
  void unsubscribeTouchBroadcast() {
    _touchThrottleTimer?.cancel();
    _touchThrottleTimer = null;
    _pendingTouchPayload = null;

    if (_touchChannel != null) {
      SupabaseDataService.client.removeChannel(_touchChannel!);
      _touchChannel = null;
    }
    _activeChannelCoupleId = null;
    _touchStreamController?.close();
    _touchStreamController = null;
    _typingStreamController?.close();
    _typingStreamController = null;
  }

  // ===================================================
  // DATABASE PERSISTENCE METHODS
  // ===================================================

  Future<List<HeartbeatModel>> getHeartbeats(
    String coupleId, {
    int? limit,
  }) async {
    final records = await SupabaseDataService.getRecords(
      _tableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'sent_at',
      ascending: false,
      limit: limit,
    );

    return records.map(HeartbeatModel.fromJson).toList();
  }

  Stream<List<HeartbeatModel>> streamHeartbeats(
    String coupleId, {
    int? limit,
  }) {
    return SupabaseDataService.getRecordsStream(
      _tableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'sent_at',
      ascending: false,
    ).map((records) {
      final models = records.map(HeartbeatModel.fromJson).toList();
      models.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      if (limit != null && limit > 0 && models.length > limit) {
        return models.sublist(0, limit);
      }
      return models;
    });
  }

  Future<HeartbeatModel> sendHeartbeat({
    required String coupleId,
    required String senderId,
    required String receiverId,
    String? message,
  }) async {
    final trimmedMessage = message?.trim();
    final payload = {
      'couple_id': coupleId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sent_at': DateTime.now().toIso8601String(),
      if (trimmedMessage != null && trimmedMessage.isNotEmpty)
        'message': trimmedMessage,
    };

    final record = await SupabaseDataService.insertRecord(_tableName, payload);
    return HeartbeatModel.fromJson(record);
  }

  Stream<List<HeartbeatReactionModel>> streamReactions(String coupleId) {
    return SupabaseDataService.getRecordsStream(
      _reactionTableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'updated_at',
      ascending: false,
    ).map((records) {
      return records.map(HeartbeatReactionModel.fromJson).toList();
    });
  }

  Future<List<HeartbeatReactionModel>> getReactions(
    String coupleId, {
    int limit = 200,
  }) async {
    final records = await SupabaseDataService.getRecords(
      _reactionTableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'updated_at',
      ascending: false,
      limit: limit,
    );

    return records.map(HeartbeatReactionModel.fromJson).toList();
  }

  Future<List<HeartbeatReactionModel>> getReactionsForHeartbeats({
    required String coupleId,
    required List<String> heartbeatIds,
  }) async {
    if (heartbeatIds.isEmpty) return [];

    final formattedIds = heartbeatIds.map((id) => '"$id"').join(',');
    final inFilter = '($formattedIds)';

    final records = await SupabaseDataService.safeExecute(() async {
      final response = await SupabaseDataService.client
          .from(_reactionTableName)
          .select()
          .eq('couple_id', coupleId)
          .filter('heartbeat_id', 'in', inFilter);
      return List<Map<String, dynamic>>.from(response);
    }, context: 'Fetch reactions for heartbeats');

    return records?.map(HeartbeatReactionModel.fromJson).toList() ?? [];
  }

  Future<void> upsertReaction({
    required String coupleId,
    required String heartbeatId,
    required String userId,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'heartbeat_id': heartbeatId,
      'user_id': userId,
      'reaction': 'purple_heart',
      'updated_at': DateTime.now().toIso8601String(),
    };

    await SupabaseDataService.safeExecute(() async {
      await SupabaseDataService.client
          .from(_reactionTableName)
          .upsert(payload, onConflict: 'heartbeat_id,user_id');
    }, context: 'Upsert heartbeat reaction for $heartbeatId');
  }

  Future<void> deleteReaction({
    required String heartbeatId,
    required String userId,
  }) async {
    await SupabaseDataService.safeExecute(() async {
      await SupabaseDataService.client
          .from(_reactionTableName)
          .delete()
          .eq('heartbeat_id', heartbeatId)
          .eq('user_id', userId);
    }, context: 'Delete heartbeat reaction for $heartbeatId');
  }

  Stream<List<HeartbeatReadModel>> streamReads(String coupleId) {
    return SupabaseDataService.getRecordsStream(
      _readTableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'read_at',
      ascending: false,
    ).map((records) {
      return records.map(HeartbeatReadModel.fromJson).toList();
    });
  }

  Future<List<HeartbeatReadModel>> getReads(
    String coupleId, {
    int limit = 200,
  }) async {
    final records = await SupabaseDataService.getRecords(
      _readTableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'read_at',
      ascending: false,
      limit: limit,
    );

    return records.map(HeartbeatReadModel.fromJson).toList();
  }

  Future<List<HeartbeatReadModel>> getReadsForHeartbeats({
    required String coupleId,
    required List<String> heartbeatIds,
  }) async {
    if (heartbeatIds.isEmpty) return [];

    final formattedIds = heartbeatIds.map((id) => '"$id"').join(',');
    final inFilter = '($formattedIds)';

    final records = await SupabaseDataService.safeExecute(() async {
      final response = await SupabaseDataService.client
          .from(_readTableName)
          .select()
          .eq('couple_id', coupleId)
          .filter('heartbeat_id', 'in', inFilter);
      return List<Map<String, dynamic>>.from(response);
    }, context: 'Fetch reads for heartbeats');

    return records?.map(HeartbeatReadModel.fromJson).toList() ?? [];
  }

  Future<void> upsertRead({
    required String coupleId,
    required String heartbeatId,
    required String readerId,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'heartbeat_id': heartbeatId,
      'reader_id': readerId,
      'read_at': DateTime.now().toIso8601String(),
    };

    await SupabaseDataService.safeExecute(() async {
      await SupabaseDataService.client
          .from(_readTableName)
          .upsert(payload, onConflict: 'heartbeat_id,reader_id');
    }, context: 'Upsert heartbeat read for $heartbeatId');
  }

  Stream<List<HeartbeatTypingModel>> streamTypingStatuses(String coupleId) {
    return SupabaseDataService.getRecordsStream(
      _typingTableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'updated_at',
      ascending: false,
    ).map((records) {
      return records.map(HeartbeatTypingModel.fromJson).toList();
    });
  }

  Future<void> upsertTypingStatus({
    required String coupleId,
    required String userId,
    required bool isTyping,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'user_id': userId,
      'is_typing': isTyping,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await SupabaseDataService.safeExecute(() async {
      await SupabaseDataService.client
          .from(_typingTableName)
          .upsert(payload, onConflict: 'couple_id,user_id');
    }, context: 'Upsert typing status for $coupleId');
  }
}
