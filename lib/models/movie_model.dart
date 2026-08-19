import 'package:intl/intl.dart';
import 'movie_rating_model.dart';

/// PostgreSQL-compatible MovieModel for Supabase `movies` table in Jayienne Link
class MovieModel {
  final String? id;
  final String coupleId;
  final String title;
  final String? posterUrl;
  final String status; // 'watchlist' or 'watched'
  final int? rating; // Legacy fallback single rating
  final String? notes; // Legacy fallback notes
  final DateTime? watchedDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<MovieRatingModel> ratings; // Dual Partner Ratings from movie_ratings

  const MovieModel({
    this.id,
    required this.coupleId,
    required this.title,
    this.posterUrl,
    this.status = 'watchlist',
    this.rating,
    this.notes,
    this.watchedDate,
    required this.createdAt,
    this.updatedAt,
    this.ratings = const [],
  });

  bool get isWatched => status == 'watched';
  bool get isWatchlist => status == 'watchlist';

  String get formattedWatchedDate {
    if (watchedDate == null) return '';
    return DateFormat('MMM d, yyyy').format(watchedDate!.toLocal());
  }

  String get formattedCreatedDate {
    return DateFormat('MMM d, yyyy').format(createdAt.toLocal());
  }

  /// Calculates average rating strictly from partner ratings in movie_ratings
  double? get calculatedAverageRating {
    if (ratings.isNotEmpty) {
      final validRatings = ratings.where((r) => r.rating > 0).toList();
      if (validRatings.isNotEmpty) {
        final total = validRatings.fold<int>(0, (sum, r) => sum + r.rating);
        return total / validRatings.length;
      }
    }
    return null;
  }

  /// Gets the rating submitted by the specified user
  MovieRatingModel? getRatingForUser(String userId) {
    if (userId.isEmpty) return null;
    try {
      return ratings.firstWhere((r) => r.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Gets the partner's rating (strictly where userId != myUserId and userId is not empty)
  MovieRatingModel? getPartnerRating(String myUserId) {
    if (myUserId.isEmpty) return null;
    try {
      return ratings.firstWhere((r) => r.userId.isNotEmpty && r.userId != myUserId);
    } catch (_) {
      return null;
    }
  }

  factory MovieModel.fromJson(Map<String, dynamic> json, {List<MovieRatingModel> ratings = const []}) {
    DateTime parseDateTime(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return fallback;
      }
    }

    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return MovieModel(
      id: json['id']?.toString(),
      coupleId: json['couple_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Movie',
      posterUrl: json['poster_url']?.toString(),
      status: json['status']?.toString() ?? 'watchlist',
      rating: json['rating'] != null ? int.tryParse(json['rating'].toString()) : null,
      notes: json['notes']?.toString(),
      watchedDate: parseNullableDateTime(json['watched_date']),
      createdAt: parseDateTime(json['created_at'], DateTime.now()),
      updatedAt: parseNullableDateTime(json['updated_at']),
      ratings: ratings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id!.isNotEmpty) 'id': id,
      'couple_id': coupleId,
      'title': title,
      'poster_url': posterUrl,
      'status': status,
      'watched_date': watchedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  MovieModel copyWith({
    String? id,
    String? coupleId,
    String? title,
    String? posterUrl,
    String? status,
    int? rating,
    String? notes,
    DateTime? watchedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MovieRatingModel>? ratings,
  }) {
    return MovieModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      watchedDate: watchedDate ?? this.watchedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ratings: ratings ?? this.ratings,
    );
  }
}
