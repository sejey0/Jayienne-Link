import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../models/movie_model.dart';
import '../models/movie_rating_model.dart';
import 'supabase_data_service.dart';

/// Service for managing couple's movies and cinema diary in Supabase
class SupabaseMovieService {
  static const String _tableName = 'movies';
  static const String _ratingsTableName = 'movie_ratings';
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

  /// Stream all partner ratings with real-time auto-sync
  Stream<List<MovieRatingModel>> streamMovieRatings() {
    try {
      return _supabase
          .from(_ratingsTableName)
          .stream(primaryKey: ['id'])
          .map((data) {
            return data.map((json) => MovieRatingModel.fromJson(json)).toList();
          });
    } catch (e) {
      debugPrint('Error initiating real-time movie ratings stream: $e');
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

  /// Single fetch of ratings for a list of movie IDs
  Future<List<MovieRatingModel>> fetchMovieRatings(List<String> movieIds) async {
    if (movieIds.isEmpty) return [];

    try {
      final response = await _supabase
          .from(_ratingsTableName)
          .select()
          .inFilter('movie_id', movieIds);

      final records = List<Map<String, dynamic>>.from(response);
      return records.map((json) => MovieRatingModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching movie ratings: $e');
      return [];
    }
  }

  /// Add a new movie to Watchlist or Watched history
  Future<MovieModel?> addMovie(MovieModel movie) async {
    try {
      final data = <String, dynamic>{
        'couple_id': movie.coupleId,
        'title': movie.title,
        if (movie.posterUrl != null && movie.posterUrl!.isNotEmpty)
          'poster_url': movie.posterUrl,
        'status': movie.status,
        if (movie.watchedDate != null)
          'watched_date': movie.watchedDate!.toIso8601String(),
        'created_at': movie.createdAt.toIso8601String(),
      };

      if (movie.id != null && movie.id!.isNotEmpty) {
        data['id'] = movie.id;
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

  /// Update an existing movie entry (metadata only, ratings are isolated in movie_ratings)
  Future<void> updateMovie(MovieModel movie) async {
    if (movie.id == null || movie.id!.isEmpty) {
      throw Exception('Movie ID is required for update');
    }

    try {
      final data = <String, dynamic>{
        'couple_id': movie.coupleId,
        'title': movie.title,
        'poster_url': movie.posterUrl,
        'status': movie.status,
        'watched_date': movie.watchedDate?.toIso8601String(),
      };

      try {
        await _supabase
            .from(_tableName)
            .update({
              ...data,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', movie.id!);
      } catch (colErr) {
        debugPrint('Updating movie with updated_at failed, retrying without updated_at: $colErr');
        await _supabase
            .from(_tableName)
            .update(data)
            .eq('id', movie.id!);
      }
    } catch (e) {
      debugPrint('Error updating movie: $e');
      rethrow;
    }
  }

  /// Upsert a specific partner's rating and review strictly in `movie_ratings`
  Future<void> upsertRating({
    required String movieId,
    required String userId,
    required int rating,
    String? notes,
  }) async {
    try {
      final ratingData = <String, dynamic>{
        'movie_id': movieId,
        'user_id': userId,
        'rating': rating,
        'notes': notes?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from(_ratingsTableName)
          .upsert(ratingData, onConflict: 'movie_id,user_id');
    } catch (e) {
      debugPrint('Error upserting movie rating: $e');
      rethrow;
    }
  }

  /// Mark a movie as watched and save the user's personal rating & review strictly in `movie_ratings`
  Future<void> markAsWatchedWithRating({
    required String movieId,
    required String userId,
    required int rating,
    DateTime? watchedDate,
    String? notes,
  }) async {
    try {
      // 1. Update movie status & watched date safely (no shared rating written to movies table)
      final updateData = <String, dynamic>{
        'status': 'watched',
        'watched_date': watchedDate?.toIso8601String(),
      };

      try {
        await _supabase
            .from(_tableName)
            .update({
              ...updateData,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', movieId);
      } catch (colErr) {
        debugPrint('Failed to set updated_at on movie, retrying without: $colErr');
        await _supabase
            .from(_tableName)
            .update(updateData)
            .eq('id', movieId);
      }

      // 2. Upsert the partner's rating strictly in movie_ratings
      await upsertRating(
        movieId: movieId,
        userId: userId,
        rating: rating,
        notes: notes,
      );
    } catch (e) {
      debugPrint('Error marking movie as watched with rating: $e');
      rethrow;
    }
  }

  /// Delete a movie and its cascade ratings from the cinema diary
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
          debugPrint('Using Base64 encoding fallback for movie poster');
          final base64String = base64Encode(optimizedBytes);
          return 'data:image/jpeg;base64,$base64String';
        }
      }
    } catch (e) {
      debugPrint('Error uploading poster: $e');
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
