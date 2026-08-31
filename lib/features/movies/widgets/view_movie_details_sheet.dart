import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import 'movie_poster_widget.dart';

/// Modal bottom sheet displaying Movie Details, Dates, Synopsis, and Edit/Delete Options
/// Fully aligned to the Jayienne Link romantic aesthetic
class ViewMovieDetailsSheet extends StatefulWidget {
  final MovieModel movie;
  final String currentUserId;
  final String partnerName;
  final VoidCallback? onMovieUpdated;
  final VoidCallback? onEditMovie;
  final VoidCallback? onDeleteMovie;
  final VoidCallback? onPlanRewatch;
  final VoidCallback? onCancelRewatch;

  const ViewMovieDetailsSheet({
    super.key,
    required this.movie,
    required this.currentUserId,
    required this.partnerName,
    this.onMovieUpdated,
    this.onEditMovie,
    this.onDeleteMovie,
    this.onPlanRewatch,
    this.onCancelRewatch,
  });

  static Future<dynamic> show(
    BuildContext context, {
    required MovieModel movie,
    required String currentUserId,
    required String partnerName,
    VoidCallback? onMovieUpdated,
    VoidCallback? onEditMovie,
    VoidCallback? onDeleteMovie,
    VoidCallback? onPlanRewatch,
    VoidCallback? onCancelRewatch,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 440),
      builder: (context) => ViewMovieDetailsSheet(
        movie: movie,
        currentUserId: currentUserId,
        partnerName: partnerName,
        onMovieUpdated: onMovieUpdated,
        onEditMovie: onEditMovie,
        onDeleteMovie: onDeleteMovie,
        onPlanRewatch: onPlanRewatch,
        onCancelRewatch: onCancelRewatch,
      ),
    );
  }

  @override
  State<ViewMovieDetailsSheet> createState() => _ViewMovieDetailsSheetState();
}

class _ViewMovieDetailsSheetState extends State<ViewMovieDetailsSheet> {
  late int _selectedSessionNumber;

  @override
  void initState() {
    super.initState();
    _selectedSessionNumber = widget.movie.watchCount;
  }

