import '../models/mood_message_model.dart';
import 'supabase_data_service.dart';

class SupabaseMoodService {
  static const String _tableName = 'mood_messages';

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
}
