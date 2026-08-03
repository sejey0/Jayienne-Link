import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_data_service.dart';

class LoveNudgePayload {
  final String senderId;
  final String senderName;
  final String nudgeType; // 'kiss' or 'hug'
  final int timestamp;

  LoveNudgePayload({
    required this.senderId,
    required this.senderName,
    required this.nudgeType,
    required this.timestamp,
  });

  factory LoveNudgePayload.fromMap(Map<String, dynamic> map) {
    return LoveNudgePayload(
      senderId: map['sender_id'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? 'Your Partner',
      nudgeType: map['nudge_type'] as String? ?? 'kiss',
      timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'nudge_type': nudgeType,
      'timestamp': timestamp,
    };
  }
}

class SupabaseLoveNudgeService {
  static final SupabaseLoveNudgeService _instance = SupabaseLoveNudgeService._internal();
  factory SupabaseLoveNudgeService() => _instance;
  SupabaseLoveNudgeService._internal();

  RealtimeChannel? _nudgeChannel;
  String? _activeCoupleId;
  StreamController<LoveNudgePayload>? _nudgeController;

  /// Subscribe to incoming love nudges for a couple
  Stream<LoveNudgePayload> subscribeToLoveNudges(String coupleId) {
    if (_nudgeChannel != null && _activeCoupleId == coupleId && _nudgeController != null) {
      return _nudgeController!.stream;
    }

    unsubscribe();

    _activeCoupleId = coupleId;
    _nudgeController = StreamController<LoveNudgePayload>.broadcast();
    final client = SupabaseDataService.client;

    debugPrint('📡 Subscribing to Love Nudges channel: love_nudge:$coupleId');
    _nudgeChannel = client.channel('love_nudge:$coupleId');

    _nudgeChannel!.onBroadcast(
      event: 'nudge',
      callback: (payload) {
        try {
          debugPrint('💌 Received Love Nudge broadcast: $payload');
          final nudge = LoveNudgePayload.fromMap(payload);
          _nudgeController?.add(nudge);
        } catch (e) {
          debugPrint('❌ Error parsing Love Nudge payload: $e');
        }
      },
    );

    try {
      _nudgeChannel!.subscribe();
      debugPrint('✅ Subscribed to Love Nudges realtime channel');
    } catch (e) {
      debugPrint('❌ Error subscribing to Love Nudges channel: $e');
    }

    return _nudgeController!.stream;
  }

  /// Broadcast a love nudge (kiss or hug) to the couple's channel
  Future<void> sendLoveNudge({
    required String coupleId,
    required String senderId,
    required String senderName,
    required String nudgeType,
  }) async {
    try {
      final payload = LoveNudgePayload(
        senderId: senderId,
        senderName: senderName,
        nudgeType: nudgeType,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final client = SupabaseDataService.client;
      var channel = _nudgeChannel;

      if (channel == null || _activeCoupleId != coupleId) {
        channel = client.channel('love_nudge:$coupleId');
        channel.subscribe();
      }

      debugPrint('🚀 Sending Love Nudge ($nudgeType) to couple: $coupleId');
      await channel.sendBroadcastMessage(
        event: 'nudge',
        payload: payload.toMap(),
      );
      debugPrint('✅ Love Nudge broadcast sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending Love Nudge broadcast: $e');
    }
  }

  /// Unsubscribe from channel
  void unsubscribe() {
    if (_nudgeChannel != null) {
      _nudgeChannel!.unsubscribe();
      _nudgeChannel = null;
    }
    _nudgeController?.close();
    _nudgeController = null;
    _activeCoupleId = null;
  }
}
