import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_movie_service.dart';
import '../../../widgets/smart_profile_image.dart';
import 'mark_watched_sheet.dart';
import 'movie_alert_dialog.dart';
import 'movie_poster_widget.dart';

/// Modal bottom sheet displaying detailed dual reviews for a watched movie
/// Supports multi-session Watch History (1st Watch, Rewatch #1, etc.), Watch Photo Memories, and "Plan Rewatch" action
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
  final SupabaseMovieService _movieService = SupabaseMovieService();
  final ImagePicker _imagePicker = ImagePicker();
  late int _selectedSession;
  bool _isPlanningRewatch = false;
  bool _isUploadingQuickPhoto = false;

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

  void _showImageZoomDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF758C)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.black87,
                    child: const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 40),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleQuickAddBulkPhotos() async {
    HapticFeedback.selectionClick();
    if (widget.movie.id == null || widget.currentUserId.isEmpty) return;

    try {
      final pickedList = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (pickedList.isEmpty) return;

      setState(() => _isUploadingQuickPhoto = true);
      HapticFeedback.mediumImpact();

      final myRating = widget.movie.getRatingForUser(
        widget.currentUserId,
        watchNumber: _selectedSession,
      );

      for (final picked in pickedList) {
        final uploadedUrl = await _movieService.uploadMoviePhoto(
          widget.movie.coupleId.isNotEmpty ? widget.movie.coupleId : 'couple',
          File(picked.path),
        );

        await _movieService.addWatchPhoto(
          movieId: widget.movie.id!,
          userId: widget.currentUserId,
          photoUrl: uploadedUrl,
          watchNumber: _selectedSession,
          defaultRating: myRating?.rating ?? 5,
        );
      }

      if (!mounted) return;
      setState(() => _isUploadingQuickPhoto = false);

      widget.onMovieUpdated?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingQuickPhoto = false);
      showCenterAlertDialog(
        context: context,
        title: 'Upload Failed',
        message: 'Could not upload memory photos: $e',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
      );
    }
  }

  Future<void> _handleQuickAddCameraPhoto() async {
    HapticFeedback.selectionClick();
    if (widget.movie.id == null || widget.currentUserId.isEmpty) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _isUploadingQuickPhoto = true);
      HapticFeedback.mediumImpact();

      final uploadedUrl = await _movieService.uploadMoviePhoto(
        widget.movie.coupleId.isNotEmpty ? widget.movie.coupleId : 'couple',
        File(picked.path),
      );

      final myRating = widget.movie.getRatingForUser(
        widget.currentUserId,
        watchNumber: _selectedSession,
      );

      await _movieService.addWatchPhoto(
        movieId: widget.movie.id!,
        userId: widget.currentUserId,
        photoUrl: uploadedUrl,
        watchNumber: _selectedSession,
        defaultRating: myRating?.rating ?? 5,
      );

      if (!mounted) return;
      setState(() => _isUploadingQuickPhoto = false);

      widget.onMovieUpdated?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingQuickPhoto = false);
      showCenterAlertDialog(
        context: context,
        title: 'Camera Upload Failed',
        message: 'Could not upload snapshot: $e',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
      );
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
    if (res != null) {
      widget.onMovieUpdated?.call();
    }
  }

  Future<void> _handlePlanRewatch() async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextWatchNum = (widget.movie.watchCount < 1 ? 1 : widget.movie.watchCount) + 1;
    final nextLabel = nextWatchNum == 2 ? 'Rewatch #1' : '${nextWatchNum}th Watch';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.replay_rounded, color: Color(0xFFFF758C), size: 32),
            ),
            const SizedBox(height: 14),

            // 2. Title
            Text(
              'Plan Rewatch',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D4059),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Subtitle / Message
            Text(
              'Move "${widget.movie.title}" back to your Watchlist for $nextLabel with ${widget.partnerName}?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // 4. Primary Button (Move to Watchlist)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.bookmark_added_rounded, size: 18),
                label: const Text(
                  'Move to Watchlist',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF758C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 5. Centered Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isPlanningRewatch = true);
    try {
      await _movieService.planRewatch(widget.movie);
      if (!mounted) return;

      widget.onMovieUpdated?.call();
      Navigator.pop(context, {
        'action': 'plan_rewatch',
        'title': widget.movie.title,
      });
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
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final myPhotoUrl = userProvider.user?.photoUrl;
    final partnerPhotoUrl = coupleProvider.partner?.photoUrl;
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

                        // Watched Date & Added Date
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
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: isDark ? Colors.white54 : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Added ${movie.formattedCreatedDate}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

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
              // ----------------------------------------------------
              // BOX 1: MY RATING & REVIEW FOR SELECTED SESSION
              // ----------------------------------------------------
              _buildReviewBox(
                title: sessions.length > 1
                    ? 'Your Review (${MovieModel.getSessionLabel(_selectedSession)})'
                    : 'Your Rating & Review',
                accentColor: const Color(0xFFFF758C),
                icon: Icons.person_rounded,
                avatarUrl: myPhotoUrl,
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
                avatarUrl: partnerPhotoUrl,
                isDark: isDark,
                hasRated: partnerRating != null,
                rating: partnerRating?.rating,
                notes: partnerRating?.notes,
                emptyMessage: "Partner hasn't reviewed this watch yet",
              ),
              const SizedBox(height: 16),

              // ----------------------------------------------------
              // BOX 3: DEDICATED WATCH MEMORIES & DATE SNAPSHOTS
              // ----------------------------------------------------
              _buildWatchMemoriesSection(
                isDark: isDark,
                photos: widget.movie.getWatchPhotosForSession(_selectedSession),
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

  Widget _buildWatchMemoriesSection({
    required bool isDark,
    required List<String> photos,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E162B)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFFF758C).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch Memories',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF2D4059),
                        ),
                      ),
                      Text(
                        'Photos & snapshots during movie night',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (photos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${photos.length} photo${photos.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF758C),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Bulk Select (Gallery) & Take Snapshot (Camera)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploadingQuickPhoto ? null : _handleQuickAddBulkPhotos,
                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                  label: const Text(
                    'Bulk Select',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF758C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploadingQuickPhoto ? null : _handleQuickAddCameraPhoto,
                  icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFFA18CD1)),
                  label: const Text(
                    'Take Snapshot',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFA18CD1),
                    side: BorderSide(color: const Color(0xFFA18CD1).withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isUploadingQuickPhoto) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF758C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF758C)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Uploading memory photos...',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFFFF758C),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Photos Grid Display
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: photos.length == 1 ? 1 : (photos.length == 2 ? 2 : 3),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: photos.length == 1 ? 1.6 : 1.0,
              ),
              itemBuilder: (context, index) {
                final url = photos[index];
                return GestureDetector(
                  onTap: () => _showImageZoomDialog(context, url),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.withValues(alpha: 0.15),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF758C),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Icon(Icons.broken_image_rounded, size: 24),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ] else if (!_isUploadingQuickPhoto) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 24,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No memories added yet. Tap Bulk Select or Take Snapshot to capture your movie snacks or cuddle setup!',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: isDark ? Colors.white38 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String? photoUrl,
    required Color accentColor,
    required IconData fallbackIcon,
    double size = 28,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: SmartProfileImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: Container(
            width: size,
            height: size,
            color: accentColor.withValues(alpha: 0.15),
            child: Icon(fallbackIcon, size: size * 0.55, color: accentColor),
          ),
          errorWidget: Container(
            width: size,
            height: size,
            color: accentColor.withValues(alpha: 0.15),
            child: Icon(fallbackIcon, size: size * 0.55, color: accentColor),
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
    String? avatarUrl,
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
              _buildAvatar(
                photoUrl: avatarUrl,
                accentColor: accentColor,
                fallbackIcon: icon,
                size: 28,
              ),
              const SizedBox(width: 10),
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
