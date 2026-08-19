import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import 'mark_watched_sheet.dart';
import 'movie_poster_widget.dart';

/// Modal bottom sheet displaying detailed dual reviews for a watched movie
/// Shows Box 1 (My Rating with Edit/Add button) and Box 2 (Partner's Rating read-only)
class ViewMovieDetailsSheet extends StatelessWidget {
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

  static Future<bool?> show(
    BuildContext context, {
    required MovieModel movie,
    required String currentUserId,
    required String partnerName,
    VoidCallback? onMovieUpdated,
  }) {
    return showModalBottomSheet<bool>(
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

  Future<void> _openRateSheet(BuildContext context) async {
    HapticFeedback.lightImpact();
    Navigator.pop(context, true); // Close details sheet and signal refresh
    final res = await MarkWatchedSheet.show(
      context,
      movie: movie,
      currentUserId: currentUserId,
      partnerName: partnerName,
      onMovieUpdated: onMovieUpdated,
    );
    if (res == true) {
      onMovieUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Strict isolation: ONLY query ratings from movie_ratings
    final myRating = movie.getRatingForUser(currentUserId);
    final partnerRating = movie.getPartnerRating(currentUserId);
    final calculatedAvg = movie.calculatedAverageRating;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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

              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MoviePosterWidget(
                    posterUrl: movie.posterUrl,
                    width: 70,
                    height: 102,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2D4059),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (movie.watchedDate != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 14,
                                color: Color(0xFFA18CD1),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Watched on ${movie.formattedWatchedDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFA18CD1)
                                      : const Color(0xFF7E57C2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (calculatedAvg != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  color: Color(0xFFFF4081),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Overall Score: ${calculatedAvg.toStringAsFixed(1)} / 5',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF4081),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ----------------------------------------------------
              // BOX 1: MY RATING & REVIEW (WITH EDIT / ADD ACTION)
              // ----------------------------------------------------
              _buildReviewBox(
                title: 'Your Rating & Review',
                accentColor: const Color(0xFFFF758C),
                icon: Icons.person_rounded,
                isDark: isDark,
                hasRated: myRating != null,
                rating: myRating?.rating,
                notes: myRating?.notes,
                actionButton: ElevatedButton.icon(
                  onPressed: () => _openRateSheet(context),
                  icon: Icon(
                    myRating != null ? Icons.edit_note_rounded : Icons.favorite,
                    size: 16,
                  ),
                  label: Text(
                    myRating != null ? 'Edit My Rating' : 'Add My Rating',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF758C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ----------------------------------------------------
              // BOX 2: PARTNER'S RATING & REVIEW (READ-ONLY)
              // ----------------------------------------------------
              _buildReviewBox(
                title: "$partnerName's Rating & Review",
                accentColor: const Color(0xFFA18CD1),
                icon: Icons.favorite_rounded,
                isDark: isDark,
                hasRated: partnerRating != null,
                rating: partnerRating?.rating,
                notes: partnerRating?.notes,
                emptyMessage: "Partner hasn't rated this movie yet",
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewBox({
    required String title,
    required Color accentColor,
    required IconData icon,
    required bool isDark,
    required bool hasRated,
    int? rating,
    String? notes,
    Widget? actionButton,
    String emptyMessage = "You haven't rated this movie yet",
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Box Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D4059),
                  ),
                ),
              ),
              if (hasRated && rating != null) ...[
                Row(
                  children: List.generate(5, (index) {
                    final isFilled = index < rating;
                    return Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        isFilled ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFilled ? const Color(0xFFFF4081) : Colors.grey.shade400,
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Content or Empty Placeholder
          if (hasRated) ...[
            if (notes != null && notes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : accentColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : accentColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  '"$notes"',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF333333),
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Rated ${rating ?? 5} / 5 (No written review)',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: actionButton,
              ),
            ],
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    emptyMessage,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: actionButton,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
