import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../models/movie_model.dart';
import 'supabase_data_service.dart';

/// Service for managing couple's movies and cinema diary in Supabase
class SupabaseMovieService {
  static const String _tableName = 'movies';
  static const String _storageBucket = 'movie-posters';
  static const String _fallbackStorageBucket = 'chat-photos';

  SupabaseClient get _supabase => SupabaseDataService.client;

  /// Stream all movies for a given couple with real-time updates
  Stream<List<MovieModel>> streamMovies(String coupleId) {
    if (coupleId.isEmpty) {
      return Stream.value([]);
    }

    try {
      return _supabase
          .from(_tableName)
          .stream(primaryKey: ['id'])
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false)
          .map((data) {
            return data.map((json) => MovieModel.fromJson(json)).toList();
          });
    } catch (e) {
      debugPrint('Error initiating real-time movie stream: $e');
      return Stream.value([]);
    }
  }

  /// Single fetch of all movies for a given couple
  Future<List<MovieModel>> fetchMovies(String coupleId) async {
    if (coupleId.isEmpty) return [];

    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      return records.map((json) => MovieModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching movies: $e');
      return [];
    }
  }

  /// Add a new movie to Watchlist or Watched history
  Future<MovieModel?> addMovie(MovieModel movie) async {
    try {
      final data = movie.toJson();
      // Remove id if it's null so Postgres generates uuid
      if (movie.id == null || movie.id!.isEmpty) {
        data.remove('id');
      }

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      return MovieModel.fromJson(response);
    } catch (e) {
      debugPrint('Error adding movie: $e');
      rethrow;
    }
  }

  /// Update an existing movie entry
  Future<void> updateMovie(MovieModel movie) async {
    if (movie.id == null || movie.id!.isEmpty) {
      throw Exception('Movie ID is required for update');
    }

    try {
      final data = movie.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from(_tableName)
          .update(data)
          .eq('id', movie.id!);
    } catch (e) {
      debugPrint('Error updating movie: $e');
      rethrow;
    }
  }

  /// Mark a movie as watched with ratings, date, and review notes
  Future<void> markAsWatched({
    required String movieId,
    required int rating,
    required DateTime watchedDate,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': 'watched',
        'rating': rating,
        'watched_date': watchedDate.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (notes != null && notes.trim().isNotEmpty) {
        updateData['notes'] = notes.trim();
      }

      await _supabase
          .from(_tableName)
          .update(updateData)
          .eq('id', movieId);
    } catch (e) {
      debugPrint('Error marking movie as watched: $e');
      rethrow;
    }
  }

  /// Delete a movie from the cinema diary
  Future<void> deleteMovie(String movieId) async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', movieId);
    } catch (e) {
      debugPrint('Error deleting movie: $e');
      rethrow;
    }
  }

  /// Upload movie poster to Supabase Storage with Base64 fallback
  Future<String> uploadMoviePoster(String coupleId, File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist');
      }

      final fileBytes = await imageFile.readAsBytes();
      final optimizedBytes = await _optimizePosterImage(fileBytes);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final fileName = 'movie_${coupleId}_$timestamp${fileExtension.isEmpty ? '.jpg' : fileExtension}';

      try {
        // Try uploading to movie-posters or fallback bucket
        await _supabase.storage
            .from(_storageBucket)
            .uploadBinary(
              fileName,
              optimizedBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        return _supabase.storage.from(_storageBucket).getPublicUrl(fileName);
      } catch (bucketError) {
        debugPrint('Primary movie bucket upload failed, trying fallback: $bucketError');
        try {
          await _supabase.storage
              .from(_fallbackStorageBucket)
              .uploadBinary(
                fileName,
                optimizedBytes,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );

          return _supabase.storage.from(_fallbackStorageBucket).getPublicUrl(fileName);
        } catch (_) {
          // If storage bucket is not configured or blocked by RLS, use Base64 data URI
          debugPrint('Using Base64 encoding fallback for movie poster');
          final base64String = base64Encode(optimizedBytes);
          return 'data:image/jpeg;base64,$base64String';
        }
      }
    } catch (e) {
      debugPrint('Error uploading poster: $e');
      // Read bytes and encode as Base64 fallback
      try {
        final bytes = await imageFile.readAsBytes();
        final optimized = await _optimizePosterImage(bytes);
        return 'data:image/jpeg;base64,${base64Encode(optimized)}';
      } catch (_) {
        throw Exception('Failed to process poster image: $e');
      }
    }
  }

  /// Optimize poster image dimensions and compression
  Future<Uint8List> _optimizePosterImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Posters look best around 600x900 or max width 600
      img.Image resized = image;
      if (image.width > 600 || image.height > 900) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 600 : null,
          height: image.height >= image.width ? 900 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      debugPrint('Poster image optimization failed, using original: $e');
      return imageBytes;
    }
  }
}
