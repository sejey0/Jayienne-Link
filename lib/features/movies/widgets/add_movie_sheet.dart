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

/// Modal bottom sheet for adding or editing movie/series details
/// Features:
/// - Media Type Selector: Movie vs Series
/// - Dynamic Visibility:
///   - "Plan to Watch" (watchlist): Title, Media Type, Poster selection
///   - "Already Watched" (watched): Title, Media Type, Poster, 1-5 Heart Rating, Watched Date, Review Notes, and Watch Memories Photos
class AddMovieSheet extends StatefulWidget {
  final String coupleId;
  final String currentUserId;
  final String initialStatus; // 'watchlist' or 'watched'
  final MovieModel? movieToEdit;
  final VoidCallback? onMovieAdded;

  const AddMovieSheet({
    super.key,
    required this.coupleId,
    this.currentUserId = '',
    this.initialStatus = 'watchlist',
    this.movieToEdit,
    this.onMovieAdded,
  });

  static Future<dynamic> show(
    BuildContext context, {
    required String coupleId,
    String currentUserId = '',
    String initialStatus = 'watchlist',
    MovieModel? movieToEdit,
    VoidCallback? onMovieAdded,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMovieSheet(
        coupleId: coupleId,
        currentUserId: currentUserId,
        initialStatus: initialStatus,
        movieToEdit: movieToEdit,
        onMovieAdded: onMovieAdded,
      ),
    );
  }

  @override
  State<AddMovieSheet> createState() => _AddMovieSheetState();
}

