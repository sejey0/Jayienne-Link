import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import '../../../models/movie_rating_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_movie_service.dart';
import '../widgets/add_movie_sheet.dart';
import '../widgets/mark_watched_sheet.dart';
import '../widgets/movie_alert_dialog.dart';
import '../widgets/movie_poster_widget.dart';
import '../widgets/view_movie_details_sheet.dart';
import '../../home/screens/decision_spinner_screen.dart';
import '../../../widgets/smart_profile_image.dart';
import '../../../widgets/common/app_text_field.dart';

/// Senior Couples Movie Tracker & Watchlist Screen ("Cinema Diary")
/// Features a decluttered card layout, single "View Details & Ratings" action,
/// simplified 2-option 3-dots menu ("Edit Movie Details" and "Remove Movie"),
/// Manual Header Refresh button, Pull-to-Refresh on tabs, and Instant UI Auto-Sync.
enum MovieRatingFilter { all, unrated, rated }

class MovieTrackerScreen extends StatefulWidget {
  const MovieTrackerScreen({super.key});

  @override
  State<MovieTrackerScreen> createState() => _MovieTrackerScreenState();
}

class _MovieTrackerScreenState extends State<MovieTrackerScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseMovieService _movieService = SupabaseMovieService();
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;
  int _selectedTabIndex = 0;
  String _searchQuery = '';

  StreamSubscription<List<MovieModel>>? _moviesSubscription;
  StreamSubscription<List<MovieRatingModel>>? _ratingsSubscription;

  List<MovieModel> _allMovies = [];
  List<MovieRatingModel> _allRatings = [];
  bool _isLoading = true;
  String? _errorMessage;
  MovieRatingFilter _ratingFilter = MovieRatingFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStreams();
    });
  }

  @override
  void dispose() {
    _moviesSubscription?.cancel();
    _ratingsSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getCoupleId(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final coupleProvider = Provider.of<CoupleProvider>(context, listen: false);
    return userProvider.coupleId ?? coupleProvider.couple?.id ?? '';
  }

  String _getCurrentUserId(BuildContext context) {
    final authId = Supabase.instance.client.auth.currentUser?.id;
    if (authId != null && authId.isNotEmpty) return authId;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.user?.id ?? '';
  }

  void _initStreams() {
    final coupleId = _getCoupleId(context);
    if (coupleId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Link with your love to start your Cinema Diary';
      });
      return;
    }

    _moviesSubscription?.cancel();
    _ratingsSubscription?.cancel();
    setState(() => _isLoading = true);

    // 1. Real-time Stream of Couple's Movies
    _moviesSubscription = _movieService.streamMovies(coupleId).listen(
      (movies) async {
        if (!mounted) return;
        setState(() {
          _allMovies = movies;
          _isLoading = false;
          _errorMessage = null;
        });
        final movieIds = movies.map((m) => m.id).whereType<String>().toList();
        if (movieIds.isNotEmpty) {
          final ratings = await _movieService.fetchMovieRatings(movieIds);
          if (mounted) {
            setState(() {
              _allRatings = ratings;
            });
          }
        }
      },
      onError: (error) {
        debugPrint('Error streaming movies: $error');
        if (!mounted) return;
        _refreshMovies();
      },
    );

    // 2. Real-time Stream of Dual Ratings
    _ratingsSubscription = _movieService.streamMovieRatings().listen(
      (ratings) {
        if (!mounted) return;
        setState(() {
          _allRatings = ratings;
        });
      },
      onError: (error) {
        debugPrint('Error streaming movie ratings: $error');
      },
    );
  }

  /// Instant data pull from Supabase for zero-delay UI update
  Future<void> _refreshMovies({bool showIndicator = false}) async {
    if (showIndicator && mounted) {
      setState(() => _isLoading = true);
    }
    final coupleId = _getCoupleId(context);
    if (coupleId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final movies = await _movieService.fetchMovies(coupleId);
      final movieIds = movies.map((m) => m.id).whereType<String>().toList();
      final ratings = await _movieService.fetchMovieRatings(movieIds);

      if (!mounted) return;
      setState(() {
        _allMovies = movies;
        _allRatings = ratings;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Error refreshing cinema diary: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Returns all movies with their corresponding ratings joined
  List<MovieModel> get _moviesWithRatings {
    final ratingsByMovie = <String, List<MovieRatingModel>>{};
    for (final r in _allRatings) {
      ratingsByMovie.putIfAbsent(r.movieId, () => []).add(r);
    }

    return _allMovies.map((m) {
      final movieRatings = ratingsByMovie[m.id] ?? [];
      return m.copyWith(ratings: movieRatings);
    }).toList();
  }

  List<MovieModel> get _watchlistMovies {
    return _moviesWithRatings.where((m) {
      final matchesStatus = m.status == 'watchlist';
      if (_searchQuery.isEmpty) return matchesStatus;
      final matchesSearch = m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  /// Returns true if either you or your partner is missing a rating score (> 0) OR review text
  bool _isMovieUnrated(MovieModel movie, String currentUserId, {bool hasPartner = true}) {
    final myRating = movie.getRatingForUser(currentUserId);
    final partnerRating = movie.getPartnerRating(currentUserId);

    final hasMyScore = myRating != null && myRating.rating > 0;
    final hasMyReview = myRating?.notes != null && myRating!.notes!.trim().isNotEmpty;
    final myComplete = hasMyScore && hasMyReview;

    if (!hasPartner) {
      if (movie.ratings.isNotEmpty) {
        return !myComplete;
      }
      final hasFallbackScore = movie.rating != null && movie.rating! > 0;
      final hasFallbackReview = movie.notes != null && movie.notes!.trim().isNotEmpty;
      return !(hasFallbackScore && hasFallbackReview);
    }

    final hasPartnerScore = partnerRating != null && partnerRating.rating > 0;
    final hasPartnerReview = partnerRating?.notes != null && partnerRating!.notes!.trim().isNotEmpty;
    final partnerComplete = hasPartnerScore && hasPartnerReview;

    if (movie.ratings.isNotEmpty) {
      // If either user is missing a rating or review, put it in "Not Rated Yet"
      return !(myComplete && partnerComplete);
    }

    final hasFallbackScore = movie.rating != null && movie.rating! > 0;
    final hasFallbackReview = movie.notes != null && movie.notes!.trim().isNotEmpty;
    return !(hasFallbackScore && hasFallbackReview);
  }

  List<MovieModel> get _watchedMovies {
    final currentUserId = _getCurrentUserId(context);
    final coupleProvider = context.read<CoupleProvider>();
    final hasPartner = coupleProvider.partner != null;

    return _moviesWithRatings.where((m) {
      final matchesStatus = m.status == 'watched';
      if (!matchesStatus) return false;

      final isUnrated = _isMovieUnrated(m, currentUserId, hasPartner: hasPartner);

      if (_ratingFilter == MovieRatingFilter.unrated && !isUnrated) {
        return false;
      }
      if (_ratingFilter == MovieRatingFilter.rated && isUnrated) {
        return false;
      }

      if (_searchQuery.isEmpty) return true;
      final matchesSearch = m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch;
    }).toList();
  }

  double get _averageRating {
    final watchedMovies = _moviesWithRatings.where((m) => m.status == 'watched').toList();
    if (watchedMovies.isEmpty) return 0.0;

    double total = 0.0;
    int count = 0;

    for (final m in watchedMovies) {
      final avg = m.calculatedAverageRating;
      if (avg != null && avg > 0) {
        total += avg;
        count++;
      }
    }

    if (count == 0) return 0.0;
    return total / count;
  }

  Future<void> _openAddMovieModal() async {
    HapticFeedback.lightImpact();
    final coupleId = _getCoupleId(context);
    final currentUserId = _getCurrentUserId(context);
    final res = await AddMovieSheet.show(
      context,
      coupleId: coupleId,
      currentUserId: currentUserId,
      initialStatus: _selectedTabIndex == 0 ? 'watchlist' : 'watched',
      onMovieAdded: () => _refreshMovies(),
    );

    if (res != null && mounted) {
      _refreshMovies();
      if (res is Map<String, dynamic>) {
        final action = res['action'];
        final title = res['title'] ?? 'Movie';
        if (action == 'add_watchlist') {
          await showCenterAlertDialog(
            context: context,
            title: 'Added to Watchlist!',
            message: '"$title" has been added to your watchlist',
            icon: Icons.bookmark_added_rounded,
            iconColor: const Color(0xFFFF758C),
          );
        } else if (action == 'save_watched') {
          await showCenterAlertDialog(
            context: context,
            title: 'Saved to Watched Diary!',
            message: '"$title" has been recorded in your cinema diary',
            icon: Icons.movie_filter_rounded,
            iconColor: const Color(0xFFFF758C),
          );
        } else if (action == 'update_movie') {
          await showCenterAlertDialog(
            context: context,
            title: 'Movie Updated!',
            message: 'Details for "$title" have been updated successfully',
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFFFF758C),
          );
        }
      }
    }
  }

  Future<void> _openEditMovieDetails(MovieModel movie) async {
    HapticFeedback.lightImpact();
    final coupleId = _getCoupleId(context);
    final currentUserId = _getCurrentUserId(context);
    final res = await AddMovieSheet.show(
      context,
      coupleId: coupleId,
      currentUserId: currentUserId,
      movieToEdit: movie,
      onMovieAdded: () => _refreshMovies(),
    );

    if (res != null && mounted) {
      _refreshMovies();
      final title = (res is Map<String, dynamic> ? res['title'] : null) ?? movie.title;
      await showCenterAlertDialog(
        context: context,
        title: 'Movie Updated!',
        message: 'Details for "$title" have been updated successfully',
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFFFF758C),
      );
    }
  }

  Future<void> _openRateMovieModal(MovieModel movie) async {
    HapticFeedback.lightImpact();
    final currentUserId = _getCurrentUserId(context);
    final coupleProvider = context.read<CoupleProvider>();
    final partner = coupleProvider.partner;
    final partnerName = partner?.displayName.isNotEmpty == true
        ? partner!.displayName
        : 'Partner';

    final res = await MarkWatchedSheet.show(
      context,
      movie: movie,
      currentUserId: currentUserId,
      partnerName: partnerName,
      onMovieUpdated: () => _refreshMovies(),
    );

    if (res != null && mounted) {
      _refreshMovies();
      final title = (res is Map<String, dynamic> ? res['title'] : null) ?? movie.title;
      final isWatchlist = (res is Map<String, dynamic> ? res['isWatchlist'] : false) || movie.isWatchlist;
      final action = res is Map<String, dynamic> ? res['action'] : null;

      if (isWatchlist || action == 'marked_watched') {
        await showCenterAlertDialog(
          context: context,
          title: 'Marked as Watched!',
          message: '"$title" has been added to your Watched Cinema Diary',
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFFFF758C),
        );
      } else {
        await showCenterAlertDialog(
          context: context,
          title: 'Review Updated!',
          message: 'Your review for "$title" has been saved successfully',
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFFF4081),
        );
      }
    }
  }

  Future<void> _planToRewatch(MovieModel movie) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();

    // Confirmation dialog before planning rewatch
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Color(0xFFFF758C), size: 20),
            SizedBox(width: 8),
            Text('Plan Rewatch?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Move "${movie.title}" back to your Watchlist to plan a rewatch together?',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Plan Rewatch', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      HapticFeedback.mediumImpact();
      await _movieService.planRewatch(movie);
      if (!mounted) return;
      _refreshMovies();
      await showCenterAlertDialog(
        context: context,
        title: 'Moved to Watchlist!',
        message: '"${movie.title}" is ready for a rewatch',
        icon: Icons.replay_rounded,
        iconColor: const Color(0xFFFF758C),
      );
    } catch (e) {
      if (!mounted) return;
      showCenterAlertDialog(
        context: context,
        title: 'Error',
        message: 'Failed to plan rewatch: $e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _cancelRewatch(MovieModel movie) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();

    // Confirmation dialog before canceling rewatch
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.undo_rounded, color: Color(0xFFA18CD1), size: 20),
            SizedBox(width: 8),
            Text('Cancel Rewatch?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Move "${movie.title}" back to your Watched Cinema Diary and cancel the planned rewatch?',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep in Watchlist',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Cancel Rewatch', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      HapticFeedback.mediumImpact();
      await _movieService.cancelRewatch(movie);
      if (!mounted) return;
      _refreshMovies();
      await showCenterAlertDialog(
        context: context,
        title: 'Rewatch Cancelled',
        message: '"${movie.title}" has been returned to your Watched Diary',
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFFA18CD1),
      );
    } catch (e) {
      if (!mounted) return;
      showCenterAlertDialog(
        context: context,
        title: 'Error',
        message: 'Failed to cancel rewatch: $e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _openMovieDetailsModal(MovieModel movie) async {
    HapticFeedback.lightImpact();
    final currentUserId = _getCurrentUserId(context);
    final coupleProvider = context.read<CoupleProvider>();
    final partner = coupleProvider.partner;
    final partnerName = partner?.displayName.isNotEmpty == true
        ? partner!.displayName
        : 'Partner';

    final res = await ViewMovieDetailsSheet.show(
      context,
      movie: movie,
      currentUserId: currentUserId,
      partnerName: partnerName,
      onMovieUpdated: () => _refreshMovies(),
      onEditMovie: () => _openEditMovieDetails(movie),
      onDeleteMovie: () => _confirmDeleteMovie(movie),
      onPlanRewatch: () => _planToRewatch(movie),
      onCancelRewatch: () => _cancelRewatch(movie),
    );

    if (res != null && mounted) {
      _refreshMovies();
      if (res is Map<String, dynamic>) {
        if (res['action'] == 'plan_rewatch') {
          final title = res['title'] ?? movie.title;
          await showCenterAlertDialog(
            context: context,
            title: 'Moved to Watchlist!',
            message: '"$title" is ready for a rewatch',
            icon: Icons.replay_rounded,
            iconColor: const Color(0xFFFF758C),
          );
        } else if (res['action'] == 'marked_watched') {
          final title = res['title'] ?? movie.title;
          await showCenterAlertDialog(
            context: context,
            title: 'Set to Already Watched!',
            message: '"$title" has been moved to your watched diary',
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFFFF758C),
          );
        } else if (res['action'] == 'add_memories') {
          final title = res['title'] ?? movie.title;
          final count = res['count'] ?? 1;
          await showCenterAlertDialog(
            context: context,
            title: 'Memories Saved!',
            message: count == 1
                ? 'Successfully added 1 photo memory to "$title"'
                : 'Successfully added $count photo memories to "$title"',
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFFFF758C),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteMovie(MovieModel movie) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 14),

            // 2. Title
            Text(
              'Remove Movie',
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
              'Are you sure you want to remove "${movie.title}" from your Cinema Diary?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // 4. Primary Button (Remove Movie)
            Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Remove Movie',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
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

    if (confirm == true && movie.id != null) {
      try {
        await _movieService.deleteMovie(movie.id!);
        _refreshMovies();
        if (!mounted) return;
        showCenterAlertDialog(
          context: context,
          title: 'Movie Removed',
          message: 'Removed "${movie.title}" from your Cinema Diary.',
          icon: Icons.delete_sweep_rounded,
          iconColor: const Color(0xFFFF758C),
        );
      } catch (e) {
        if (!mounted) return;
        showCenterAlertDialog(
          context: context,
          title: 'Delete Error',
          message: 'Failed to delete movie: $e',
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.watch<CoupleProvider>();
    final partner = coupleProvider.partner;
    final partnerName = partner?.displayName.isNotEmpty == true
        ? partner!.displayName
        : 'Partner';
    final currentUserId = _getCurrentUserId(context);

    final watchlistCount = _allMovies.where((m) => m.status == 'watchlist').length;
    final watchedCount = _allMovies.where((m) => m.status == 'watched').length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF140E1B) : const Color(0xFFFFF7F9),
      body: Column(
        children: [
          // ----------------------------------------------------
          // 1. TOP FIXED GRADIENT HEADER BOX
          // ----------------------------------------------------
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF758C),
                  Color(0xFFA18CD1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact Top Navigation Bar
                    Row(
                      children: [
                        // Back Button
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Header Title with Movie Icon
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.movie_creation_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Movie Diary',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'Watchlist & reviews',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Manual Refresh Button
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _refreshMovies(showIndicator: true);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Sleek Compressed Cinema Stats Capsule Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E162B).withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFFF758C).withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            icon: Icons.bookmark_added_rounded,
                            iconColor: const Color(0xFFFF758C),
                            value: '$watchlistCount',
                            label: 'Watchlist',
                            isDark: isDark,
                          ),
                          Container(
                            height: 22,
                            width: 1,
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                          _buildStatItem(
                            icon: Icons.movie_filter_rounded,
                            iconColor: const Color(0xFFA18CD1),
                            value: '$watchedCount',
                            label: 'Watched',
                            isDark: isDark,
                          ),
                          Container(
                            height: 22,
                            width: 1,
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                          _buildStatItem(
                            icon: Icons.favorite,
                            iconColor: const Color(0xFFFF4081),
                            value: _averageRating > 0
                                ? _averageRating.toStringAsFixed(1)
                                : '--',
                            label: 'Avg Rating',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Search Bar & Decision Spinner Shortcut Row
                    Row(
                      children: [
                        // Clean Search Bar matching Sign-In Screen design
                        Expanded(
                          child: AppTextField(
                            controller: _searchController,
                            hintText: 'Search movies, memories...',
                            prefixIcon: Icons.search_rounded,
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            isDark: isDark,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Decision Spinner Shortcut Button
                        Tooltip(
                          message: 'Decision Spinner',
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DecisionSpinnerScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.rotate_right_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Segmented TabBar (Watchlist vs Watched)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: const Color(0xFFFF758C),
                        unselectedLabelColor: Colors.white.withValues(alpha: 0.9),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Watchlist'),
                                if (watchlistCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 0
                                          ? const Color(0xFFFF758C).withValues(alpha: 0.15)
                                          : Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$watchlistCount',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedTabIndex == 0
                                            ? const Color(0xFFFF758C)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Watched'),
                                if (watchedCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 1
                                          ? const Color(0xFFFF758C).withValues(alpha: 0.15)
                                          : Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$watchedCount',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedTabIndex == 1
                                            ? const Color(0xFFFF758C)
                                            : Colors.white,
                                      ),
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
                ),
              ),
            ),
          ),

          // ----------------------------------------------------
          // 2. EXPANDED SCROLLABLE TAB CONTENT
          // ----------------------------------------------------
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF758C),
                    ),
                  )
                : _errorMessage != null
                    ? _buildErrorState(isDark)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildWatchlistTab(isDark, partnerName),
                          _buildWatchedTab(isDark, partnerName, currentUserId),
                        ],
                      ),
          ),
        ],
      ),

      // Floating Action Button (+ Add Movie)
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF758C).withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _openAddMovieModal,
          elevation: 0,
          backgroundColor: Colors.transparent,
          splashColor: Colors.white.withValues(alpha: 0.2),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
          label: const Text(
            'Add Movie',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2D4059),
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: WATCHLIST TAB (WITH PULL-TO-REFRESH)
  // ----------------------------------------------------
  Widget _buildWatchlistTab(bool isDark, String partnerName) {
    final list = _watchlistMovies;

    if (list.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFFF758C),
        onRefresh: () => _refreshMovies(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: _buildEmptyState(
              isDark: isDark,
              icon: Icons.movie_filter_outlined,
              title: _searchQuery.isNotEmpty
                  ? 'No movies found'
                  : 'Your Watchlist is Empty',
              subtitle: _searchQuery.isNotEmpty
                  ? 'Try searching for another movie title'
                  : 'Plan your next cinema date night with $partnerName. Tap "+ Add Movie" below.',
              buttonText: 'Add to Watchlist',
              onButtonTap: _openAddMovieModal,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF758C),
      onRefresh: () => _refreshMovies(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final movie = list[index];
          return _buildWatchlistCard(movie, isDark);
        },
      ),
    );
  }

  Widget _buildWatchlistCard(MovieModel movie, bool isDark) {
    return InkWell(
      onTap: () => _openMovieDetailsModal(movie),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E162B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFFF758C).withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : const Color(0xFFFF758C).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Movie Poster
              MoviePosterWidget(
                posterUrl: movie.posterUrl,
                title: movie.title,
                year: movie.year,
                date: movie.formattedCreatedDate,
                notes: movie.notes,
                width: 62,
                height: 86,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 10),

              // Details & Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title & Year
                    Text.rich(
                      TextSpan(
                        text: movie.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF2D4059),
                        ),
                        children: [
                          if (movie.year != null && movie.year!.isNotEmpty)
                            TextSpan(
                              text: ' (${movie.year})',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Media Type Badge & Rewatch Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: movie.isSeries
                                ? const Color(0xFFA18CD1).withValues(alpha: 0.15)
                                : const Color(0xFFFF758C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            movie.isSeries ? 'Series' : 'Movie',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: movie.isSeries
                                  ? const Color(0xFFA18CD1)
                                  : const Color(0xFFFF758C),
                            ),
                          ),
                        ),
                        if (movie.isRewatch) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              movie.rewatchBadgeLabel,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF758C),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Actions Row: "Mark Watched", "Cancel" (if rewatch), & "Movie Details"
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _openRateMovieModal(movie),
                              icon: const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                              label: const Text(
                                'Mark as Watched',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (movie.isRewatch) ...[
                          const SizedBox(width: 5),
                          SizedBox(
                            height: 30,
                            child: OutlinedButton.icon(
                              onPressed: () => _cancelRewatch(movie),
                              icon: const Icon(Icons.undo_rounded, size: 11, color: Color(0xFFA18CD1)),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : const Color(0xFF2D4059),
                                side: BorderSide(
                                  color: const Color(0xFFA18CD1).withValues(alpha: 0.35),
                                ),
                                backgroundColor: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFA18CD1).withValues(alpha: 0.06),
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 5),
                        SizedBox(
                          height: 30,
                          child: OutlinedButton.icon(
                            onPressed: () => _openMovieDetailsModal(movie),
                            icon: const Icon(Icons.movie_filter_rounded, size: 11, color: Color(0xFFFF758C)),
                            label: Text(
                              movie.isRewatch ? 'Details' : 'Movie Details',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF2D4059),
                              side: BorderSide(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                              ),
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFFF758C).withValues(alpha: 0.06),
                              padding: EdgeInsets.symmetric(horizontal: movie.isRewatch ? 6 : 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: WATCHED TAB WITH DUAL RATINGS & DETAILS (WITH PULL-TO-REFRESH)
  // ----------------------------------------------------
  Widget _buildWatchedTab(bool isDark, String partnerName, String currentUserId) {
    final list = _watchedMovies;

    if (list.isEmpty) {
      String emptyTitle = 'No Watched Movies Yet';
      String emptySubtitle = 'Record your first movie date with $partnerName and rate your favorites together.';
      if (_searchQuery.isNotEmpty) {
        emptyTitle = 'No matching watched movies';
        emptySubtitle = 'Try another movie title or keyword';
      } else if (_ratingFilter == MovieRatingFilter.unrated) {
        emptyTitle = 'All Caught Up!';
        emptySubtitle = 'All watched movies have both ratings and reviews from both of you.';
      } else if (_ratingFilter == MovieRatingFilter.rated) {
        emptyTitle = 'No Fully Reviewed Movies';
        emptySubtitle = 'Complete your ratings and reviews for watched movies to see them here.';
      }

      return Column(
        children: [
          _buildFilterChips(isDark, currentUserId),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildEmptyState(
                  isDark: isDark,
                  icon: _ratingFilter == MovieRatingFilter.unrated
                      ? Icons.rate_review_outlined
                      : Icons.local_movies_outlined,
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                  buttonText: 'Log Watched Movie',
                  onButtonTap: _openAddMovieModal,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildFilterChips(isDark, currentUserId),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFFF758C),
            onRefresh: () => _refreshMovies(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final movie = list[index];
                return _buildWatchedCard(movie, isDark, partnerName, currentUserId);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(bool isDark, String currentUserId) {
    final coupleProvider = context.watch<CoupleProvider>();
    final hasPartner = coupleProvider.partner != null;
    final rawWatched = _moviesWithRatings.where((m) => m.status == 'watched').toList();
    final unratedCount = rawWatched.where((m) => _isMovieUnrated(m, currentUserId, hasPartner: hasPartner)).length;
    final ratedCount = rawWatched.where((m) => !_isMovieUnrated(m, currentUserId, hasPartner: hasPartner)).length;

    final filterItems = [
      (MovieRatingFilter.all, 'All', rawWatched.length, Icons.apps_rounded),
      (MovieRatingFilter.unrated, 'Needs Review', unratedCount, Icons.rate_review_outlined),
      (MovieRatingFilter.rated, 'Fully Reviewed', ratedCount, Icons.star_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filterItems.map((item) {
            final filter = item.$1;
            final label = item.$2;
            final count = item.$3;
            final icon = item.$4;
            final isSelected = _ratingFilter == filter;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _ratingFilter = filter;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF758C)
                        : (isDark
                            ? const Color(0xFF1E162B)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF758C)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFFF758C).withValues(alpha: 0.22)),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFFFF758C).withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 13.5,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFA18CD1) : const Color(0xFFFF758C)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : AppColors.deepCharcoal),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.28)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFFF758C).withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFFFF758C)),
                          ),
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
    );
  }

  Widget _buildWatchedCard(
    MovieModel movie,
    bool isDark,
    String partnerName,
    String currentUserId,
  ) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final myPhotoUrl = userProvider.user?.photoUrl;
    final partnerPhotoUrl = coupleProvider.partner?.photoUrl;
    final myRating = movie.getRatingForUser(currentUserId);
    final partnerRating = movie.getPartnerRating(currentUserId);
    final calculatedAvg = movie.calculatedAverageRating;
    final myReview = myRating?.notes?.trim();
    final partnerReview = partnerRating?.notes?.trim();
    final hasMyReview = myReview != null && myReview.isNotEmpty;
    final hasPartnerReview = partnerReview != null && partnerReview.isNotEmpty;
    final hasMovieNotes = movie.notes != null && movie.notes!.trim().isNotEmpty;

    return InkWell(
      onTap: () => _openMovieDetailsModal(movie),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E162B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFA18CD1).withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : const Color(0xFFA18CD1).withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Movie Poster with Average Score Badge
              Stack(
                children: [
                  MoviePosterWidget(
                    posterUrl: movie.posterUrl,
                    title: movie.title,
                    year: movie.year,
                    date: movie.formattedWatchedDate,
                    notes: movie.notes,
                    width: 62,
                    height: 86,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  if (calculatedAvg != null)
                    Positioned(
                      top: 3,
                      left: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_rounded, size: 9, color: Color(0xFFFF4081)),
                            const SizedBox(width: 2),
                            Text(
                              calculatedAvg.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),

              // Details & Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title & Year
                    Text.rich(
                      TextSpan(
                        text: movie.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF2D4059),
                        ),
                        children: [
                          if (movie.year != null && movie.year!.isNotEmpty)
                            TextSpan(
                              text: ' (${movie.year})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Badges Row (Media Type, Watches, Needs Rating)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: movie.isSeries
                                ? const Color(0xFFA18CD1).withValues(alpha: 0.15)
                                : const Color(0xFFFF758C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            movie.isSeries ? 'Series' : 'Movie',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: movie.isSeries
                                  ? const Color(0xFFA18CD1)
                                  : const Color(0xFFFF758C),
                            ),
                          ),
                        ),
                        if (movie.watchCount > 1) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${movie.watchCount}x',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF758C),
                              ),
                            ),
                          ),
                        ],
                        if (_isMovieUnrated(movie, currentUserId, hasPartner: coupleProvider.partner != null)) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8A65).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFFF8A65).withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.rate_review_outlined, size: 9.5, color: Color(0xFFFF8A65)),
                                const SizedBox(width: 2.5),
                                Text(
                                  (myRating == null || myRating.rating <= 0 || !hasMyReview)
                                      ? 'Needs Your Review'
                                      : 'Waiting for $partnerName',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF8A65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Combined Couple Ratings & Reviews Section (No duplicates)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFFF758C).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFFF758C).withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // You line: Avatar + Hearts + Review Quote
                          Row(
                            children: [
                              _buildMiniAvatar(
                                photoUrl: myPhotoUrl,
                                accentColor: const Color(0xFFFF758C),
                                fallbackIcon: Icons.person_rounded,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              if (myRating != null && myRating.rating > 0) ...[
                                const Icon(Icons.favorite_rounded, size: 10, color: Color(0xFFFF758C)),
                                const SizedBox(width: 2),
                                Text(
                                  '${myRating.rating}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF758C),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (hasMyReview) ...[
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '"$myReview"',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ] else if (myRating != null && myRating.rating > 0) ...[
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'No review written',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2.5),

                          // Partner line: Avatar + Hearts + Review Quote
                          Row(
                            children: [
                              _buildMiniAvatar(
                                photoUrl: partnerPhotoUrl,
                                accentColor: const Color(0xFFA18CD1),
                                fallbackIcon: Icons.favorite_rounded,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              if (partnerRating != null && partnerRating.rating > 0) ...[
                                const Icon(Icons.favorite_rounded, size: 10, color: Color(0xFFA18CD1)),
                                const SizedBox(width: 2),
                                Text(
                                  '${partnerRating.rating}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFA18CD1),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (hasPartnerReview) ...[
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '"$partnerReview"',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ] else if (partnerRating != null && partnerRating.rating > 0) ...[
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'No review written',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Fallback movie notes if neither reviewed
                          if (!hasMyReview && !hasPartnerReview && hasMovieNotes) ...[
                            const SizedBox(height: 2.5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.format_quote_rounded,
                                  size: 10,
                                  color: Color(0xFFFF758C),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    movie.notes!.trim(),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Actions Row: "View / Edit Review", "Rewatch", & "Movie Details"
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _openRateMovieModal(movie),
                              icon: Icon(
                                myRating != null ? Icons.rate_review_rounded : Icons.favorite_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              label: Text(
                                myRating != null ? 'View / Edit Review' : 'Rate Movie',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          height: 30,
                          child: OutlinedButton.icon(
                            onPressed: () => _planToRewatch(movie),
                            icon: const Icon(Icons.replay_rounded, size: 11, color: Color(0xFFA18CD1)),
                            label: const Text(
                              'Rewatch',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF2D4059),
                              side: BorderSide(
                                color: const Color(0xFFA18CD1).withValues(alpha: 0.35),
                              ),
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFA18CD1).withValues(alpha: 0.06),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          height: 30,
                          child: OutlinedButton.icon(
                            onPressed: () => _openMovieDetailsModal(movie),
                            icon: const Icon(Icons.movie_filter_rounded, size: 11, color: Color(0xFFFF758C)),
                            label: const Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF2D4059),
                              side: BorderSide(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                              ),
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFFF758C).withValues(alpha: 0.06),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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
      ),
    );
  }

  /// Mini Avatar Helper for Movie Card Rating Rows
  Widget _buildMiniAvatar({
    required String? photoUrl,
    required Color accentColor,
    required IconData fallbackIcon,
    double size = 18,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 1.2,
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
            child: Icon(fallbackIcon, size: size * 0.6, color: accentColor),
          ),
          errorWidget: Container(
            width: size,
            height: size,
            color: accentColor.withValues(alpha: 0.15),
            child: Icon(fallbackIcon, size: size * 0.6, color: accentColor),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // EMPTY & ERROR STATES
  // ----------------------------------------------------
  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onButtonTap,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF758C).withValues(alpha: 0.2),
                    const Color(0xFFA18CD1).withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 52,
                color: const Color(0xFFFF758C),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D4059),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onButtonTap,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF758C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initStreams,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
