import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import 'movie_poster_widget.dart';

/// Modal bottom sheet displaying Movie Details, Dates, Synopsis, and Edit/Delete Options
class ViewMovieDetailsSheet extends StatefulWidget {
  final MovieModel movie;
  final String currentUserId;
  final String partnerName;
  final VoidCallback? onMovieUpdated;
  final VoidCallback? onEditMovie;
  final VoidCallback? onDeleteMovie;

  const ViewMovieDetailsSheet({
    super.key,
    required this.movie,
    required this.currentUserId,
    required this.partnerName,
    this.onMovieUpdated,
    this.onEditMovie,
    this.onDeleteMovie,
  });

  static Future<dynamic> show(
    BuildContext context, {
    required MovieModel movie,
    required String currentUserId,
    required String partnerName,
    VoidCallback? onMovieUpdated,
    VoidCallback? onEditMovie,
    VoidCallback? onDeleteMovie,
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
      ),
    );
  }

  @override
  State<ViewMovieDetailsSheet> createState() => _ViewMovieDetailsSheetState();
}

class _ViewMovieDetailsSheetState extends State<ViewMovieDetailsSheet> {
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
            color: isDark ? const Color(0xFF1C1427) : const Color(0xFFFFF9FA),
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
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.movie_creation_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Movie Details',
                              style: TextStyle(
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

                  // Movie Card Row: Poster + Title (Year) + Badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Movie Poster
                      MoviePosterWidget(
                        posterUrl: movie.posterUrl,
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
                            const SizedBox(height: 5),

                            // Badges Row (Media Type + Status)
                            Wrap(
                              spacing: 5,
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
                  const SizedBox(height: 12),

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
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Added Date with time
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
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
                  const SizedBox(height: 14),

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
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text(
                              'Edit Movie',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF2D4059),
                              side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                              ),
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