  String _getOrdinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final movie = widget.movie;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1224) : const Color(0xFFFFF9FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.softRose.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Header: Gradient Badge "Movie Details" + Close Button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              movie.isSeries ? 'Series Details' : 'Movie Details',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Movie Card Row: Poster + Title (Year) + Badges in a themed card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFFF758C).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Movie Poster (Tap to view full screen)
                        MoviePosterWidget(
                          posterUrl: movie.posterUrl,
                          title: movie.title,
                          year: movie.year,
                          date: movie.isWatched ? movie.formattedWatchedDate : movie.formattedCreatedDate,
                          width: 56,
                          height: 80,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const SizedBox(width: 12),

                        // Movie Title & Badges
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: movie.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF2D4059),
                                  ),
                                  children: [
                                    if (movie.year != null && movie.year!.isNotEmpty)
                                      TextSpan(
                                        text: ' (${movie.year})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              // Badges Row (Media Type + Status)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  // Media Type Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: movie.isSeries
                                          ? const Color(0xFFA18CD1).withValues(alpha: 0.15)
                                          : const Color(0xFFFF758C).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          movie.isSeries ? Icons.tv_rounded : Icons.movie_rounded,
                                          size: 11,
                                          color: movie.isSeries
                                              ? const Color(0xFFA18CD1)
                                              : const Color(0xFFFF758C),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          movie.isSeries ? 'Series' : 'Movie',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: movie.isSeries
                                                ? const Color(0xFFA18CD1)
                                                : const Color(0xFFFF758C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Watch Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: movie.isWatchlist
                                          ? const Color(0xFFFF758C).withValues(alpha: 0.15)
                                          : const Color(0xFFA18CD1).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          movie.isWatchlist
                                              ? Icons.bookmark_outline_rounded
                                              : Icons.check_circle_outline_rounded,
                                          size: 11,
                                          color: movie.isWatchlist
                                              ? const Color(0xFFFF758C)
                                              : const Color(0xFFA18CD1),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          movie.isWatchlist
                                              ? 'In Watchlist'
                                              : (movie.watchCount > 1
                                                  ? 'Watched ${movie.watchCount}x'
                                                  : 'Watched'),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: movie.isWatchlist
                                                ? const Color(0xFFFF758C)
                                                : const Color(0xFFA18CD1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ----------------------------------------------------
                  // DATES SECTION (Added Date & Watched Date)
                  // ----------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFFF758C).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Added Date with time
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Color(0xFFFF758C),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Added ${movie.formattedCreatedDateTime}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Watched Date (if watched)
                        if (movie.watchedDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 13,
                                color: Color(0xFFA18CD1),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Watched on ${movie.formattedWatchedDate}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFA18CD1) : const Color(0xFF7E57C2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ----------------------------------------------------
                  // MOVIE SYNOPSIS & NOTES
                  // ----------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.notes_rounded,
                              size: 14,
                              color: Color(0xFFFF758C),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Synopsis & Notes',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2D4059),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          movie.notes != null && movie.notes!.trim().isNotEmpty
                              ? movie.notes!.trim()
                              : 'No synopsis or notes added for this movie.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: movie.notes != null && movie.notes!.trim().isNotEmpty
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.grey.shade500),
                            fontStyle: movie.notes != null && movie.notes!.trim().isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ----------------------------------------------------
                  // WATCH SESSIONS / REWATCH VERSION SELECTOR (IF MULTIPLE)
                  // ----------------------------------------------------
                  if (movie.sessionNumbers.length > 1) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: movie.sessionNumbers.map((sessionNum) {
                          final isSelected = sessionNum == _selectedSessionNumber;
                          final label = sessionNum == 1
                              ? '1st Watch'
                              : '$sessionNum${_getOrdinalSuffix(sessionNum)} Watch (Rewatch)';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedSessionNumber = sessionNum);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      sessionNum == 1 ? Icons.movie_rounded : Icons.replay_rounded,
                                      size: 12,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ----------------------------------------------------
                  // COUPLE REVIEWS & RATINGS (IF WATCHED / RATED)
                  // ----------------------------------------------------
                  Builder(
                    builder: (context) {
                      final myRating = movie.getRatingForUser(
                        widget.currentUserId,
                        watchNumber: _selectedSessionNumber,
                      );
                      final partnerRating = movie.getPartnerRating(
                        widget.currentUserId,
                        watchNumber: _selectedSessionNumber,
                      );
                      final myReview = myRating?.notes?.trim();
                      final partnerReview = partnerRating?.notes?.trim();
                      final hasMyReview = myReview != null && myReview.isNotEmpty;
                      final hasPartnerReview = partnerReview != null && partnerReview.isNotEmpty;
                      final hasRatings = (myRating != null && myRating.rating > 0) ||
                          (partnerRating != null && partnerRating.rating > 0) ||
                          hasMyReview ||
                          hasPartnerReview;

                      if (!hasRatings) return const SizedBox.shrink();

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 14,
                                  color: Color(0xFFFF758C),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  movie.sessionNumbers.length > 1
                                      ? 'Couple Reviews (Watch #$_selectedSessionNumber)'
                                      : 'Couple Reviews & Ratings',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // 1. Your Rating & Review
                            if (myRating != null && (myRating.rating > 0 || hasMyReview)) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF758C).withValues(alpha: isDark ? 0.08 : 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF758C).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Your Review',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF758C),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (myRating.rating > 0) ...[
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(5, (index) {
                                              final isFilled = index < myRating.rating;
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 1.5),
                                                child: Icon(
                                                  isFilled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                  size: 13,
                                                  color: isFilled
                                                      ? const Color(0xFFFF4081)
                                                      : (isDark ? Colors.white30 : Colors.grey.shade400),
                                                ),
                                              );
                                            }),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${myRating.rating}/5',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF4081),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (hasMyReview) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '"$myReview"',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.4,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            if ((myRating != null && (myRating.rating > 0 || hasMyReview)) &&
                                (partnerRating != null && (partnerRating.rating > 0 || hasPartnerReview)))
                              const SizedBox(height: 8),

                            // 2. Partner Rating & Review
                            if (partnerRating != null && (partnerRating.rating > 0 || hasPartnerReview)) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFA18CD1).withValues(alpha: isDark ? 0.08 : 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFA18CD1).withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFA18CD1).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            "${widget.partnerName}'s Review",
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFA18CD1),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (partnerRating.rating > 0) ...[
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(5, (index) {
                                              final isFilled = index < partnerRating.rating;
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 1.5),
                                                child: Icon(
                                                  isFilled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                  size: 13,
                                                  color: isFilled
                                                      ? const Color(0xFFFF4081)
                                                      : (isDark ? Colors.white30 : Colors.grey.shade400),
                                                ),
                                              );
                                            }),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${partnerRating.rating}/5',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF4081),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (hasPartnerReview) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '"$partnerReview"',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.4,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),



                  // ----------------------------------------------------
                  // CANCEL REWATCH (IF CURRENTLY PLANNED REWATCH IN WATCHLIST)
                  // ----------------------------------------------------
                  if (movie.isWatchlist && movie.isRewatch && widget.onCancelRewatch != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          widget.onCancelRewatch?.call();
                        },
                        icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFA18CD1)),
                        label: const Text(
                          'Cancel Rewatch',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA18CD1),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA18CD1),
                          side: BorderSide(color: const Color(0xFFA18CD1).withValues(alpha: 0.4)),
                          backgroundColor: const Color(0xFFA18CD1).withValues(alpha: 0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ----------------------------------------------------
                  // 2 OPTIONS: EDIT DETAILS & REMOVE MOVIE
                  // ----------------------------------------------------
                  Row(
                    children: [
                      // Edit Movie Details Button
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              widget.onEditMovie?.call();
                            },
                            icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFFFF758C)),
                            label: const Text(
                              'Edit Details',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF2D4059),
                              side: BorderSide(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                              ),
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFFF758C).withValues(alpha: 0.05),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Remove Movie Button
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              widget.onDeleteMovie?.call();
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: AppColors.error.withValues(alpha: 0.35),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: AppColors.error.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
