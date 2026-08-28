import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../models/movie_model.dart';
import '../models/movie_rating_model.dart';
import 'supabase_data_service.dart';

/// Service for managing couple's movies, cinema diary, dual ratings, and rewatch history in Supabase
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
            final list = data.map((json) => MovieRatingModel.fromJson(json)).toList();
            list.sort((a, b) => a.watchNumber.compareTo(b.watchNumber));
            return list;
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
          .inFilter('movie_id', movieIds)
          .order('watch_number', ascending: true);

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
        'media_type': movie.mediaType,
        'watch_count': movie.watchCount,
        if (movie.photoUrls.isNotEmpty)
          'photo_urls': movie.photoUrls,
        if (movie.watchedDate != null)
          'watched_date': movie.watchedDate!.toUtc().toIso8601String(),
        'created_at': movie.createdAt.toUtc().toIso8601String(),
      };

      if (movie.id != null && movie.id!.isNotEmpty) {
        data['id'] = movie.id;
      }

      try {
        final response = await _supabase
            .from(_tableName)
            .insert(data)
            .select()
            .single();

        return MovieModel.fromJson(response);
      } catch (insertErr) {
        // Fallback without photo_urls if column is not yet present
        if (data.containsKey('photo_urls')) {
          data.remove('photo_urls');
          final response = await _supabase
              .from(_tableName)
              .insert(data)
              .select()
              .single();
          return MovieModel.fromJson(response);
        }
        rethrow;
      }
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
        'media_type': movie.mediaType,
        'watch_count': movie.watchCount,
        'photo_urls': movie.photoUrls,
        'watched_date': movie.watchedDate?.toUtc().toIso8601String(),
      };

      try {
        await _supabase
            .from(_tableName)
            .update({
              ...data,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', movie.id!);
      } catch (colErr) {
        debugPrint('Updating movie with photo_urls/updated_at failed, retrying without: $colErr');
        data.remove('photo_urls');
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

  /// Plan a rewatch: Moves movie to Watchlist and increments watch_count
  Future<void> planRewatch(MovieModel movie) async {
    if (movie.id == null || movie.id!.isEmpty) {
      throw Exception('Movie ID is required to plan rewatch');
    }

    final newWatchCount = (movie.watchCount < 1 ? 1 : movie.watchCount) + 1;

    try {
      final updateData = <String, dynamic>{
        'status': 'watchlist',
        'watch_count': newWatchCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await _supabase
            .from(_tableName)
            .update(updateData)
            .eq('id', movie.id!);
      } catch (colErr) {
        debugPrint('Updating with updated_at failed in planRewatch, retrying: $colErr');
        await _supabase
            .from(_tableName)
            .update({
              'status': 'watchlist',
              'watch_count': newWatchCount,
            })
            .eq('id', movie.id!);
      }
    } catch (e) {
      debugPrint('Error planning rewatch: $e');
      rethrow;
    }
  }

  /// Upsert a specific partner's rating, review, and watch photos strictly in `movie_ratings`
  Future<void> upsertRating({
    required String movieId,
    required String userId,
    required int rating,
    String? notes,
    List<String>? photoUrls,
    int watchNumber = 1,
  }) async {
    try {
      final ratingData = <String, dynamic>{
        'movie_id': movieId,
        'user_id': userId,
        'rating': rating,
        'notes': notes?.trim(),
        if (photoUrls != null) 'photo_urls': photoUrls,
        'watch_number': watchNumber,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await _supabase
            .from(_ratingsTableName)
            .upsert(ratingData, onConflict: 'movie_id,user_id,watch_number');
      } catch (conflictErr) {
        debugPrint('Upsert with watch_number conflict failed, trying movie_id,user_id fallback: $conflictErr');
        try {
          await _supabase
              .from(_ratingsTableName)
              .upsert(ratingData, onConflict: 'movie_id,user_id');
        } catch (colErr) {
          debugPrint('Upsert with photo_urls failed, retrying without photo_urls: $colErr');
          ratingData.remove('photo_urls');
          await _supabase
              .from(_ratingsTableName)
              .upsert(ratingData, onConflict: 'movie_id,user_id');
        }
      }
    } catch (e) {
      debugPrint('Error upserting movie rating: $e');
      rethrow;
    }
  }

  /// Add a watch photo memory directly to a movie rating
  Future<void> addWatchPhoto({
    required String movieId,
    required String userId,
    required String photoUrl,
    int watchNumber = 1,
    int defaultRating = 5,
  }) async {
    try {
      // 1. Fetch current rating for this user and session
      final response = await _supabase
          .from(_ratingsTableName)
          .select()
          .eq('movie_id', movieId)
          .eq('user_id', userId);

      final records = List<Map<String, dynamic>>.from(response);
      Map<String, dynamic>? match;
      for (final r in records) {
        if (r['watch_number'] == watchNumber) {
          match = r;
          break;
        }
      }
      match ??= records.isNotEmpty ? records.first : null;

      List<String> existingPhotos = [];
      if (match != null && match['photo_urls'] != null) {
        final raw = match['photo_urls'];
        if (raw is List) {
          existingPhotos = raw.map((e) => e.toString()).toList();
        }
      }

      if (!existingPhotos.contains(photoUrl)) {
        existingPhotos.add(photoUrl);
      }

      await upsertRating(
        movieId: movieId,
        userId: userId,
        rating: match != null && match['rating'] != null ? int.tryParse(match['rating'].toString()) ?? defaultRating : defaultRating,
        notes: match?['notes']?.toString(),
        photoUrls: existingPhotos,
        watchNumber: watchNumber,
      );
    } catch (e) {
      debugPrint('Error adding watch photo: $e');
      rethrow;
    }
  }

  /// Remove a watch photo from movie ratings and/or movie record
  Future<void> removeWatchPhoto({
    required String movieId,
    required String userId,
    required String photoUrl,
    int watchNumber = 1,
  }) async {
    try {
      // 1. Fetch all ratings for this movie
      final ratingsResponse = await _supabase
          .from(_ratingsTableName)
          .select()
          .eq('movie_id', movieId);

      for (final r in ratingsResponse) {
        final rRatingId = r['id']?.toString();
        final rawPhotos = r['photo_urls'];
        List<String> photos = [];
        if (rawPhotos is List) {
          photos = rawPhotos.map((e) => e.toString()).toList();
        }
        if (photos.contains(photoUrl)) {
          photos.remove(photoUrl);
          if (rRatingId != null) {
            try {
              await _supabase
                  .from(_ratingsTableName)
                  .update({
                    'photo_urls': photos,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', rRatingId);
            } catch (_) {}
          }
        }
      }

      // Also clean up movie photo_urls if present
      final movieResponse = await _supabase
          .from(_tableName)
          .select('photo_urls')
          .eq('id', movieId)
          .maybeSingle();

      if (movieResponse != null) {
        final rawMoviePhotos = movieResponse['photo_urls'];
        if (rawMoviePhotos is List) {
          final mPhotos = rawMoviePhotos.map((e) => e.toString()).toList();
          if (mPhotos.contains(photoUrl)) {
            mPhotos.remove(photoUrl);
            try {
              await _supabase
                  .from(_tableName)
                  .update({
                    'photo_urls': mPhotos,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', movieId);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error removing watch photo: $e');
      rethrow;
    }
  }

  /// Mark a movie as watched and save the user's personal rating, review, and watch photos strictly in `movie_ratings`
  Future<void> markAsWatchedWithRating({
    required String movieId,
    required String userId,
    required int rating,
    DateTime? watchedDate,
    String? notes,
    List<String>? photoUrls,
    int watchNumber = 1,
  }) async {
    try {
      // 1. Update movie status & watched date safely
      final updateData = <String, dynamic>{
        'status': 'watched',
        'watch_count': watchNumber < 1 ? 1 : watchNumber,
        'watched_date': watchedDate?.toUtc().toIso8601String(),
      };

      try {
        await _supabase
            .from(_tableName)
            .update({
              ...updateData,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
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
        photoUrls: photoUrls,
        watchNumber: watchNumber,
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

  /// Upload a watch snapshot / memory photo to Supabase Storage with Base64 fallback
  Future<String> uploadMoviePhoto(String coupleId, File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist');
      }

      final fileBytes = await imageFile.readAsBytes();
      final optimizedBytes = await _optimizeWatchPhotoImage(fileBytes);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final fileName = 'watch_photo_${coupleId}_$timestamp${fileExtension.isEmpty ? '.jpg' : fileExtension}';

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
        debugPrint('Primary movie bucket upload failed for photo, trying fallback: $bucketError');
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
          debugPrint('Using Base64 encoding fallback for watch photo');
          final base64String = base64Encode(optimizedBytes);
          return 'data:image/jpeg;base64,$base64String';
        }
      }
    } catch (e) {
      debugPrint('Error uploading watch photo: $e');
      try {
        final bytes = await imageFile.readAsBytes();
        final optimized = await _optimizeWatchPhotoImage(bytes);
        return 'data:image/jpeg;base64,${base64Encode(optimized)}';
      } catch (_) {
        throw Exception('Failed to process watch photo: $e');
      }
    }
  }

  /// Optimize watch memory photo dimensions and compression
  Future<Uint8List> _optimizeWatchPhotoImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      img.Image resized = image;
      if (image.width > 1200 || image.height > 1200) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 1200 : null,
          height: image.height >= image.width ? 1200 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      debugPrint('Watch photo image optimization failed, using original: $e');
      return imageBytes;
    }
  }
}
