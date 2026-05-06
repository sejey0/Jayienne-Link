import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/secret_media_model.dart';

class SupabaseSecretMediaService {
  final SupabaseClient _supabase;
  static const String _tableName = 'secret_media';
  static const String _missingTableHelp =
      'Secret Media is not configured in Supabase yet. Run secret_media_schema.sql in the Supabase SQL Editor.';

  SupabaseSecretMediaService(this._supabase);

  bool _isMissingSecretMediaTable(Object error) {
    return error is PostgrestException && error.code == 'PGRST205';
  }

  Exception _tableSetupException() {
    return Exception(_missingTableHelp);
  }

  // Get all secret media for a couple
  Future<List<SecretMediaModel>> getSecretMedia(String coupleId,
      {bool includeHidden = false}) async {
    try {
      List<dynamic> response;

      if (includeHidden) {
        response = await _supabase
            .from(_tableName)
            .select()
            .eq('couple_id', coupleId)
            .order('uploaded_at', ascending: false);
      } else {
        response = await _supabase
            .from(_tableName)
            .select()
            .eq('couple_id', coupleId)
            .eq('is_hidden', false)
            .order('uploaded_at', ascending: false);
      }

      return response
          .map(
              (item) => SecretMediaModel.fromJson(item as Map<String, dynamic>))
          .where((media) => media.deletedAt == null)
          .toList();
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error fetching secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error fetching secret media: $e');
      rethrow;
    }
  }

  // Get hidden secret media only (personal vault)
  Future<List<SecretMediaModel>> getHiddenSecretMedia(String coupleId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .eq('is_hidden', true)
          .order('uploaded_at', ascending: false);

      return (response as List)
          .map(
              (item) => SecretMediaModel.fromJson(item as Map<String, dynamic>))
          .where((media) => media.deletedAt == null)
          .toList();
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error fetching hidden secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error fetching hidden secret media: $e');
      rethrow;
    }
  }

  // Add new secret media
  Future<SecretMediaModel> addSecretMedia({
    required String coupleId,
    required String uploadedById,
    required String mediaType,
    required String mediaUrl,
    String? thumbnail,
    String? caption,
    bool isEncrypted = true,
    bool isHidden = false,
  }) async {
    try {
      final response = await _supabase.from(_tableName).insert({
        'couple_id': coupleId,
        'uploaded_by_id': uploadedById,
        'media_type': mediaType,
        'media_url': mediaUrl,
        'thumbnail': thumbnail,
        'caption': caption,
        'uploaded_at': DateTime.now().toIso8601String(),
        'is_encrypted': isEncrypted,
        'is_hidden': isHidden,
      }).select();

      if (response.isEmpty) {
        throw Exception('Failed to add secret media');
      }

      return SecretMediaModel.fromJson(response[0]);
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error adding secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error adding secret media: $e');
      rethrow;
    }
  }

  // Update secret media caption or hidden status
  Future<SecretMediaModel> updateSecretMedia({
    required String mediaId,
    String? caption,
    bool? isHidden,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (caption != null) updates['caption'] = caption;
      if (isHidden != null) updates['is_hidden'] = isHidden;

      if (updates.isEmpty) {
        throw Exception('No updates provided');
      }

      final response = await _supabase
          .from(_tableName)
          .update(updates)
          .eq('id', mediaId)
          .select();

      if (response.isEmpty) {
        throw Exception('Failed to update secret media');
      }

      return SecretMediaModel.fromJson(response[0]);
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error updating secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error updating secret media: $e');
      rethrow;
    }
  }

  // Soft delete secret media (moves to trash)
  Future<void> deleteSecretMedia(String mediaId) async {
    try {
      await _supabase.from(_tableName).update(
          {'deleted_at': DateTime.now().toIso8601String()}).eq('id', mediaId);
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error deleting secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error deleting secret media: $e');
      rethrow;
    }
  }

  // Get deleted (trash) secret media
  Future<List<SecretMediaModel>> getDeletedSecretMedia(String coupleId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .order('deleted_at', ascending: false);

      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((item) => SecretMediaModel.fromJson(item))
          .where((media) => media.deletedAt != null)
          .toList();
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error fetching deleted secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error fetching deleted secret media: $e');
      rethrow;
    }
  }

  // Restore deleted secret media
  Future<SecretMediaModel> restoreSecretMedia(String mediaId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .update({'deleted_at': null as dynamic})
          .eq('id', mediaId)
          .select();

      if (response.isEmpty) {
        throw Exception('Failed to restore secret media');
      }

      return SecretMediaModel.fromJson(response[0]);
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error restoring secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error restoring secret media: $e');
      rethrow;
    }
  }

  // Permanently delete secret media
  Future<void> permanentlyDeleteSecretMedia(String mediaId) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', mediaId);
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint(
            'Error permanently deleting secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error permanently deleting secret media: $e');
      rethrow;
    }
  }

  // Stream secret media updates
  Stream<List<SecretMediaModel>> streamSecretMedia(String coupleId) {
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('couple_id', coupleId)
        .order('uploaded_at', ascending: false)
        .map((data) => (data as List)
            .cast<Map<String, dynamic>>()
            .map((item) => SecretMediaModel.fromJson(item))
            .toList())
        .handleError((error) {
          if (_isMissingSecretMediaTable(error)) {
            throw _tableSetupException();
          }
          throw error;
        });
  }

  // Toggle hidden status (move to vault or make visible)
  Future<SecretMediaModel> toggleHidden(
      String mediaId, bool shouldBeHidden) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .update({'is_hidden': shouldBeHidden})
          .eq('id', mediaId)
          .select();

      if (response.isEmpty) {
        throw Exception('Failed to toggle hidden status');
      }

      return SecretMediaModel.fromJson(response[0]);
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error toggling hidden status: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error toggling hidden status: $e');
      rethrow;
    }
  }
}
