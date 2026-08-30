import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import '../../../services/supabase_movie_service.dart';
import 'movie_alert_dialog.dart';
import 'movie_poster_widget.dart';

/// Bottom sheet allowing a partner to submit or edit their individual rating & review,
/// set optional watched dates, attach watch photos/memories, and mark the movie as watched in real-time.
class MarkWatchedSheet extends StatefulWidget {
  final MovieModel movie;
  final String currentUserId;
  final String partnerName;
  final int? targetWatchNumber;
  final VoidCallback? onMovieUpdated;

  const MarkWatchedSheet({
    super.key,
    required this.movie,
    required this.currentUserId,
    required this.partnerName,
    this.targetWatchNumber,
    this.onMovieUpdated,
  });

  static Future<dynamic> show(
    BuildContext context, {
    required MovieModel movie,
    required String currentUserId,
    required String partnerName,
    int? targetWatchNumber,
    VoidCallback? onMovieUpdated,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MarkWatchedSheet(
        movie: movie,
        currentUserId: currentUserId,
        partnerName: partnerName,
        targetWatchNumber: targetWatchNumber,
        onMovieUpdated: onMovieUpdated,
      ),
    );
  }

  @override
  State<MarkWatchedSheet> createState() => _MarkWatchedSheetState();
}

class _MarkWatchedSheetState extends State<MarkWatchedSheet> {
  final SupabaseMovieService _movieService = SupabaseMovieService();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _notesController;

  int? _selectedRating; // Null by default for clean start unless editing own rating
  DateTime? _selectedDate;
  List<String> _existingPhotos = [];
  final List<File> _newPhotoFiles = [];
  bool _isUploadingPhotos = false;
  bool _isSubmitting = false;

  int get _effectiveWatchNumber => widget.targetWatchNumber ?? widget.movie.watchCount;

