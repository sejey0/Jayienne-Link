import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import '../../../services/supabase_movie_service.dart';
import 'movie_poster_widget.dart';

/// Modal bottom sheet for adding a new movie to either Watchlist or Watched history
class AddMovieSheet extends StatefulWidget {
  final String coupleId;
  final String currentUserId;
  final String initialStatus; // 'watchlist' or 'watched'
  final VoidCallback? onMovieAdded;

  const AddMovieSheet({
    super.key,
    required this.coupleId,
    this.currentUserId = '',
    this.initialStatus = 'watchlist',
    this.onMovieAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String coupleId,
    String currentUserId = '',
    String initialStatus = 'watchlist',
    VoidCallback? onMovieAdded,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMovieSheet(
        coupleId: coupleId,
        currentUserId: currentUserId,
        initialStatus: initialStatus,
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
  late final TextEditingController _posterUrlController;
  late final TextEditingController _notesController;

  late String _status; // 'watchlist' or 'watched'
  int _rating = 5;
  DateTime? _watchedDate;
  File? _selectedImageFile;
  bool _isUploadingPoster = false;
  bool _isSaving = false;
  int _posterInputMode = 0; // 0: Gallery pick, 1: Poster URL

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _posterUrlController = TextEditingController();
    _notesController = TextEditingController();
    _status = widget.initialStatus;
  }

  @override
  void dispose() {
    _titleController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.coupleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couple profile not found. Please ensure you are linked.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      String? finalPosterUrl;

      if (_selectedImageFile != null) {
        setState(() => _isUploadingPoster = true);
        finalPosterUrl = await _movieService.uploadMoviePoster(
          widget.coupleId,
          _selectedImageFile!,
        );
        setState(() => _isUploadingPoster = false);
      } else if (_posterUrlController.text.trim().isNotEmpty) {
        finalPosterUrl = _posterUrlController.text.trim();
      }

      final newMovie = MovieModel(
        coupleId: widget.coupleId,
        title: _titleController.text.trim(),
        posterUrl: finalPosterUrl,
        status: _status,
        rating: _status == 'watched' ? _rating : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        watchedDate: _status == 'watched' ? _watchedDate : null,
        createdAt: DateTime.now(),
      );

      final createdMovie = await _movieService.addMovie(newMovie);

      // If added as watched and user ID is available, create the partner's rating entry
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
        );
      }

      if (!mounted) return;

      widget.onMovieAdded?.call();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _status == 'watched'
                      ? 'Added "${newMovie.title}" to Watched Diary'
                      : 'Added "${newMovie.title}" to Watchlist',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF758C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isUploadingPoster = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save movie: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                      child: const Icon(
                        Icons.add_to_photos_rounded,
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
                            'Add New Movie',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: isDark ? Colors.white : const Color(0xFF2D4059),
                                ),
                          ),
                          Text(
                            'Plan a date night or log your movie review',
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

                // Status Segmented Selector (Watchlist vs Watched)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade200,
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: _status == 'watchlist'
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                    )
                                  : null,
                              color: _status == 'watchlist'
                                  ? null
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _status == 'watchlist'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF758C)
                                            .withValues(alpha: 0.35),
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
                                  'Watchlist',
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: _status == 'watched'
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                    )
                                  : null,
                              color: _status == 'watched'
                                  ? null
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _status == 'watched'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF758C)
                                            .withValues(alpha: 0.35),
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
                const SizedBox(height: 20),

                // Movie Title Input
                Text(
                  'Movie Title *',
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
                    hintText: 'e.g. La La Land, Spirited Away, Titanic...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    prefixIcon: const Icon(
                      Icons.movie_creation_rounded,
                      color: Color(0xFFFF758C),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                      return 'Please enter the movie title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Poster Image Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Movie Poster (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF2D4059),
                      ),
                    ),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Pick Photo', style: TextStyle(fontSize: 11)),
                          selected: _posterInputMode == 0,
                          onSelected: (_) => setState(() => _posterInputMode = 0),
                          selectedColor: const Color(0xFFFF758C).withValues(alpha: 0.2),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Image URL', style: TextStyle(fontSize: 11)),
                          selected: _posterInputMode == 1,
                          onSelected: (_) => setState(() => _posterInputMode = 1),
                          selectedColor: const Color(0xFFA18CD1).withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Poster Image Input / Preview
                if (_posterInputMode == 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text('From Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF758C),
                            side: const BorderSide(color: Color(0xFFFF758C)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Take Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA18CD1),
                            side: const BorderSide(color: Color(0xFFA18CD1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextFormField(
                    controller: _posterUrlController,
                    keyboardType: TextInputType.url,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    onChanged: (_) => setState(() {
                      _selectedImageFile = null;
                    }),
                    decoration: InputDecoration(
                      hintText: 'https://image.tmdb.org/t/p/w500/...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      prefixIcon: const Icon(
                        Icons.link_rounded,
                        color: Color(0xFFA18CD1),
                        size: 20,
                      ),
                      suffixIcon: _posterUrlController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() {
                                _posterUrlController.clear();
                              }),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
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
                          color: Color(0xFFA18CD1),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],

                // Poster Preview if chosen
                if (_selectedImageFile != null || _posterUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      MoviePosterWidget(
                        localFile: _selectedImageFile,
                        posterUrl: _selectedImageFile == null
                            ? _posterUrlController.text.trim()
                            : null,
                        width: 50,
                        height: 72,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedImageFile != null
                              ? 'Custom image selected'
                              : 'Poster URL previewing',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
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

                // If Watched: Show Rating & Watched Date (Optional)
                if (_status == 'watched') ...[
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date Watched (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF2D4059),
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
                ],

                // Review Notes
                Text(
                  _status == 'watched'
                      ? 'Your Review & Notes (Optional)'
                      : 'Notes (Optional)',
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
                    hintText: _status == 'watched'
                        ? 'Thoughts on the movie, favorite scenes, or memories...'
                        : 'Suggested by partner, date night idea, or thoughts...',
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
                const SizedBox(height: 24),

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
                                      : 'Adding movie...',
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
                                const Icon(Icons.favorite, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _status == 'watched'
                                      ? 'Save to Watched Diary'
                                      : 'Add to Watchlist',
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
