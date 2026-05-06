import '../models/photo_message_model.dart';
import '../models/photo_message_read_model.dart';
import 'supabase_data_service.dart';

class SupabasePhotoMessageService {
  static const String _tableName = 'photo_messages';
  static const String _readTableName = 'photo_message_reads';

  Future<List<PhotoMessageModel>> getPhotoMessages(
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

    return records.map(PhotoMessageModel.fromJson).toList();
  }

  Stream<List<PhotoMessageModel>> streamPhotoMessages(
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
      final models = records.map(PhotoMessageModel.fromJson).toList();
      models.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      if (limit != null && limit > 0 && models.length > limit) {
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

  Future<PhotoMessageModel?> updatePhotoCaption({
    required String messageId,
    String? caption,
  }) async {
    final trimmedCaption = caption?.trim();
    final updates = {
      'caption': trimmedCaption != null && trimmedCaption.isNotEmpty
          ? trimmedCaption
          : null,
    };

    final records = await SupabaseDataService.updateRecords(
      _tableName,
      updates,
      whereColumn: 'id',
      whereValue: messageId,
    );

    if (records.isEmpty) {
      throw Exception(
        'Caption update was blocked or the message was not found.',
      );
    }
    return PhotoMessageModel.fromJson(records.first);
  }

  Future<bool> deletePhotoMessage(String messageId) async {
    final deletedRecords = await SupabaseDataService.safeExecute(
      () async {
        final response = await SupabaseDataService.client
            .from(_tableName)
            .delete()
            .eq('id', messageId)
            .select();
        return List<Map<String, dynamic>>.from(response);
      },
      context: 'Delete from $_tableName where id = $messageId',
    );

    return deletedRecords?.isNotEmpty == true;
  }

  Stream<List<PhotoMessageReadModel>> streamReads(String coupleId) {
    return SupabaseDataService.getRecordsStream(
      _readTableName,
      whereColumn: 'couple_id',
      whereValue: coupleId,
      orderBy: 'read_at',
      ascending: false,
    ).map((records) {
      return records.map(PhotoMessageReadModel.fromJson).toList();
    });
  }

  Future<List<PhotoMessageReadModel>> getReads(
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

    return records.map(PhotoMessageReadModel.fromJson).toList();
  }

  Future<List<PhotoMessageReadModel>> getReadsForPhotoMessages({
    required String coupleId,
    required List<String> photoMessageIds,
  }) async {
    if (photoMessageIds.isEmpty) return [];

    final formattedIds = photoMessageIds.map((id) => '"$id"').join(',');
    final inFilter = '($formattedIds)';

    final records = await SupabaseDataService.safeExecute(() async {
      final response = await SupabaseDataService.client
          .from(_readTableName)
          .select()
          .eq('couple_id', coupleId)
          .filter('photo_message_id', 'in', inFilter);
      return List<Map<String, dynamic>>.from(response);
    }, context: 'Fetch reads for photo messages');

    return records?.map(PhotoMessageReadModel.fromJson).toList() ?? [];
  }

  Future<void> upsertRead({
    required String coupleId,
    required String photoMessageId,
    required String readerId,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'photo_message_id': photoMessageId,
      'reader_id': readerId,
      'read_at': DateTime.now().toIso8601String(),
    };

    await SupabaseDataService.safeExecute(() async {
      await SupabaseDataService.client
          .from(_readTableName)
          .upsert(payload, onConflict: 'photo_message_id,reader_id');
    }, context: 'Upsert photo read for $photoMessageId');
  }
}
