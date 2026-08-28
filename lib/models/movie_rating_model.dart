import 'dart:convert';

/// Model representing an individual partner's rating and review for a movie session
class MovieRatingModel {
  final String? id;
  final String movieId;
  final String userId;
  final int rating; // 1 to 5
  final String? notes;
  final List<String> photoUrls; // Watch memories / photos taken while watching
  final int watchNumber; // 1 for 1st watch, 2 for 1st rewatch, etc.
  final DateTime updatedAt;

  const MovieRatingModel({
    this.id,
    required this.movieId,
    required this.userId,
    required this.rating,
    this.notes,
    this.photoUrls = const [],
    this.watchNumber = 1,
    required this.updatedAt,
  });

  factory MovieRatingModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is DateTime) return value.toLocal();
      try {
        return DateTime.parse(value.toString()).toLocal();
      } catch (_) {
        return fallback;
      }
    }

    List<String> parsePhotos(dynamic value) {
      if (value == null) return const [];
      if (value is List) {
        return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (value is String) {
        if (value.trim().isEmpty) return const [];
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          }
        } catch (_) {}
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    return MovieRatingModel(
      id: json['id']?.toString(),
      movieId: json['movie_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      rating: json['rating'] != null
          ? int.tryParse(json['rating'].toString()) ?? 5
          : 5,
      notes: json['notes']?.toString(),
      photoUrls: parsePhotos(json['photo_urls'] ?? json['photos']),
      watchNumber: json['watch_number'] != null
          ? int.tryParse(json['watch_number'].toString()) ?? 1
          : 1,
      updatedAt: parseDateTime(
        json['updated_at'] ?? json['created_at'],
        DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id!.isNotEmpty) 'id': id,
      'movie_id': movieId,
      'user_id': userId,
      'rating': rating,
      'notes': notes,
      'photo_urls': photoUrls,
      'watch_number': watchNumber,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  MovieRatingModel copyWith({
    String? id,
    String? movieId,
    String? userId,
    int? rating,
    String? notes,
    List<String>? photoUrls,
    int? watchNumber,
    DateTime? updatedAt,
  }) {
    return MovieRatingModel(
      id: id ?? this.id,
      movieId: movieId ?? this.movieId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      photoUrls: photoUrls ?? this.photoUrls,
      watchNumber: watchNumber ?? this.watchNumber,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
