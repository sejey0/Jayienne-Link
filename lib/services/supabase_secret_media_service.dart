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
      debugPrint('🔍 FETCHING SECRET MEDIA FOR COUPLE_ID: $coupleId');

      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .isFilter('deleted_at', null)
          .order('uploaded_at', ascending: false);

      debugPrint('📸 FOUND ACTIVE SECRET MEDIA COUNT: ${response.length}');

      final allItems = (response as List)
          .map((item) => SecretMediaModel.fromJson(item as Map<String, dynamic>))
          .toList();

      bool isValidMedia(SecretMediaModel media) {
        if (media.id != null && _knownCorruptedIds.contains(media.id)) {
          return false;
        }
        final url = media.mediaUrl.trim();
        return media.deletedAt == null &&
            url.isNotEmpty &&
            url != 'null' &&
            url != 'undefined' &&
            (url.startsWith('http://') || url.startsWith('https://'));
      }

      final seenUrls = <String>{};
      final seenIds = <String>{};
      final result = <SecretMediaModel>[];

      for (final media in allItems) {
        if (!isValidMedia(media)) continue;
        if (media.isHidden && !includeHidden) continue;
        final id = media.id;
        final url = media.mediaUrl.trim();
        if (id != null && seenIds.contains(id)) continue;
        if (seenUrls.contains(url)) continue;
        if (id != null) seenIds.add(id);
        seenUrls.add(url);
        result.add(media);
      }

      result.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return result;
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error fetching secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error fetching secret media: $e');
      rethrow;
    }
  }

  static const Set<String> _knownCorruptedIds = {
    '68123b89-c301-4d47-980f-e7e69c1f825c',
    '517c69a3-79c3-4b46-9786-e046431fe008',
  };

  // Get hidden secret media only (personal vault)
  Future<List<SecretMediaModel>> getHiddenSecretMedia(String coupleId) async {
    try {
      debugPrint('🔍 FETCHING HIDDEN VAULT MEDIA FOR COUPLE_ID: $coupleId');

      // Best-effort cleanup of phantom duplicate IDs in database
      for (final badId in _knownCorruptedIds) {
        _supabase.from(_tableName).delete().eq('id', badId).catchError((_) {});
      }

      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .isFilter('deleted_at', null)
          .order('uploaded_at', ascending: false);

      debugPrint('🔒 FOUND ACTIVE HIDDEN VAULT COUNT: ${response.length}');

      final allItems = (response as List)
          .map((item) => SecretMediaModel.fromJson(item as Map<String, dynamic>))
          .toList();

      bool isValidMedia(SecretMediaModel media) {
        if (media.id != null && _knownCorruptedIds.contains(media.id)) {
          return false;
        }
        final url = media.mediaUrl.trim();
        return media.deletedAt == null &&
            url.isNotEmpty &&
            url != 'null' &&
            url != 'undefined' &&
            (url.startsWith('http://') || url.startsWith('https://'));
      }

      final seenUrls = <String>{};
      final seenIds = <String>{};
      final hiddenResult = <SecretMediaModel>[];

      for (final media in allItems) {
        if (!isValidMedia(media) || !media.isHidden) continue;
        final id = media.id;
        final url = media.mediaUrl.trim();
        if (id != null && seenIds.contains(id)) continue;
        if (seenUrls.contains(url)) continue;
        if (id != null) seenIds.add(id);
        seenUrls.add(url);
        hiddenResult.add(media);
      }

      hiddenResult.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      debugPrint('🔒 FOUND ACTIVE FILTERED HIDDEN VAULT COUNT: ${hiddenResult.length}');
      for (int i = 0; i < hiddenResult.length; i++) {
        final m = hiddenResult[i];
        debugPrint('VAULT_ITEM[$i]: id=${m.id}, type=${m.mediaType}, url=${m.mediaUrl}');
      }

      return hiddenResult;
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

  // Soft delete secret media (marks deleted_at without altering is_hidden)
  Future<void> deleteSecretMedia(String mediaId) async {
    try {
      await _supabase.from(_tableName).update({
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', mediaId);
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
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false);

      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((item) => SecretMediaModel.fromJson(item))
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

  // Restore all soft-deleted hidden vault media for a couple (Admin recovery sync - for Hidden Vault only)
  Future<int> restoreHiddenVaultMedia({String? coupleId}) async {
    try {
      debugPrint('🔄 RESTORING HIDDEN VAULT MEDIA (PARTNER & USER) FOR COUPLE_ID: $coupleId');

      // 1. Try RPC restore_all_hidden_vault_media if defined in Supabase
      try {
        final rpcParams = <String, dynamic>{};
        if (coupleId != null && coupleId.isNotEmpty && coupleId != 'all') {
          rpcParams['target_couple_id'] = coupleId;
        }
        final rpcResult = await _supabase.rpc('restore_all_hidden_vault_media', params: rpcParams);
        if (rpcResult != null) {
          int count = 0;
          if (rpcResult is int) {
            count = rpcResult;
          } else if (rpcResult is List) {
            count = rpcResult.length;
          }
          if (count > 0) {
            debugPrint('✅ RESTORED $count HIDDEN VAULT ITEMS VIA RPC');
            return count;
          }
        }
      } catch (rpcErr) {
        debugPrint('restore_all_hidden_vault_media RPC not available, continuing with item loop: $rpcErr');
      }

      // 2. Fetch all deleted records for the couple (SELECT policy allows both user & partner items)
      dynamic selectBuilder = _supabase
          .from(_tableName)
          .select('id, is_hidden, uploaded_by_id')
          .not('deleted_at', 'is', null);

      if (coupleId != null && coupleId.isNotEmpty && coupleId != 'all') {
        selectBuilder = selectBuilder.eq('couple_id', coupleId);
      }

      final deletedRecords = await selectBuilder;
      final items = (deletedRecords as List);
      debugPrint('📦 FOUND ${items.length} TOTAL DELETED RECORDS FOR COUPLE');

      // Target hidden items or all items to be restored to hidden vault
      final targetItems = items.where((item) {
        final isHidden = item['is_hidden'] == true;
        return isHidden;
      }).toList();

      final itemsToRestore = targetItems.isNotEmpty ? targetItems : items;
      debugPrint('🔒 RESTORING ${itemsToRestore.length} HIDDEN VAULT ITEMS (INCLUDING PARTNER)');

      int restoredCount = 0;
      for (final item in itemsToRestore) {
        final id = item['id']?.toString();
        if (id == null) continue;
        try {
          // Use restoreSecretMedia which calls SECURITY DEFINER RPC to bypass partner RLS restriction
          await restoreSecretMedia(id);
          restoredCount++;
        } catch (err) {
          debugPrint('Error restoring item $id: $err');
          // Fallback direct update
          try {
            await _supabase.from(_tableName).update({
              'deleted_at': null,
              'is_hidden': true,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', id);
            restoredCount++;
          } catch (_) {}
        }
      }

      debugPrint('✅ RESTORED $restoredCount HIDDEN VAULT ITEMS FOR USER & PARTNER');
      return restoredCount;
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error restoring hidden vault media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error restoring hidden vault media: $e');
      rethrow;
    }
  }

  // Restore all soft-deleted secret media for a couple (Admin recovery sync - preserves is_hidden)
  Future<int> restoreAllDeletedMedia({String? coupleId}) async {
    try {
      debugPrint('🔄 RESTORING ALL DELETED MEDIA FOR COUPLE_ID: $coupleId');
      
      dynamic selectBuilder = _supabase
          .from(_tableName)
          .select('id')
          .not('deleted_at', 'is', null);

      if (coupleId != null && coupleId.isNotEmpty && coupleId != 'all') {
        selectBuilder = selectBuilder.eq('couple_id', coupleId);
      }

      final deletedRecords = await selectBuilder;
      final items = (deletedRecords as List);
      final count = items.length;
      debugPrint('📦 FOUND $count DELETED MEDIA ITEMS TO RESTORE');

      int restoredCount = 0;
      for (final item in items) {
        final id = item['id']?.toString();
        if (id == null) continue;
        try {
          await restoreSecretMedia(id);
          restoredCount++;
        } catch (_) {}
      }

      return restoredCount;
    } catch (e) {
      if (_isMissingSecretMediaTable(e)) {
        debugPrint('Error restoring all secret media: $_missingTableHelp');
        throw _tableSetupException();
      }
      debugPrint('Error restoring all secret media: $e');
      rethrow;
    }
  }

  // Restore single deleted secret media (preserves is_hidden)
  Future<SecretMediaModel> restoreSecretMedia(String mediaId) async {
    try {
      // 1. Try Supabase RPC function restore_secret_media
      try {
        final rpcResponse = await _supabase.rpc('restore_secret_media', params: {
          'target_id': mediaId,
        });
        if (rpcResponse != null) {
          if (rpcResponse is List && rpcResponse.isNotEmpty) {
            return SecretMediaModel.fromJson(
                rpcResponse[0] as Map<String, dynamic>);
          } else if (rpcResponse is Map<String, dynamic>) {
            return SecretMediaModel.fromJson(rpcResponse);
          }
        }
      } catch (rpcError) {
        debugPrint(
            'restore_secret_media RPC not available or failed, falling back to direct update: $rpcError');
      }

      // 2. Direct update fallback (ONLY clears deleted_at, preserves original is_hidden)
      final response = await _supabase
          .from(_tableName)
          .update({
            'deleted_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
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