  @override
  void initState() {
    super.initState();
    // Strictly read ONLY current user's rating for the specified watch session
    final myRating = widget.movie.getRatingForUser(
      widget.currentUserId,
      watchNumber: _effectiveWatchNumber,
    );
    _selectedRating = myRating?.rating;
    _notesController = TextEditingController(text: myRating?.notes ?? '');
    _selectedDate = widget.movie.watchedDate;
    _existingPhotos = [...myRating?.photoUrls ?? []];
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();
    final initial = _selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF758C),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2D4059),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearDate() {
    HapticFeedback.selectionClick();
    setState(() => _selectedDate = null);
  }

  Future<void> _pickGalleryPhotos() async {
    HapticFeedback.selectionClick();
    try {
      final pickedList = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (pickedList.isNotEmpty) {
        setState(() {
          for (final picked in pickedList) {
            _newPhotoFiles.add(File(picked.path));
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking memory photos: $e');
      if (mounted) {
        showCenterAlertDialog(
          context: context,
          title: 'Photo Selection Failed',
          message: 'Could not select photos: $e',
          icon: Icons.image_not_supported_rounded,
          iconColor: AppColors.error,
        );
      }
    }
  }

  Future<void> _pickCameraPhoto() async {
    HapticFeedback.selectionClick();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _newPhotoFiles.add(File(picked.path));
        });
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        showCenterAlertDialog(
          context: context,
          title: 'Camera Error',
          message: 'Could not capture photo: $e',
          icon: Icons.camera_alt_outlined,
          iconColor: AppColors.error,
        );
      }
    }
  }

  void _removeExistingPhoto(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _existingPhotos.removeAt(index);
    });
  }

  void _removeNewPhoto(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _newPhotoFiles.removeAt(index);
    });
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

  Future<void> _submit() async {
    if (widget.movie.id == null || widget.currentUserId.isEmpty) return;

    if (_selectedRating == null || _selectedRating! <= 0) {
      HapticFeedback.selectionClick();
      showCenterAlertDialog(
        context: context,
        title: 'Rating Required',
        message: 'Please tap a heart (1 to 5) to rate this movie before saving.',
        icon: Icons.favorite_border_rounded,
        iconColor: const Color(0xFFFF758C),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final uploadedUrls = <String>[];
      if (_newPhotoFiles.isNotEmpty) {
        setState(() => _isUploadingPhotos = true);
        for (final file in _newPhotoFiles) {
          final url = await _movieService.uploadMoviePhoto(
            widget.movie.coupleId.isNotEmpty ? widget.movie.coupleId : 'couple',
            file,
          );
          uploadedUrls.add(url);
        }
        setState(() => _isUploadingPhotos = false);
      }

      final finalPhotos = [..._existingPhotos, ...uploadedUrls];

      await _movieService.markAsWatchedWithRating(
        movieId: widget.movie.id!,
        userId: widget.currentUserId,
        rating: _selectedRating!,
        watchedDate: _selectedDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        photoUrls: finalPhotos,
        watchNumber: _effectiveWatchNumber,
      );

      if (!mounted) return;

      widget.onMovieUpdated?.call();
      Navigator.pop(context, {
        'action': 'update_rating',
        'title': widget.movie.title,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isUploadingPhotos = false;
      });
      showCenterAlertDialog(
        context: context,
        title: 'Failed to Save',
        message: 'Could not save your rating: $e',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final partnerRating = widget.movie.getPartnerRating(widget.currentUserId);
    final hasMyExistingRating =
        widget.movie.getRatingForUser(widget.currentUserId) != null;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E162B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.2),
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
              const SizedBox(height: 18),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasMyExistingRating ? Icons.edit_note_rounded : Icons.star_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasMyExistingRating ? 'Edit Your Rating' : 'Rate & Review',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: isDark ? Colors.white : const Color(0xFF2D4059),
                              ),
                        ),
                        Text(
                          'Your personal thoughts and score',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
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

              // Movie Preview Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFFFF5F7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    MoviePosterWidget(
                      posterUrl: widget.movie.posterUrl,
                      width: 50,
                      height: 72,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.movie.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF2D4059),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                widget.movie.isSeries
                                    ? Icons.tv_rounded
                                    : Icons.movie_rounded,
                                size: 14,
                                color: const Color(0xFFFF758C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.movie.isSeries
                                    ? 'Series'
                                    : (widget.movie.isWatched ? 'Watched Movie' : 'Watchlist Entry'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFF758C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.movie.year != null && widget.movie.year!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '•  ${widget.movie.year}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Partner Rating Insight Banner (strictly partnerRating only)
              if (partnerRating != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFA18CD1).withValues(alpha: 0.15)
                        : const Color(0xFFA18CD1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA18CD1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA18CD1).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 16,
                          color: Color(0xFFA18CD1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "${widget.partnerName}'s Rating:",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF2D4059),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Row(
                                  children: List.generate(5, (index) {
                                    final isFilled = index < partnerRating.rating;
                                    return Icon(
                                      isFilled ? Icons.favorite : Icons.favorite_border,
                                      size: 13,
                                      color: isFilled
                                          ? const Color(0xFFFF4081)
                                          : Colors.grey.shade400,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            if (partnerRating.notes != null && partnerRating.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '"${partnerRating.notes!}"',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Heart Rating Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Rating',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2D4059),
                    ),
                  ),
                  if (_selectedRating != null && _selectedRating! > 0)
                    Text(
                      '$_selectedRating of 5 Hearts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF758C),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFFF758C).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      final isFilled = _selectedRating != null && starNum <= _selectedRating!;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedRating = starNum);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedScale(
                            scale: isFilled ? 1.15 : 0.95,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              isFilled ? Icons.favorite : Icons.favorite_border,
                              color: isFilled
                                  ? const Color(0xFFFF4081)
                                  : (isDark ? Colors.white38 : Colors.grey.shade400),
                              size: 34,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Watched Date Selector (Optional)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Date Watched (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF2D4059),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedDate != null)
                    TextButton.icon(
                      onPressed: _clearDate,
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      label: const Text('Clear Date', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFFF758C),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)
                              : 'Tap to select date (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _selectedDate != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.grey.shade500),
                          ),
                        ),
                      ),
                      Icon(
                        _selectedDate != null
                            ? Icons.edit_calendar_rounded
                            : Icons.add_circle_outline_rounded,
                        color: const Color(0xFFFF758C),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Notes / Review Text Area
              Text(
                'Your Review & Notes (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF2D4059),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'What did you think of the movie? Favorite scenes or thoughts...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF758C),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ----------------------------------------------------
              // WATCH MEMORIES & PHOTOS (OPTIONAL)
              // ----------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_rounded,
                        color: Color(0xFFFF758C),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Watch Photos & Memories (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF2D4059),
                        ),
                      ),
                    ],
                  ),
                  if (_existingPhotos.length + _newPhotoFiles.length > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_existingPhotos.length + _newPhotoFiles.length} photo${_existingPhotos.length + _newPhotoFiles.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF758C),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Action Buttons to Add Photo (Gallery Bulk Select & Camera)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickGalleryPhotos,
                      icon: const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFFFF758C)),
                      label: const Text('Bulk Select', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF758C),
                        side: BorderSide(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFFF758C).withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCameraPhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFFA18CD1)),
                      label: const Text('Take a Photo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA18CD1),
                        side: BorderSide(
                          color: const Color(0xFFA18CD1).withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFA18CD1).withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ],
              ),

              // Horizontal Thumbnails Preview List
              if (_existingPhotos.isNotEmpty || _newPhotoFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Existing uploaded photos
                      ..._existingPhotos.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final url = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: () => _showImageZoomDialog(context, url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    width: 80,
                                    height: 85,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 80,
                                      height: 85,
                                      color: Colors.grey.withValues(alpha: 0.15),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF758C)),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 80,
                                      height: 85,
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      child: const Icon(Icons.broken_image_rounded, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeExistingPhoto(idx),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // New picked local image files
                      ..._newPhotoFiles.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final file = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  file,
                                  width: 80,
                                  height: 85,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeNewPhoto(idx),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isUploadingPhotos ? 'Uploading photos...' : 'Saving...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                hasMyExistingRating ? 'Update Your Rating' : 'Save Your Rating',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
}
