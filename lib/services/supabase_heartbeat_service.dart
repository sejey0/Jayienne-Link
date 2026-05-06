import '../models/heartbeat_model.dart';
import '../models/heartbeat_reaction_model.dart';
import '../models/heartbeat_read_model.dart';
import '../models/heartbeat_typing_model.dart';
import 'supabase_data_service.dart';

class SupabaseHeartbeatService {
  static const String _tableName = 'heartbeats';
  static const String _reactionTableName = 'heartbeat_reactions';
  static const String _readTableName = 'heartbeat_reads';
  static const String _typingTableName = 'heartbeat_typing';

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