class _AddMovieSheetState extends State<AddMovieSheet> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseMovieService _movieService = SupabaseMovieService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _yearController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _posterUrlController;
  late final TextEditingController _notesController;

  late String _status; // 'watchlist' or 'watched'
  late String _mediaType; // 'movie' or 'series'
  int _rating = 5;
  DateTime? _watchedDate;
  File? _selectedImageFile;
  List<String> _existingWatchPhotos = [];
  final List<File> _newWatchPhotoFiles = [];
  bool _isUploadingPoster = false;
  bool _isUploadingWatchPhotos = false;
  bool _isSaving = false;
  int _posterInputMode = 0; // 0: Gallery pick, 1: Poster URL

  bool get _isEditMode => widget.movieToEdit != null;

  @override
  void initState() {
    super.initState();
    final editMovie = widget.movieToEdit;
    final myRating = editMovie?.getRatingForUser(widget.currentUserId);

    _titleController = TextEditingController(text: editMovie?.title ?? '');
    _yearController = TextEditingController(text: editMovie?.year ?? '');
    _descriptionController = TextEditingController(text: editMovie?.notes ?? '');
    _posterUrlController = TextEditingController(text: editMovie?.posterUrl ?? '');
    _notesController = TextEditingController(text: myRating?.notes ?? '');
    _status = editMovie?.status ?? widget.initialStatus;
    _mediaType = editMovie?.mediaType ?? 'movie';
    _watchedDate = editMovie?.watchedDate;
    _rating = myRating?.rating ?? 5;
    _existingWatchPhotos = {
      ...?editMovie?.photoUrls,
      ...?myRating?.photoUrls,
    }.toList();

    if (editMovie?.posterUrl != null && editMovie!.posterUrl!.startsWith('http')) {
      _posterInputMode = 1;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _posterUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.selectionClick();
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _posterUrlController.clear();
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        showCenterAlertDialog(
          context: context,
          title: 'Image Selection Failed',
          message: 'Could not select image: $e',
          icon: Icons.image_not_supported_rounded,
          iconColor: AppColors.error,
        );
      }
    }
  }

  Future<void> _pickGalleryWatchPhotos() async {
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
            _newWatchPhotoFiles.add(File(picked.path));
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking watch photos: $e');
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

  Future<void> _pickCameraWatchPhoto() async {
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
          _newWatchPhotoFiles.add(File(picked.path));
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

  void _removeExistingWatchPhoto(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _existingWatchPhotos.removeAt(index);
    });
  }

  void _removeNewWatchPhoto(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _newWatchPhotoFiles.removeAt(index);
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

  Future<void> _selectWatchedDate() async {
    HapticFeedback.selectionClick();
    final initial = _watchedDate ?? DateTime.now();
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
      setState(() => _watchedDate = picked);
    }
  }

  void _clearWatchedDate() {
    HapticFeedback.selectionClick();
    setState(() => _watchedDate = null);
  }

  Future<void> _saveMovie() async {
    if (_titleController.text.trim().isEmpty) {
      HapticFeedback.selectionClick();
      showCenterAlertDialog(
        context: context,
        title: 'Title Required',
        message: 'Please enter the title of the movie or series before saving.',
        icon: Icons.movie_creation_outlined,
        iconColor: const Color(0xFFFF758C),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      String? finalPosterUrl;

      if (_selectedImageFile != null) {
        setState(() => _isUploadingPoster = true);
        finalPosterUrl = await _movieService.uploadMoviePoster(
          widget.coupleId.isNotEmpty
              ? widget.coupleId
              : (widget.movieToEdit?.coupleId ?? 'shared'),
          _selectedImageFile!,
        );
        setState(() => _isUploadingPoster = false);
      } else if (_posterUrlController.text.trim().isNotEmpty) {
        finalPosterUrl = _posterUrlController.text.trim();
      }

      final uploadedWatchPhotoUrls = <String>[];
      if (_status == 'watched' && _newWatchPhotoFiles.isNotEmpty) {
        setState(() => _isUploadingWatchPhotos = true);
        for (final file in _newWatchPhotoFiles) {
          final url = await _movieService.uploadMoviePhoto(
            widget.coupleId.isNotEmpty
                ? widget.coupleId
                : (widget.movieToEdit?.coupleId ?? 'shared'),
            file,
          );
          uploadedWatchPhotoUrls.add(url);
        }
        setState(() => _isUploadingWatchPhotos = false);
      }

      final allWatchPhotos = [..._existingWatchPhotos, ...uploadedWatchPhotoUrls];

      if (_isEditMode) {
        // 1. Update existing movie metadata
        final updatedMovie = widget.movieToEdit!.copyWith(
          title: _titleController.text.trim(),
          posterUrl: finalPosterUrl ?? widget.movieToEdit!.posterUrl,
          status: _status,
          mediaType: _mediaType,
          year: _yearController.text.trim().isNotEmpty ? _yearController.text.trim() : null,
          notes: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          photoUrls: _status == 'watched' ? allWatchPhotos : widget.movieToEdit!.photoUrls,
          watchedDate: _status == 'watched' ? _watchedDate : null,
          clearWatchedDate: _status != 'watched' || _watchedDate == null,
          updatedAt: DateTime.now(),
        );

        await _movieService.updateMovie(updatedMovie);

        // 2. If status is watched, save user's rating & review in movie_ratings
        if (_status == 'watched' &&
            updatedMovie.id != null &&
            widget.currentUserId.isNotEmpty) {
          await _movieService.upsertRating(
            movieId: updatedMovie.id!,
            userId: widget.currentUserId,
            rating: _rating,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
            photoUrls: allWatchPhotos,
          );
        }

        if (!mounted) return;

        widget.onMovieAdded?.call();
        Navigator.pop(context, {'action': 'update_movie', 'title': updatedMovie.title});
      } else {
        // 1. Create new movie (ratings strictly stored in movie_ratings)
        final newMovie = MovieModel(
          coupleId: widget.coupleId,
          title: _titleController.text.trim(),
          posterUrl: finalPosterUrl,
          status: _status,
          mediaType: _mediaType,
          year: _yearController.text.trim().isNotEmpty ? _yearController.text.trim() : null,
          notes: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          photoUrls: _status == 'watched' ? allWatchPhotos : const [],
          watchedDate: _status == 'watched' ? _watchedDate : null,
          createdAt: DateTime.now(),
        );

        final createdMovie = await _movieService.addMovie(newMovie);

        // 2. If added as watched and user ID is available, create the user's rating entry
        if (_status == 'watched' &&
            createdMovie?.id != null &&
            widget.currentUserId.isNotEmpty) {
          await _movieService.upsertRating(
            movieId: createdMovie!.id!,
            userId: widget.currentUserId,
            rating: _rating,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
            photoUrls: allWatchPhotos,
          );
        }

        if (!mounted) return;

        widget.onMovieAdded?.call();
        Navigator.pop(context, {
          'action': _status == 'watched' ? 'save_watched' : 'add_watchlist',
          'title': newMovie.title,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isUploadingPoster = false;
        _isUploadingWatchPhotos = false;
      });
      showCenterAlertDialog(
        context: context,
        title: 'Failed to Save',
        message: 'An error occurred while saving: $e',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
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
          child: Form(
            key: _formKey,
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

                // Modal Header
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
                        _isEditMode
                            ? Icons.edit_note_rounded
                            : (_status == 'watched'
                                ? Icons.movie_filter_rounded
                                : Icons.bookmark_add_rounded),
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
                            _isEditMode
                                ? 'Edit Details'
                                : (_status == 'watched'
                                    ? 'Log Watched'
                                    : 'Add to Watchlist'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: isDark ? Colors.white : const Color(0xFF2D4059),
                                ),
                          ),
                          Text(
                            _isEditMode
                                ? 'Update movie or series details'
                                : (_status == 'watched'
                                    ? 'Record what you watched and review together'
                                    : 'Save for your next movie or series night'),
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
                const SizedBox(height: 20),

                // Status Segmented Switcher (Watchlist vs Watched)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _status = 'watchlist');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _status == 'watchlist'
                                  ? const Color(0xFFFF758C)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _status == 'watchlist'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Plan to Watch',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _status == 'watchlist'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _status = 'watched');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _status == 'watched'
                                  ? const Color(0xFFA18CD1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _status == 'watched'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFA18CD1).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already Watched',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _status == 'watched'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Title & Release Year Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Input
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Title *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF2D4059),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: _mediaType == 'series'
                                  ? 'Stranger Things, Friends...'
                                  : 'La La Land, Titanic...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              prefixIcon: Icon(
                                _mediaType == 'series'
                                    ? Icons.tv_rounded
                                    : Icons.movie_creation_rounded,
                                color: const Color(0xFFFF758C),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
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
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.error),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter title';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Release Year Input
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Year',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF2D4059),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '2024',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description / Synopsis Input (For both Watchlist and Watched)
                Text(
                  'Description / Synopsis (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF2D4059),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Brief plot, genre, or notes on why you want to watch this...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                // MEDIA TYPE SELECTOR (MOVIE VS SERIES)
                // ----------------------------------------------------
                Text(
                  'Media Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF2D4059),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _mediaType = 'movie');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _mediaType == 'movie'
                                  ? const Color(0xFFFF758C)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _mediaType == 'movie'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.movie_rounded,
                                  size: 16,
                                  color: _mediaType == 'movie'
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Movie',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: _mediaType == 'movie'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _mediaType = 'series');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _mediaType == 'series'
                                  ? const Color(0xFFA18CD1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _mediaType == 'series'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFA18CD1).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.tv_rounded,
                                  size: 16,
                                  color: _mediaType == 'series'
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Series',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: _mediaType == 'series'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Poster Image Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Poster / Cover Image (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF2D4059),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChoiceChip(
                          label: const Text('Upload', style: TextStyle(fontSize: 11)),
                          selected: _posterInputMode == 0,
                          onSelected: (val) {
                            if (val) setState(() => _posterInputMode = 0);
                          },
                          selectedColor: const Color(0xFFFF758C).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: _posterInputMode == 0
                                ? const Color(0xFFFF758C)
                                : (isDark ? Colors.white70 : Colors.grey.shade700),
                            fontWeight: _posterInputMode == 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Poster URL', style: TextStyle(fontSize: 11)),
                          selected: _posterInputMode == 1,
                          onSelected: (val) {
                            if (val) setState(() => _posterInputMode = 1);
                          },
                          selectedColor: const Color(0xFFFF758C).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: _posterInputMode == 1
                                ? const Color(0xFFFF758C)
                                : (isDark ? Colors.white70 : Colors.grey.shade700),
                            fontWeight: _posterInputMode == 1 ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Poster Picker Mode 0: Upload Image
                if (_posterInputMode == 0) ...[
                  if (_selectedImageFile != null)
                    Center(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _selectedImageFile!,
                              width: 120,
                              height: 170,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: InkWell(
                              onTap: () => setState(() => _selectedImageFile = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickImage(ImageSource.gallery),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFFF758C).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.photo_library_rounded,
                                    color: Color(0xFFFF758C),
                                    size: 28,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Choose from Gallery',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF758C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickImage(ImageSource.camera),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFA18CD1).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFA18CD1).withValues(alpha: 0.3),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.camera_alt_rounded,
                                    color: Color(0xFFA18CD1),
                                    size: 28,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Take a Photo',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFA18CD1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  // Mode 1: Search-Bar Styled URL Input with Live Preview
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 14, right: 8),
                          child: Icon(
                            Icons.search_rounded,
                            color: Color(0xFFFF758C),
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _posterUrlController,
                            keyboardType: TextInputType.url,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Paste poster image URL or link...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            onChanged: (val) => setState(() {}),
                          ),
                        ),
                        if (_posterUrlController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                            onPressed: () {
                              setState(() => _posterUrlController.clear());
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: IconButton(
                              icon: const Icon(Icons.paste_rounded, size: 18),
                              color: const Color(0xFFFF758C),
                              tooltip: 'Paste from clipboard',
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null && data!.text!.isNotEmpty) {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _posterUrlController.text = data.text!.trim();
                                  });
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Real-time Live Poster URL Preview
                  if (_posterUrlController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: _posterUrlController.text.trim(),
                                width: 100,
                                height: 145,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 100,
                                  height: 145,
                                  color: Colors.grey.withValues(alpha: 0.1),
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
                                  width: 100,
                                  height: 145,
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                                      SizedBox(height: 4),
                                      Text(
                                        'Invalid link',
                                        style: TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Live Poster Preview',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                // Existing/Preview Poster if editing
                if (_isEditMode &&
                    _selectedImageFile == null &&
                    widget.movieToEdit?.posterUrl != null &&
                    widget.movieToEdit!.posterUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      MoviePosterWidget(
                        posterUrl: widget.movieToEdit!.posterUrl,
                        width: 44,
                        height: 64,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Current saved poster',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _selectedImageFile = null;
                          _posterUrlController.clear();
                        }),
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),

                // ----------------------------------------------------
                // DYNAMIC SECTION (ONLY SHOWN FOR 'watched' STATUS)
                // ----------------------------------------------------
                if (_status == 'watched') ...[
                  // 1. Rating (1-5 Hearts)
                  Text(
                    'Your Rating',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2D4059),
                    ),
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
                          final isFilled = starNum <= _rating;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _rating = starNum);
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
                                      : Colors.grey.shade400,
                                  size: 32,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Date Watched (Optional)
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
                      if (_watchedDate != null)
                        TextButton.icon(
                          onPressed: _clearWatchedDate,
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
                    onTap: _selectWatchedDate,
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
                              _watchedDate != null
                                  ? DateFormat('EEEE, MMMM d, yyyy').format(_watchedDate!)
                                  : 'Tap to select date (Optional)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _watchedDate != null
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.white38 : Colors.grey.shade500),
                              ),
                            ),
                          ),
                          Icon(
                            _watchedDate != null
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

                  // 3. Review & Notes (Optional)
                  Text(
                    'Your Review / Notes (Optional)',
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
                      hintText: 'Write what you felt about this movie, favorite lines, or date memories...',
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
                      if (_existingWatchPhotos.length + _newWatchPhotoFiles.length > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_existingWatchPhotos.length + _newWatchPhotoFiles.length} photo${_existingWatchPhotos.length + _newWatchPhotoFiles.length == 1 ? '' : 's'}',
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
                          onPressed: _pickGalleryWatchPhotos,
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
                          onPressed: _pickCameraWatchPhoto,
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
                  if (_existingWatchPhotos.isNotEmpty || _newWatchPhotoFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Existing uploaded photos
                          ..._existingWatchPhotos.asMap().entries.map((entry) {
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
                                      onTap: () => _removeExistingWatchPhoto(idx),
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
                          ..._newWatchPhotoFiles.asMap().entries.map((entry) {
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
                                      onTap: () => _removeNewWatchPhoto(idx),
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
                  const SizedBox(height: 18),
                ],
                const SizedBox(height: 10),

                // Submit Button
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
                      onPressed: _isSaving ? null : _saveMovie,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isUploadingPoster
                                      ? 'Uploading poster...'
                                      : (_isUploadingWatchPhotos
                                          ? 'Uploading photos...'
                                          : 'Saving...'),
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
                                Icon(
                                  _isEditMode
                                      ? Icons.check_circle_rounded
                                      : Icons.favorite,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isEditMode
                                      ? 'Save Changes'
                                      : (_status == 'watched'
                                          ? 'Save to Watched Diary'
                                          : 'Add to Watchlist'),
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
      ),
    );
  }
}
