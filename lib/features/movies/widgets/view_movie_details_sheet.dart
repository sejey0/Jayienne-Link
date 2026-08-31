import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import 'movie_poster_widget.dart';

/// Modal bottom sheet displaying ONLY the date and details of a movie (Title, Year, Type, Synopsis, Dates)
class ViewMovieDetailsSheet extends StatefulWidget {
  final MovieModel movie;
  final String currentUserId;
  final String partnerName;
  final VoidCallback? onMovieUpdated;

  const ViewMovieDetailsSheet({
    super.key,
    required this.movie,
    required this.currentUserId,
    required this.partnerName,
    this.onMovieUpdated,
  });

  static Future<dynamic> show(
    BuildContext context, {
    required MovieModel movie,
    required String currentUserId,
    required String partnerName,
    VoidCallback? onMovieUpdated,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ViewMovieDetailsSheet(
        movie: movie,
        currentUserId: currentUserId,
        partnerName: partnerName,
        onMovieUpdated: onMovieUpdated,
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1427) : const Color(0xFFFFF9FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.softRose.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row: Poster + Title + Badges + Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Movie Poster
                  MoviePosterWidget(
                    posterUrl: movie.posterUrl,
                    width: 78,
                    height: 112,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  const SizedBox(width: 16),

                  // Movie Title & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: movie.title,
                            style: TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF2D4059),
                            ),
                            children: [
                              if (movie.year != null && movie.year!.isNotEmpty)
                                TextSpan(
                                  text: ' (${movie.year})',
                                  style: TextStyle(
                                    fontSize: 14.5,
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
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: movie.isSeries
                                    ? const Color(0xFFA18CD1).withValues(alpha: 0.15)
                                    : const Color(0xFFFF758C).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    movie.isSeries ? Icons.tv_rounded : Icons.movie_rounded,
                                    size: 12,
                                    color: movie.isSeries
                                        ? const Color(0xFFA18CD1)
                                        : const Color(0xFFFF758C),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    movie.isSeries ? 'Series' : 'Movie',
                                    style: TextStyle(
                                      fontSize: 10.5,
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
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: movie.isWatchlist
                                    ? const Color(0xFFFF758C).withValues(alpha: 0.15)
                                    : const Color(0xFFA18CD1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
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
                                  const SizedBox(width: 4),
                                  Text(
                                    movie.isWatchlist
                                        ? 'In Watchlist'
                                        : (movie.watchCount > 1
                                            ? 'Watched ${movie.watchCount}x'
                                            : 'Watched'),
                                    style: TextStyle(
                                      fontSize: 10.5,
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

                  // Close button
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ----------------------------------------------------
              // DATES SECTION (Added Date & Watched Date)
              // ----------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFFF758C).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
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
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Added ${movie.formattedCreatedDateTime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Watched Date (if watched)
                    if (movie.watchedDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            size: 14,
                            color: Color(0xFFA18CD1),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Watched on ${movie.formattedWatchedDate}',
                              style: TextStyle(
                                fontSize: 12,
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
              const SizedBox(height: 16),

              // ----------------------------------------------------
              // MOVIE DETAILS & SYNOPSIS SECTION
              // ----------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
                          size: 16,
                          color: Color(0xFFFF758C),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Movie Details & Synopsis',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2D4059),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      movie.notes != null && movie.notes!.trim().isNotEmpty
                          ? movie.notes!.trim()
                          : 'No synopsis or notes added for this movie.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
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
              const SizedBox(height: 20),

              // ----------------------------------------------------
              // BOTTOM CLOSE BUTTON
              // ----------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF2D4059),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
