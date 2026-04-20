import '../models/heartbeat_model.dart';
import '../models/heartbeat_typing_model.dart';
import 'supabase_data_service.dart';

class SupabaseHeartbeatService {
  static const String _tableName = 'heartbeats';
  static const String _typingTableName = 'heartbeat_typing';

  Future<List<HeartbeatModel>> getHeartbeats(
    String coupleId, {
    int limit = 50,
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
    int limit = 50,
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
      if (models.length > limit) {
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
