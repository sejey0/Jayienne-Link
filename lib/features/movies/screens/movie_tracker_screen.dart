import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/movie_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_movie_service.dart';
import '../widgets/add_movie_sheet.dart';
import '../widgets/mark_watched_sheet.dart';
import '../widgets/movie_poster_widget.dart';

/// Senior Couples Movie Tracker & Watchlist Screen ("Cinema Diary")
/// Refactored with clean minimalist typography, emoji-free UI,
/// top fixed gradient header + Expanded TabBarView, and full editing support.
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
  List<MovieModel> _allMovies = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      _initMoviesStream();
    });
  }

  @override
  void dispose() {
    _moviesSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getCoupleId(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final coupleProvider = Provider.of<CoupleProvider>(context, listen: false);
    return userProvider.coupleId ?? coupleProvider.couple?.id ?? '';
  }

  void _initMoviesStream() {
    final coupleId = _getCoupleId(context);
    if (coupleId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Link with your partner to start your Cinema Diary';
      });
      return;
    }

    _moviesSubscription?.cancel();
    setState(() => _isLoading = true);

    _moviesSubscription = _movieService.streamMovies(coupleId).listen(
      (movies) {
        if (!mounted) return;
        setState(() {
          _allMovies = movies;
          _isLoading = false;
          _errorMessage = null;
        });
      },
      onError: (error) {
        debugPrint('Error streaming movies: $error');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load cinema diary. Retrying...';
        });
        _fetchMoviesFallback(coupleId);
      },
    );
  }

  Future<void> _fetchMoviesFallback(String coupleId) async {
    try {
      final movies = await _movieService.fetchMovies(coupleId);
      if (!mounted) return;
      setState(() {
        _allMovies = movies;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load movies. Please check your connection.';
      });
    }
  }

  List<MovieModel> get _watchlistMovies {
    return _allMovies.where((m) {
      final matchesStatus = m.status == 'watchlist';
      if (_searchQuery.isEmpty) return matchesStatus;
      final matchesSearch = m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<MovieModel> get _watchedMovies {
    return _allMovies.where((m) {
      final matchesStatus = m.status == 'watched';
      if (_searchQuery.isEmpty) return matchesStatus;
      final matchesSearch = m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  double get _averageRating {
    final watchedWithRating = _allMovies
        .where((m) => m.status == 'watched' && m.rating != null && m.rating! > 0)
        .toList();
    if (watchedWithRating.isEmpty) return 0.0;
    final total = watchedWithRating.fold<int>(0, (sum, m) => sum + (m.rating ?? 0));
    return total / watchedWithRating.length;
  }

  void _openAddMovieModal() {
    HapticFeedback.lightImpact();
    final coupleId = _getCoupleId(context);
    AddMovieSheet.show(
      context,
      coupleId: coupleId,
      initialStatus: _selectedTabIndex == 0 ? 'watchlist' : 'watched',
    );
  }

  void _openMarkWatchedModal(MovieModel movie) {
    HapticFeedback.lightImpact();
    MarkWatchedSheet.show(
      context,
      movie: movie,
    );
  }

  Future<void> _confirmDeleteMovie(MovieModel movie) async {
    HapticFeedback.selectionClick();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Movie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${movie.title}" from your Cinema Diary?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && movie.id != null) {
      try {
        await _movieService.deleteMovie(movie.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${movie.title}"'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2D4059),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete movie: $e'),
            backgroundColor: AppColors.error,
          ),
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
        : 'Your Partner';

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Bar Row (Back Button + Title)
                    Row(
                      children: [
                        // Romantic Blur Back Button
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Header Title with Movie Icon
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.movie_creation_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cinema Diary',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'Movie nights & reviews',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Cinema Stats Summary Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E162B).withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.bookmark_added_rounded,
                            iconColor: const Color(0xFFFF758C),
                            value: '$watchlistCount',
                            label: 'In Watchlist',
                            isDark: isDark,
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                          _buildStatItem(
                            icon: Icons.movie_filter_rounded,
                            iconColor: const Color(0xFFA18CD1),
                            value: '$watchedCount',
                            label: 'Watched Together',
                            isDark: isDark,
                          ),
                          Container(
                            height: 30,
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
                    const SizedBox(height: 10),

                    // Search Bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E162B).withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search movies, memories, or reviews...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFFFF758C),
                            size: 18,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
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
                          _buildWatchedTab(isDark, partnerName),
                        ],
                      ),
          ),
        ],
      ),

      // Romantic Floating Action Button (+ Add Movie)
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 15),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D4059),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // TAB 1: WATCHLIST TAB
  // ----------------------------------------------------
  Widget _buildWatchlistTab(bool isDark, String partnerName) {
    final list = _watchlistMovies;

    if (list.isEmpty) {
      return _buildEmptyState(
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
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final movie = list[index];
        return _buildWatchlistCard(movie, isDark);
      },
    );
  }

  Widget _buildWatchlistCard(MovieModel movie, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E162B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFFF758C).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFFFF758C).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie Poster
            MoviePosterWidget(
              posterUrl: movie.posterUrl,
              width: 76,
              height: 108,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(width: 14),

            // Details & Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Delete Menu Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2D4059),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                        onSelected: (val) {
                          if (val == 'delete') {
                            _confirmDeleteMovie(movie);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                SizedBox(width: 8),
                                Text('Remove', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Added Date
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Added ${movie.formattedCreatedDate}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  if (movie.notes != null && movie.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"${movie.notes!}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // "Mark as Watched" Action Button
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMarkWatchedModal(movie),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text(
                        'Mark as Watched',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFFFF758C),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: WATCHED TAB
  // ----------------------------------------------------
  Widget _buildWatchedTab(bool isDark, String partnerName) {
    final list = _watchedMovies;

    if (list.isEmpty) {
      return _buildEmptyState(
        isDark: isDark,
        icon: Icons.local_movies_outlined,
        title: _searchQuery.isNotEmpty
            ? 'No watched movies match your search'
            : 'No Watched Movies Yet',
        subtitle: _searchQuery.isNotEmpty
            ? 'Try another movie title or keyword'
            : 'Record your first movie date with $partnerName and rate your favorites.',
        buttonText: 'Log Watched Movie',
        onButtonTap: _openAddMovieModal,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final movie = list[index];
        return _buildWatchedCard(movie, isDark);
      },
    );
  }

  Widget _buildWatchedCard(MovieModel movie, bool isDark) {
    final rating = movie.rating ?? 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E162B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFA18CD1).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFFA18CD1).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie Poster
            MoviePosterWidget(
              posterUrl: movie.posterUrl,
              width: 76,
              height: 108,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Menu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2D4059),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _openMarkWatchedModal(movie);
                          } else if (val == 'delete') {
                            _confirmDeleteMovie(movie);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_note_rounded, color: Color(0xFFFF758C), size: 18),
                                SizedBox(width: 8),
                                Text('Edit Review'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                SizedBox(width: 8),
                                Text('Remove', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Pink Hearts Rating
                  Row(
                    children: List.generate(5, (index) {
                      final isFilled = index < rating;
                      return Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          isFilled ? Icons.favorite : Icons.favorite_border,
                          color: isFilled
                              ? const Color(0xFFFF4081)
                              : Colors.grey.shade400,
                          size: 16,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),

                  // Watched Date (Only shown if watchedDate is NOT null)
                  if (movie.watchedDate != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          size: 13,
                          color: Color(0xFFA18CD1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Watched on ${movie.formattedWatchedDate}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFA18CD1) : const Color(0xFF7E57C2),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Notes / Review Bubble (Emoji-free)
                  if (movie.notes != null && movie.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFFF758C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFFF758C).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '"${movie.notes!}"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : const Color(0xFF4A4A4A),
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
              onPressed: _initMoviesStream,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
