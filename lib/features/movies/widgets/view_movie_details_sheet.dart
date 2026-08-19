import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import '../../../services/supabase_movie_service.dart';
import 'mark_watched_sheet.dart';
import 'movie_alert_dialog.dart';
import 'movie_poster_widget.dart';

/// Modal bottom sheet displaying detailed dual reviews for a watched movie
/// Supports multi-session Watch History (1st Watch, Rewatch #1, etc.) and "Plan Rewatch" action
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

  @override
  State<ViewMovieDetailsSheet> createState() => _ViewMovieDetailsSheetState();
}

class _ViewMovieDetailsSheetState extends State<ViewMovieDetailsSheet> {
  final SupabaseMovieService _movieService = SupabaseMovieService();
  late int _selectedSession;
  bool _isPlanningRewatch = false;

  @override
  void initState() {
    super.initState();
    // Default to the latest watch session
    _selectedSession = widget.movie.watchCount > 0 ? widget.movie.watchCount : 1;
    final availableSessions = widget.movie.sessionNumbers;
    if (!availableSessions.contains(_selectedSession) && availableSessions.isNotEmpty) {
      _selectedSession = availableSessions.last;
    }
  }

  Future<void> _openRateSheet(BuildContext context, int sessionNum) async {
    HapticFeedback.lightImpact();
    Navigator.pop(context, true); // Close details sheet and signal refresh
    final res = await MarkWatchedSheet.show(
      context,
      movie: widget.movie,
      currentUserId: widget.currentUserId,
      partnerName: widget.partnerName,
      targetWatchNumber: sessionNum,
      onMovieUpdated: widget.onMovieUpdated,
    );
    if (res == true) {
      widget.onMovieUpdated?.call();
    }
  }

  Future<void> _handlePlanRewatch() async {
    HapticFeedback.mediumImpact();
    final nextWatchNum = (widget.movie.watchCount < 1 ? 1 : widget.movie.watchCount) + 1;
    final nextLabel = nextWatchNum == 2 ? 'Rewatch #1' : '${nextWatchNum}th Watch';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.replay_rounded, color: Color(0xFFFF758C), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Plan Rewatch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Move "${widget.movie.title}" back to your Watchlist for $nextLabel with ${widget.partnerName}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.bookmark_add_rounded, size: 16),
            label: const Text('Move to Watchlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF758C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPlanningRewatch = true);
    try {
      await _movieService.planRewatch(widget.movie);
      if (!mounted) return;

      widget.onMovieUpdated?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlanningRewatch = false);
      showCenterAlertDialog(
        context: context,
        title: 'Rewatch Error',
        message: 'Could not plan rewatch: $e',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final movie = widget.movie;
    final sessions = movie.sessionNumbers;

    // Get ratings for the currently selected session
    final myRating = movie.getRatingForUser(widget.currentUserId, watchNumber: _selectedSession);
    final partnerRating = movie.getPartnerRating(widget.currentUserId, watchNumber: _selectedSession);
    final sessionAvg = movie.getAverageRatingForSession(_selectedSession);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                    width: 72,
                    height: 104,
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
                        const SizedBox(height: 4),

                        // Badges Row (Media Type + Watch Count Badge)
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
                                borderRadius: BorderRadius.circular(6),
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
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: movie.isSeries
                                          ? const Color(0xFFA18CD1)
                                          : const Color(0xFFFF758C),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Total Watch Count Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: movie.watchCount > 1
                                    ? const Color(0xFFFF9A8B).withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    movie.watchCount > 1 ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
                                    size: 11,
                                    color: movie.watchCount > 1 ? const Color(0xFFFF758C) : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    movie.watchCount > 1 ? 'Watched ${movie.watchCount}x' : 'Watched 1x',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: movie.watchCount > 1 ? const Color(0xFFFF758C) : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Watched Date
                        if (movie.watchedDate != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 12,
                                color: Color(0xFFA18CD1),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Watched on ${movie.formattedWatchedDate}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFA18CD1)
                                        : const Color(0xFF7E57C2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Session Average Score Badge
                        if (sessionAvg != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  color: Color(0xFFFF4081),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Score: ${sessionAvg.toStringAsFixed(1)} / 5',
                                  style: const TextStyle(
                                    fontSize: 11.5,
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
              const SizedBox(height: 18),

              // ----------------------------------------------------
              // WATCH HISTORY SESSION SELECTOR (IF MULTIPLE WATCHES)
              // ----------------------------------------------------
              if (sessions.length > 1) ...[
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 16, color: Color(0xFFFF758C)),
                    const SizedBox(width: 6),
                    Text(
                      'Watch History Sessions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF2D4059),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: sessions.map((sNum) {
                      final isSelected = sNum == _selectedSession;
                      final label = MovieModel.getSessionLabel(sNum);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            sNum == 1 ? Icons.local_movies_rounded : Icons.replay_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : const Color(0xFFFF758C),
                          ),
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedSession = sNum);
                            }
                          },
                          selectedColor: const Color(0xFFFF758C),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ----------------------------------------------------
              // BOX 1: MY RATING & REVIEW FOR SELECTED SESSION
              // ----------------------------------------------------
              _buildReviewBox(
                title: sessions.length > 1
                    ? 'Your Review (${MovieModel.getSessionLabel(_selectedSession)})'
                    : 'Your Rating & Review',
                accentColor: const Color(0xFFFF758C),
                icon: Icons.person_rounded,
                isDark: isDark,
                hasRated: myRating != null,
                rating: myRating?.rating,
                notes: myRating?.notes,
                actionButton: ElevatedButton.icon(
                  onPressed: () => _openRateSheet(context, _selectedSession),
                  icon: Icon(
                    myRating != null ? Icons.edit_note_rounded : Icons.favorite,
                    size: 16,
                  ),
                  label: Text(
                    myRating != null ? 'Edit My Review' : 'Add My Review',
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
              const SizedBox(height: 14),

              // ----------------------------------------------------
              // BOX 2: PARTNER'S RATING & REVIEW FOR SELECTED SESSION
              // ----------------------------------------------------
              _buildReviewBox(
                title: sessions.length > 1
                    ? "${widget.partnerName}'s Review (${MovieModel.getSessionLabel(_selectedSession)})"
                    : "${widget.partnerName}'s Rating & Review",
                accentColor: const Color(0xFFA18CD1),
                icon: Icons.favorite_rounded,
                isDark: isDark,
                hasRated: partnerRating != null,
                rating: partnerRating?.rating,
                notes: partnerRating?.notes,
                emptyMessage: "Partner hasn't reviewed this watch yet",
              ),
              const SizedBox(height: 20),

              // ----------------------------------------------------
              // BOTTOM ACTION: "PLAN REWATCH" BUTTON
              // ----------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isPlanningRewatch ? null : _handlePlanRewatch,
                  icon: _isPlanningRewatch
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF758C),
                          ),
                        )
                      : const Icon(Icons.replay_rounded, size: 18, color: Color(0xFFFF758C)),
                  label: Text(
                    _isPlanningRewatch
                        ? 'Planning Rewatch...'
                        : 'Plan Rewatch (${(movie.watchCount < 1 ? 1 : movie.watchCount) + 1}th Watch)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF758C),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF758C), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: const Color(0xFFFF758C).withValues(alpha: 0.05),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
