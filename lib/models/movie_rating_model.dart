/// Model representing an individual partner's rating and review for a movie session
class MovieRatingModel {
  final String? id;
  final String movieId;
  final String userId;
  final int rating; // 1 to 5
  final String? notes;
  final int watchNumber; // 1 for 1st watch, 2 for 1st rewatch, etc.
  final DateTime updatedAt;

  const MovieRatingModel({
    this.id,
    required this.movieId,
    required this.userId,
    required this.rating,
    this.notes,
    this.watchNumber = 1,
    required this.updatedAt,
  });

  factory MovieRatingModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return fallback;
      }
    }

    return MovieRatingModel(
      id: json['id']?.toString(),
      movieId: json['movie_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      rating: json['rating'] != null
          ? int.tryParse(json['rating'].toString()) ?? 5
          : 5,
      notes: json['notes']?.toString(),
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
      'watch_number': watchNumber,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MovieRatingModel copyWith({
    String? id,
    String? movieId,
    String? userId,
    int? rating,
    String? notes,
    int? watchNumber,
    DateTime? updatedAt,
  }) {
    return MovieRatingModel(
      id: id ?? this.id,
      movieId: movieId ?? this.movieId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      watchNumber: watchNumber ?? this.watchNumber,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
