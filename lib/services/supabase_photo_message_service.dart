import '../models/photo_message_model.dart';
import 'supabase_data_service.dart';

class SupabasePhotoMessageService {
  static const String _tableName = 'photo_messages';

  Future<List<PhotoMessageModel>> getPhotoMessages(
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

    return records.map(PhotoMessageModel.fromJson).toList();
  }

  Stream<List<PhotoMessageModel>> streamPhotoMessages(
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
      final models = records.map(PhotoMessageModel.fromJson).toList();
      models.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      if (models.length > limit) {
        return models.sublist(0, limit);
      }
      return models;
    });
  }

  Future<PhotoMessageModel> sendPhotoMessage({
    required String coupleId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String? caption,
  }) async {
    final trimmedCaption = caption?.trim();
    final payload = {
      'couple_id': coupleId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'image_url': imageUrl,
      'sent_at': DateTime.now().toIso8601String(),
      if (trimmedCaption != null && trimmedCaption.isNotEmpty)
        'caption': trimmedCaption,
    };

    final record = await SupabaseDataService.insertRecord(_tableName, payload);
    return PhotoMessageModel.fromJson(record);
  }
}
