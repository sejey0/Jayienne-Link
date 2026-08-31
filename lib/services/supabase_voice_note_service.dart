import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voice_note_model.dart';

class SupabaseVoiceNoteService {
  final SupabaseClient _supabase;
  static const String _tableName = 'couple_voice_notes';

  RealtimeChannel? _realtimeSubscription;

  SupabaseVoiceNoteService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  /// Upload an audio file/bytes to Supabase storage with automatic fallback bucket loop
  Future<String> uploadAudio({
    required dynamic audioSource, // File or Uint8List
    required String coupleId,
    required String fileName,
  }) async {
    final path = '$coupleId/$fileName';
    final candidateBuckets = [
      'voice-notes',
      'chat-photos',
      'profile-photos',
      'secret-media',
    ];

    Uint8List bytes;
    if (audioSource is Uint8List) {
      bytes = audioSource;
    } else if (audioSource is File) {
      bytes = await audioSource.readAsBytes();
    } else {
      throw ArgumentError('Unsupported audioSource type: ${audioSource.runtimeType}');
    }

    dynamic lastError;
    for (final bucket in candidateBuckets) {
      try {
        debugPrint('[SupabaseVoiceNoteService] Attempting upload to bucket: $bucket');
        await _supabase.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'audio/m4a',
                upsert: true,
              ),
            );

        final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);
        debugPrint('[SupabaseVoiceNoteService] Upload succeeded in bucket: $bucket -> $publicUrl');
        return publicUrl;
      } catch (e) {
        debugPrint('[SupabaseVoiceNoteService] Bucket $bucket failed: $e');
        lastError = e;
      }
    }

    throw lastError ?? Exception('Failed to upload audio to any storage bucket.');
  }

  /// Fetch all voice notes for a couple
  Future<List<VoiceNoteModel>> getVoiceNotes(String coupleId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((item) => VoiceNoteModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseVoiceNoteService] getVoiceNotes error: $e');
      rethrow;
    }
  }

  /// Send a new voice note
  Future<VoiceNoteModel> sendVoiceNote(VoiceNoteModel note) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .insert(note.toInsertJson())
          .select()
          .single();

      return VoiceNoteModel.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseVoiceNoteService] sendVoiceNote error: $e');
      rethrow;
    }
  }

  /// Mark voice note as listened
  Future<void> markAsListened(String noteId) async {
    try {
      await _supabase
          .from(_tableName)
          .update({'is_listened': true})
          .eq('id', noteId);
    } catch (e) {
      debugPrint('[SupabaseVoiceNoteService] markAsListened error: $e');
    }
  }

  /// Delete a voice note
  Future<void> deleteVoiceNote(String noteId, {String? audioUrl}) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', noteId);

      // Attempt to clean up storage if URL is available
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(audioUrl);
          final segments = uri.pathSegments;
          final bucketIndex = segments.indexOf('public');
          if (bucketIndex != -1 && bucketIndex + 2 < segments.length) {
            final bucket = segments[bucketIndex + 1];
            final filePath = segments.sublist(bucketIndex + 2).join('/');
            await _supabase.storage.from(bucket).remove([filePath]);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SupabaseVoiceNoteService] deleteVoiceNote error: $e');
      rethrow;
    }
  }

  /// Subscribe to realtime updates for couple's voice notes
  void subscribeToVoiceNotes(String coupleId, {required VoidCallback onUpdate}) {
    unsubscribe();

    try {
      _realtimeSubscription = _supabase
          .channel('public:$_tableName:$coupleId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'couple_id',
              value: coupleId,
            ),
            callback: (payload) {
              debugPrint('[SupabaseVoiceNoteService] Realtime payload received: ${payload.eventType}');
              onUpdate();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[SupabaseVoiceNoteService] subscribe error: $e');
    }
  }

  void unsubscribe() {
    if (_realtimeSubscription != null) {
      try {
        _supabase.removeChannel(_realtimeSubscription!);
      } catch (_) {}
      _realtimeSubscription = null;
    }
  }
}
