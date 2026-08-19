import 'package:intl/intl.dart';
import 'movie_rating_model.dart';

/// PostgreSQL-compatible MovieModel for Supabase `movies` table in Jayienne Link
/// Features full Rewatch support and multi-session watch history
class MovieModel {
  final String? id;
  final String coupleId;
  final String title;
  final String? posterUrl;
  final String status; // 'watchlist' or 'watched'
  final String mediaType; // 'movie' or 'series'
  final int watchCount; // Total times watched (1 for 1st watch, 2 for 2nd watch, etc.)
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
    this.mediaType = 'movie',
    this.watchCount = 1,
    this.rating,
    this.notes,
    this.watchedDate,
    required this.createdAt,
    this.updatedAt,
    this.ratings = const [],
  });

  bool get isWatched => status == 'watched';
  bool get isWatchlist => status == 'watchlist';
  bool get isSeries => mediaType == 'series';
  bool get isMovie => mediaType != 'series';
  bool get isRewatch => watchCount > 1;

  /// Returns a clean romantic badge label, e.g. "Rewatch #1" or "3rd Watch"
  String get rewatchBadgeLabel {
    if (watchCount <= 1) return '';
    if (watchCount == 2) return 'Rewatch #1';
    if (watchCount == 3) return 'Rewatch #2';
    return '${watchCount}th Watch';
  }

  /// Label for the current watch session
  String get currentWatchLabel {
    if (watchCount <= 1) return '1st Watch';
    if (watchCount == 2) return 'Rewatch #1';
    if (watchCount == 3) return 'Rewatch #2';
    return '${watchCount}th Watch';
  }

  /// Label for any specific session number
  static String getSessionLabel(int sessionNumber) {
    if (sessionNumber <= 1) return '1st Watch';
    if (sessionNumber == 2) return 'Rewatch #1';
    if (sessionNumber == 3) return 'Rewatch #2';
    return '${sessionNumber}th Watch';
  }

  String get formattedWatchedDate {
    if (watchedDate == null) return '';
    return DateFormat('MMM d, yyyy').format(watchedDate!.toLocal());
  }

  String get formattedCreatedDate {
    return DateFormat('MMM d, yyyy').format(createdAt.toLocal());
  }

  /// Calculates average rating across latest session (or all ratings)
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

  /// Average score for a specific watch session
  double? getAverageRatingForSession(int sessionNum) {
    final sessionRatings = ratings.where((r) => r.watchNumber == sessionNum && r.rating > 0).toList();
    if (sessionRatings.isNotEmpty) {
      final total = sessionRatings.fold<int>(0, (sum, r) => sum + r.rating);
      return total / sessionRatings.length;
    }
    return null;
  }

  /// Gets all distinct session numbers recorded in ratings + current watchCount
  List<int> get sessionNumbers {
    final nums = <int>{1};
    if (watchCount > 1) {
      for (int i = 1; i <= watchCount; i++) {
        nums.add(i);
      }
    }
    for (final r in ratings) {
      if (r.watchNumber > 0) {
        nums.add(r.watchNumber);
      }
    }
    final sorted = nums.toList()..sort();
    return sorted;
  }

  /// Gets the rating submitted by the specified user for a given watchNumber (or latest session)
  MovieRatingModel? getRatingForUser(String userId, {int? watchNumber}) {
    if (userId.isEmpty) return null;
    if (watchNumber != null) {
      try {
        return ratings.firstWhere((r) => r.userId == userId && r.watchNumber == watchNumber);
      } catch (_) {
        return null;
      }
    }

    // Default to the rating with the highest watchNumber for this user
    final userRatings = ratings.where((r) => r.userId == userId).toList()
      ..sort((a, b) => b.watchNumber.compareTo(a.watchNumber));
    return userRatings.isNotEmpty ? userRatings.first : null;
  }

  /// Gets the partner's rating for a given watchNumber (or latest session)
  MovieRatingModel? getPartnerRating(String myUserId, {int? watchNumber}) {
    if (myUserId.isEmpty) return null;
    if (watchNumber != null) {
      try {
        return ratings.firstWhere((r) => r.userId.isNotEmpty && r.userId != myUserId && r.watchNumber == watchNumber);
      } catch (_) {
        return null;
      }
    }

    // Default to partner's rating with the highest watchNumber
    final partnerRatings = ratings.where((r) => r.userId.isNotEmpty && r.userId != myUserId).toList()
      ..sort((a, b) => b.watchNumber.compareTo(a.watchNumber));
    return partnerRatings.isNotEmpty ? partnerRatings.first : null;
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
      mediaType: json['media_type']?.toString() ?? 'movie',
      watchCount: json['watch_count'] != null
          ? int.tryParse(json['watch_count'].toString()) ?? 1
          : 1,
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
      'media_type': mediaType,
      'watch_count': watchCount,
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
    String? mediaType,
    int? watchCount,
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
      mediaType: mediaType ?? this.mediaType,
      watchCount: watchCount ?? this.watchCount,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      watchedDate: watchedDate ?? this.watchedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ratings: ratings ?? this.ratings,
    );
  }
}
