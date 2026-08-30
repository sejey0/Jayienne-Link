import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'supabase_data_service.dart';

class LoveNudgePayload {
  final String senderId;
  final String senderName;
  final String nudgeType; // 'kiss' or 'hug'
  final String? photoUrl;
  final String? message;
  final int timestamp;

  LoveNudgePayload({
    required this.senderId,
    required this.senderName,
    required this.nudgeType,
    this.photoUrl,
    this.message,
    required this.timestamp,
  });

  factory LoveNudgePayload.fromMap(Map<String, dynamic> map) {
    return LoveNudgePayload(
      senderId: map['sender_id'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? 'Your Love',
      nudgeType: map['nudge_type'] as String? ?? 'kiss',
      photoUrl: map['photo_url'] as String?,
      message: map['message'] as String?,
      timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'nudge_type': nudgeType,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (message != null && message!.trim().isNotEmpty) 'message': message!.trim(),
      'timestamp': timestamp,
    };
  }
}

class SupabaseLoveNudgeService {
  static final SupabaseLoveNudgeService _instance = SupabaseLoveNudgeService._internal();
  factory SupabaseLoveNudgeService() => _instance;
  SupabaseLoveNudgeService._internal();

  static const String _storageBucket = 'chat-photos';
  static const String _fallbackStorageBucket = 'profile-photos';

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

  /// Broadcast a love nudge (kiss or hug) with optional custom photo to the couple's channel.
  /// Reuses the existing subscribed channel when available; otherwise opens a fresh one
  /// and waits for it to join before broadcasting.
  Future<void> sendLoveNudge({
    required String coupleId,
    required String senderId,
    required String senderName,
    required String nudgeType,
    String? photoUrl,
    String? message,
  }) async {
    try {
      final payload = LoveNudgePayload(
        senderId: senderId,
        senderName: senderName,
        nudgeType: nudgeType,
        photoUrl: photoUrl,
        message: message,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final client = SupabaseDataService.client;

      // Fast path: reuse the already-subscribed singleton channel
      if (_nudgeChannel != null && _activeCoupleId == coupleId) {
        debugPrint('🚀 Sending Love Nudge ($nudgeType) via existing channel — photo: ${photoUrl != null}');
        await _nudgeChannel!.sendBroadcastMessage(
          event: 'nudge',
          payload: payload.toMap(),
        );
        debugPrint('✅ Love Nudge sent via existing channel');
        return;
      }

      // Slow path: subscribe a new channel and wait before sending
      debugPrint('🔗 No active channel. Subscribing to love_nudge:$coupleId...');
      final tempChannel = client.channel('love_nudge:$coupleId');
      final completer = Completer<void>();

      tempChannel.subscribe((status, [error]) {
        if (!completer.isCompleted) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            completer.complete();
          } else if (error != null) {
            completer.completeError(error);
          }
        }
      });

      try {
        await completer.future.timeout(const Duration(seconds: 4));
      } catch (_) {
        debugPrint('⚠️ Channel subscription timed out — attempting send anyway');
      }

      debugPrint('🚀 Sending Love Nudge ($nudgeType) via temp channel — photo: ${photoUrl != null}');
      await tempChannel.sendBroadcastMessage(
        event: 'nudge',
        payload: payload.toMap(),
      );
      debugPrint('✅ Love Nudge broadcast sent successfully');

      // Cleanup temp channel
      Future.delayed(const Duration(seconds: 2), () {
        try { tempChannel.unsubscribe(); } catch (_) {}
      });
    } catch (e) {
      debugPrint('❌ Error sending Love Nudge broadcast: $e');
    }
  }

  /// Upload a custom photo for a love nudge (kiss / hug) to Supabase Storage
  Future<String> uploadLoveNudgePhoto(String userId, File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileBytes = await imageFile.readAsBytes();
      final optimizedBytes = await _optimizeNudgeImage(fileBytes);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final ext = fileExtension.isEmpty ? '.jpg' : fileExtension;
      final fileName = 'nudge_${userId}_$timestamp$ext';

      final client = SupabaseDataService.client;
      try {
        await client.storage
            .from(_storageBucket)
            .uploadBinary(
              fileName,
              optimizedBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        return client.storage.from(_storageBucket).getPublicUrl(fileName);
      } catch (storageErr) {
        debugPrint('Upload to $_storageBucket failed ($storageErr), trying $_fallbackStorageBucket...');
        try {
          await client.storage
              .from(_fallbackStorageBucket)
              .uploadBinary(
                fileName,
                optimizedBytes,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );
          return client.storage.from(_fallbackStorageBucket).getPublicUrl(fileName);
        } catch (_) {
          return 'data:image/jpeg;base64,${base64Encode(optimizedBytes)}';
        }
      }
    } catch (e) {
      debugPrint('Error uploading love nudge photo: $e');
      try {
        final bytes = await imageFile.readAsBytes();
        final optimized = await _optimizeNudgeImage(bytes);
        return 'data:image/jpeg;base64,${base64Encode(optimized)}';
      } catch (_) {
        throw Exception('Failed to process love nudge photo: $e');
      }
    }
  }

  /// Optimize love nudge image dimensions and compression
  Future<Uint8List> _optimizeNudgeImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      img.Image resized = image;
      if (image.width > 1080 || image.height > 1080) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 1080 : null,
          height: image.height >= image.width ? 1080 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      debugPrint('Love nudge image optimization failed, using original: $e');
      return imageBytes;
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
