import '../models/mood_message_model.dart';
import '../models/mood_read_model.dart';
import 'supabase_data_service.dart';

class SupabaseMoodService {
  static const String _tableName = 'mood_messages';
  static const String _readTableName = 'mood_message_reads';

  Future<List<MoodMessageModel>> getMoodMessages(
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

    return records.map(MoodMessageModel.fromJson).toList();
  }

  Stream<List<MoodMessageModel>> streamMoodMessages(
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
      final models = records.map(MoodMessageModel.fromJson).toList();
      models.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      if (models.length > limit) {
        return models.sublist(0, limit);
      }
      return models;
    });
  }

  Future<MoodMessageModel> sendMoodMessage({
    required String coupleId,
    required String senderId,
    required String receiverId,
    required String mood,
    required String callSign,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'mood': mood,
      'call_sign': callSign,
      'sent_at': DateTime.now().toIso8601String(),
    };

    final record = await SupabaseDataService.insertRecord(_tableName, payload);
    return MoodMessageModel.fromJson(record);
  }

  Future<void> updateMoodMessage({
    required String moodMessageId,
    required String coupleId,
    required String mood,
    required String callSign,
  }) async {
    await SupabaseDataService.safeExecute(() async {
      await SupabaseDataService.client
          .from(_tableName)
          .update({
            'mood': mood,
            'call_sign': callSign,
          })
          .eq('id', moodMessageId)
          .eq('couple_id', coupleId);
    }, context: 'Update mood message $moodMessageId');
  }

  Stream<List<MoodReadModel>> streamReads(String coupleId) {
    return SupabaseDataService.getRecordsStream(
      _readTableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'read_at',
      ascending: false,
    ).map((records) {
      return records.map(MoodReadModel.fromJson).toList();
    });
  }

  Future<List<MoodReadModel>> getReads(
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

    return records.map(MoodReadModel.fromJson).toList();
  }

  Future<List<MoodReadModel>> getReadsForMoodMessages({
    required String coupleId,
    required List<String> moodMessageIds,
  }) async {
    if (moodMessageIds.isEmpty) return [];

    final formattedIds = moodMessageIds.map((id) => '"$id"').join(',');
    final inFilter = '($formattedIds)';

    final records = await SupabaseDataService.safeExecute(() async {
      final response = await SupabaseDataService.client
          .from(_readTableName)
          .select()
          .eq('couple_id', coupleId)
          .filter('mood_message_id', 'in', inFilter);
      return List<Map<String, dynamic>>.from(response);
    }, context: 'Fetch reads for mood messages');

    return records?.map(MoodReadModel.fromJson).toList() ?? [];
  }

  Future<void> upsertRead({
    required String coupleId,
    required String moodMessageId,
    required String readerId,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'mood_message_id': moodMessageId,
      'reader_id': readerId,
      'read_at': DateTime.now().toIso8601String(),
    };

    await SupabaseDataService.safeExecute(() async {
      await SupabaseDataService.client
          .from(_readTableName)
          .upsert(payload, onConflict: 'mood_message_id,reader_id');
    }, context: 'Upsert mood read for $moodMessageId');
  }

  Future<void> deleteMoodMessage({
    required String moodMessageId,
    required String coupleId,
  }) async {
    await SupabaseDataService.safeExecute(() async {
      // 1. Delete associated read receipts first to prevent foreign key constraints
      try {
        await SupabaseDataService.client
            .from(_readTableName)
            .delete()
            .eq('mood_message_id', moodMessageId);
      } catch (e) {
        // Log note if reads deletion is optional/cascaded
      }

      // 2. Delete the mood message permanently from Supabase
      await SupabaseDataService.client
          .from(_tableName)
          .delete()
          .eq('id', moodMessageId);
    }, context: 'Delete mood message $moodMessageId');
  }

  Future<void> deleteMoodMessages({
    required List<String> moodMessageIds,
    required String coupleId,
  }) async {
    if (moodMessageIds.isEmpty) return;
    await SupabaseDataService.safeExecute(() async {
      // 1. Delete associated read receipts first
      try {
        await SupabaseDataService.client
            .from(_readTableName)
            .delete()
            .inFilter('mood_message_id', moodMessageIds);
      } catch (e) {
        // Log note if reads deletion is optional/cascaded
      }

      // 2. Delete mood messages permanently using inFilter
      await SupabaseDataService.client
          .from(_tableName)
          .delete()
          .inFilter('id', moodMessageIds);
    }, context: 'Delete bulk mood messages');
  }
}
