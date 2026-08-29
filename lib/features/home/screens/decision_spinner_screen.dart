import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/movie_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_data_service.dart';
import '../../../services/supabase_movie_service.dart';
import '../../movies/screens/movie_tracker_screen.dart';
import '../../movies/widgets/movie_poster_widget.dart';

/// Representation of a slice on the merged wheel
class _WheelSliceItem {
  final String label;
  final bool isCustom;
  final IconData onlineIcon;

  const _WheelSliceItem({
    required this.label,
    required this.isCustom,
    required this.onlineIcon,
  });
}

/// Pure Custom & Online Decision Spinner Screen
/// - Custom options are merged on the wheel alongside online icon slices
/// - Custom options show their text labels; online suggestion slices show Material online icons
/// - Dual persistence via SharedPreferences & Supabase so custom options are never lost on back navigation
class DecisionSpinnerScreen extends StatefulWidget {
  const DecisionSpinnerScreen({super.key});

  @override
  State<DecisionSpinnerScreen> createState() => _DecisionSpinnerScreenState();
}

class _DecisionSpinnerScreenState extends State<DecisionSpinnerScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  final SupabaseMovieService _movieService = SupabaseMovieService();

  int _selectedCategoryIndex = 0; // 0: Food & Drinks, 1: Dates & Activities, 2: Movie Watchlist
  int _spinnerModeIndex = 0; // 0: Spin Wheel, 1: Quick Roulette
  bool _isSpinning = false;
  String _currentDisplayResult = 'Tap Spin to Decide!';

  // Wheel Physics Animation
  late AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  double _currentWheelAngle = 0.0;
  double _startWheelAngle = 0.0;
  double _targetWheelAngle = 0.0;
  Timer? _quickSlotTimer;
  StreamSubscription<List<MovieModel>>? _moviesSubscription;

  // Persistent History tracking across navigations to prevent auto-resetting
  final List<String> _foodHistory = [];
  final List<String> _activityHistory = [];
  final List<String> _watchHistory = [];

  // Filter out any previous auto-seeded defaults from DB
  static const List<String> _defaultFilterOutList = [
    'Sinigang na Baboy',
    'Crispy Pork Sisig',
    'Beef Pares & Mami',
    'Chicken Inasal',
    'Kare-Kareng Baka',
    'Lechon Kawali',
    'Samgyupsal & K-BBQ',
    'Samgyupsal / K-BBQ',
    'Halo-Halo & Ice Cream',
    'Halo-Halo & Ube Ice Cream',
    'Milk Tea & Street Food',
    'Milk Tea & Boba',
    'Pancit Canton & Dimsum',
    'Pancit Bihon & Dimsum',
    'Sunset Walk in Seaside / Baywalk',
    'Sunset Walk in Park',
    'Videoke & Karaoke Night',
    'Videoke / Karaoke',
    'Night Market & Street Food Crawl',
    'Intramuros Historic Stroll',
    'Coffee Date & Pastries',
    'Coffee Date & Pastry',
    'BGC / Park Picnic & Photos',
    'Park Picnic & Photos',
    'Arcade & Bowling Match',
    'Shopping & Arcade',
    'Roadtrip to Tagaytay Overlook',
    'Night Drive & Snacks',
    'Board Games & Netflix Marathon',
    'Board Games Match',
    'Cinema Movie Night',
    'Co-op Gaming Session',
    'Co-op Video Game Session',
    'Cook Dinner Together',
    'Ramen & Bento Box',
    'Pizza & Pasta Date',
    'Dessert & Ice Cream',
    'Jollibee Chickenjoy',
  ];

  // Dynamic Online Filipino Suggestions (picked online dynamically)
  static const List<String> _onlineFilipinoFood = [
    'Sinigang na Baboy',
    'Crispy Pork Sisig',
    'Beef Pares & Mami',
    'Chicken Inasal',
    'Kare-Kareng Baka',
    'Lechon Kawali',
    'Samgyupsal & K-BBQ',
    'Halo-Halo & Ice Cream',
    'Milk Tea & Street Food',
    'Pancit Canton & Dimsum',
    'Ramen & Gyoza Date',
    'Pizza & Pasta Treat',
  ];

  static const List<String> _onlineFilipinoActivities = [
    'Sunset Walk in Seaside / Baywalk',
    'Videoke & Karaoke Night',
    'Night Market & Street Food Crawl',
    'Intramuros Historic Stroll',
    'Coffee Date & Pastries',
    'BGC / Park Picnic & Photos',
    'Arcade & Bowling Match',
    'Roadtrip to Tagaytay Overlook',
    'Board Games & Netflix Marathon',
    'Late Night Drive & Snacks',
    'Co-op Video Game Session',
    'Cook Dinner Together',
  ];

  static const List<IconData> _onlineSliceIcons = [
    Icons.language_rounded,
    Icons.cloud_queue_rounded,
    Icons.wifi_rounded,
    Icons.public_rounded,
    Icons.explore_rounded,
    Icons.hub_rounded,
    Icons.travel_explore_rounded,
    Icons.stream_rounded,
  ];

  // Active Options Lists (Strictly Custom Added Choices Synced Online in Supabase & SharedPreferences)
  final List<String> _foodOptions = [];
  final List<String> _activityOptions = [];
  final List<String> _watchOptions = [];
  final List<MovieModel> _watchMovies = [];

  List<String> get _currentOptions {
    switch (_selectedCategoryIndex) {
      case 0:
        return _foodOptions;
      case 1:
        return _activityOptions;
      default:
        return _watchOptions;
    }
  }

  List<String> get _currentHistory {
    switch (_selectedCategoryIndex) {
      case 0:
        return _foodHistory;
      case 1:
        return _activityHistory;
      default:
        return _watchHistory;
    }
  }

  /// Merged wheel slices: Custom options + Online icon slices together on the wheel!
  List<_WheelSliceItem> get _wheelDisplaySlices {
    if (_selectedCategoryIndex == 2) {
      // Movie Watchlist
      return _watchOptions
          .map((title) => _WheelSliceItem(
                label: title,
                isCustom: true,
                onlineIcon: Icons.movie_rounded,
              ))
          .toList();
    }

    final customList = _currentOptions;
    if (customList.isEmpty) {
      // Pure online icon slices (8 slices)
      return List.generate(
        8,
        (i) => _WheelSliceItem(
          label: '',
          isCustom: false,
          onlineIcon: _onlineSliceIcons[i % _onlineSliceIcons.length],
        ),
      );
    }

    // Merged: Custom options (with text labels) + Online suggestion slices (with online icons)
    final result = <_WheelSliceItem>[];
    final totalCount = max(8, customList.length * 2);
    int customIndex = 0;

    for (int i = 0; i < totalCount; i++) {
      if (i % 2 == 0 && customIndex < customList.length) {
        result.add(_WheelSliceItem(
          label: customList[customIndex],
          isCustom: true,
          onlineIcon: Icons.star_rounded,
        ));
        customIndex++;
      } else {
        result.add(_WheelSliceItem(
          label: '',
          isCustom: false,
          onlineIcon: _onlineSliceIcons[i % _onlineSliceIcons.length],
        ));
      }
    }

    while (customIndex < customList.length) {
      result.add(_WheelSliceItem(
        label: customList[customIndex],
        isCustom: true,
        onlineIcon: Icons.star_rounded,
      ));
      customIndex++;
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _wheelAnimation = CurvedAnimation(
      parent: _wheelController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersistentData();
      _fetchOnlineSyncedData();
      _initMovieDiaryStream();
    });
  }

  @override
  void dispose() {
    _moviesSubscription?.cancel();
    _wheelController.dispose();
    _quickSlotTimer?.cancel();
    super.dispose();
  }

  /// Load persistent custom options and excluded history from SharedPreferences
  Future<void> _loadPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        // Load Custom Options from Local Cache immediately
        final cachedFood =
            prefs.getStringList('decision_spinner_custom_food') ?? [];
        final cachedActivities =
            prefs.getStringList('decision_spinner_custom_activities') ?? [];

        _foodOptions.clear();
        _foodOptions.addAll(cachedFood);

        _activityOptions.clear();
        _activityOptions.addAll(cachedActivities);

        // Load Excluded History
        _foodHistory.clear();
        _foodHistory
            .addAll(prefs.getStringList('decision_spinner_food_history') ?? []);
        _activityHistory.clear();
        _activityHistory.addAll(
            prefs.getStringList('decision_spinner_activity_history') ?? []);
        _watchHistory.clear();
        _watchHistory
            .addAll(prefs.getStringList('decision_spinner_watch_history') ?? []);
      });
    } catch (_) {}
  }

  /// Save persistent custom options and excluded history to SharedPreferences
  Future<void> _savePersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('decision_spinner_custom_food', _foodOptions);
      await prefs.setStringList(
          'decision_spinner_custom_activities', _activityOptions);
      await prefs.setStringList('decision_spinner_food_history', _foodHistory);
      await prefs.setStringList(
          'decision_spinner_activity_history', _activityHistory);
      await prefs.setStringList('decision_spinner_watch_history', _watchHistory);
    } catch (_) {}
  }

  /// Reset the excluded history only when the user explicitly triggers it
  Future<void> _resetCurrentHistory() async {
    HapticFeedback.lightImpact();
    setState(() {
      _currentHistory.clear();
    });
    await _savePersistentData();
    if (mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Excluded options reset! All items are ready to spin again.',
      );
    }
  }

  String _getCoupleId() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final coupleProvider =
          Provider.of<CoupleProvider>(context, listen: false);
      return userProvider.coupleId ?? coupleProvider.couple?.id ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Real-time live stream from Movie Diary (Cinema Diary)
  void _initMovieDiaryStream() {
    final coupleId = _getCoupleId();
    if (coupleId.isEmpty) return;

    _moviesSubscription?.cancel();
    _moviesSubscription = _movieService.streamMovies(coupleId).listen(
      (movies) {
        if (!mounted) return;
        final unWatched = movies
            .where((m) =>
                !m.isWatched &&
                m.status.toLowerCase() != 'watched' &&
                m.status.toLowerCase() != 'already watched')
            .toList();

        setState(() {
          _watchMovies.clear();
          _watchMovies.addAll(unWatched);

          _watchOptions.clear();
          _watchOptions.addAll(unWatched.map((m) => m.title.trim()).toList());
        });
      },
      onError: (e) {
        debugPrint('Error streaming Movie Diary in spinner: $e');
      },
    );
  }

  /// Fetch user custom ideas from Supabase and merge with local SharedPreferences cache
  Future<void> _fetchOnlineSyncedData() async {
    try {
      final coupleId = _getCoupleId();

      final customFood = <String>[..._foodOptions];
      final customActivities = <String>[..._activityOptions];

      if (coupleId.isNotEmpty) {
        final response = await SupabaseDataService.client
            .from('decision_ideas')
            .select()
            .eq('couple_id', coupleId);

        final records = List<Map<String, dynamic>>.from(response);

        for (final row in records) {
          final category = row['category']?.toString().toLowerCase() ?? '';
          final title = row['title']?.toString().trim() ?? '';
          final isCustomFlag =
              row['is_custom'] == true || row['is_custom'] == 'true';

          // Clean up previously auto-seeded default items from database
          if (_defaultFilterOutList.contains(title) && !isCustomFlag) {
            SupabaseDataService.client
                .from('decision_ideas')
                .delete()
                .eq('title', title)
                .eq('couple_id', coupleId)
                .catchError((_) {});
            continue;
          }

          if (title.isNotEmpty) {
            if (category == 'food' && !customFood.contains(title)) {
              customFood.add(title);
            } else if (category == 'activity' &&
                !customActivities.contains(title)) {
              customActivities.add(title);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _foodOptions.clear();
          _foodOptions.addAll(customFood);

          _activityOptions.clear();
          _activityOptions.addAll(customActivities);
        });
        _savePersistentData();
      }

      // Fetch movies directly from couple's Watchlist in Movie Diary
      if (coupleId.isNotEmpty) {
        final movies = await _movieService.fetchMovies(coupleId);
        if (movies.isNotEmpty) {
          final unWatched = movies
              .where((m) =>
                  !m.isWatched &&
                  m.status.toLowerCase() != 'watched' &&
                  m.status.toLowerCase() != 'already watched')
              .toList();

          if (mounted) {
            setState(() {
              _watchMovies.clear();
              _watchMovies.addAll(unWatched);

              _watchOptions.clear();
              _watchOptions
                  .addAll(unWatched.map((m) => m.title.trim()).toList());
            });
          }
        }
      }
    } catch (_) {}
  }

  /// Weighted winner selection algorithm:
  /// - If custom options exist: 80% chance to pick custom option, 20% to fetch online Filipino suggestion.
  /// - If 0 custom options: 100% online dynamic Filipino suggestion.
  String _pickWinner() {
    if (_selectedCategoryIndex == 2) {
      // Movie Watchlist: uniform distribution
      final available = _watchOptions
          .where((m) => !_watchHistory.contains(m))
          .toList();
      final pool = available.isNotEmpty ? available : _watchOptions;
      if (available.isEmpty) {
        _watchHistory.clear();
        _savePersistentData();
      }
      return pool[_random.nextInt(pool.length)];
    }

    final availableCustom = _currentOptions
        .where((item) => !_currentHistory.contains(item))
        .toList();

    final onlinePool = (_selectedCategoryIndex == 0
            ? _onlineFilipinoFood
            : _onlineFilipinoActivities)
        .where((item) => !_currentHistory.contains(item))
        .toList();

    final activeOnlineList = onlinePool.isNotEmpty
        ? onlinePool
        : (_selectedCategoryIndex == 0
            ? _onlineFilipinoFood
            : _onlineFilipinoActivities);

    if (availableCustom.isNotEmpty) {
      final roll = _random.nextDouble(); // 0.0 to 1.0
      if (roll < 0.80 || activeOnlineList.isEmpty) {
        // 80% weighted chance: Pick one of the couple's custom options!
        return availableCustom[_random.nextInt(availableCustom.length)];
      } else {
        // 20% chance: Fetch an online suggestion!
        return activeOnlineList[_random.nextInt(activeOnlineList.length)];
      }
    } else {
      // 0 custom options: Picks directly from online suggestions
      return activeOnlineList[_random.nextInt(activeOnlineList.length)];
    }
  }

  /// Pick winner and calculate target wedge index on the merged wheel
  ({String winner, int targetSliceIndex}) _pickWinnerWithTarget() {
    final slices = _wheelDisplaySlices;
    final winner = _pickWinner();

    if (_selectedCategoryIndex == 2) {
      final idx = slices.indexWhere((s) => s.label == winner);
      return (
        winner: winner,
        targetSliceIndex: idx >= 0 ? idx : 0,
      );
    }

    if (_currentOptions.contains(winner)) {
      // Winner is a custom option -> land on its custom slice
      final idx = slices.indexWhere((s) => s.isCustom && s.label == winner);
      return (
        winner: winner,
        targetSliceIndex: idx >= 0 ? idx : 0,
      );
    } else {
      // Winner is an online suggestion -> land on an online icon slice
      final onlineIndices = [
        for (int i = 0; i < slices.length; i++)
          if (!slices[i].isCustom) i
      ];
      final targetIdx = onlineIndices.isNotEmpty
          ? onlineIndices[_random.nextInt(onlineIndices.length)]
          : 0;
      return (
        winner: winner,
        targetSliceIndex: targetIdx,
      );
    }
  }

  /// Trigger the appropriate spin mode
  void _onSpinPressed() {
    if (_isSpinning) return;
    if (_selectedCategoryIndex == 2 && _watchOptions.length < 2) {
      HapticFeedback.vibrate();
      SnackbarHelper.showError(
        context,
        'Please add at least 2 unwatched movies in Movie Diary to spin!',
      );
      return;
    }

    if (_spinnerModeIndex == 0) {
      _startVisualWheelSpin();
    } else {
      _startQuickSlotSpin();
    }
  }

  /// Interactive Visual Wheel Physics Spin on the merged wheel
  void _startVisualWheelSpin() {
    final slices = _wheelDisplaySlices;
    if (slices.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSpinning = true;
    });

    final decision = _pickWinnerWithTarget();
    final sliceCount = slices.length;

    final sliceAngle = (2 * pi) / sliceCount;
    final targetWedgeLocalCenter =
        (decision.targetSliceIndex + 0.5) * sliceAngle;

    final targetNormalizedAngle =
        (-pi / 2 - targetWedgeLocalCenter) % (2 * pi);

    final currentNormalized = _currentWheelAngle % (2 * pi);
    double diff = targetNormalizedAngle - currentNormalized;
    if (diff < 0) diff += 2 * pi;

    final extraTurns = 5 + _random.nextInt(3); // 5 to 7 full rotations
    final finalTargetAngle = _currentWheelAngle + (2 * pi * extraTurns) + diff;

    _startWheelAngle = _currentWheelAngle;
    _targetWheelAngle = finalTargetAngle;
    final totalDistance = _targetWheelAngle - _startWheelAngle;

    int lastTickIndex = -1;
    void tickListener() {
      final currentAngle =
          _startWheelAngle + (totalDistance * _wheelAnimation.value);
      final normalized = (currentAngle % (2 * pi) + (2 * pi)) % (2 * pi);
      final currentSlice = (normalized / sliceAngle).floor();
      if (currentSlice != lastTickIndex) {
        lastTickIndex = currentSlice;
        HapticFeedback.selectionClick();
      }
    }

    _wheelController.removeListener(tickListener);
    _wheelController.addListener(tickListener);

    _wheelController.reset();
    _wheelController.forward().then((_) {
      _wheelController.removeListener(tickListener);
      _currentWheelAngle = finalTargetAngle;
      _finalizeDecision(decision.winner);
    });
  }

  /// Quick Slot-Machine Carousel Spin
  void _startQuickSlotSpin() {
    final displayPool = _selectedCategoryIndex == 2
        ? _watchOptions
        : (_currentOptions.isNotEmpty
            ? _currentOptions
            : const [
                'Deciding Online Selection...',
                'Spinning Online Suggestions...',
                'Exploring Online Ideas...',
                'Selecting Online Choice...'
              ]);

    if (displayPool.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSpinning = true;
    });

    int ticks = 0;
    const totalTicks = 20;

    _quickSlotTimer?.cancel();
    _quickSlotTimer = Timer.periodic(const Duration(milliseconds: 65), (timer) {
      ticks++;
      HapticFeedback.selectionClick();

      final randomIndex = _random.nextInt(displayPool.length);
      setState(() {
        _currentDisplayResult = displayPool[randomIndex];
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        final winner = _pickWinner();
        _finalizeDecision(winner);
      }
    });
  }

  void _finalizeDecision(String winner) {
    HapticFeedback.heavyImpact();

    setState(() {
      _isSpinning = false;
      _currentDisplayResult = winner;
      _currentHistory.add(winner);
    });

    _savePersistentData();

    MovieModel? winningMovie;
    if (_selectedCategoryIndex == 2) {
      try {
        winningMovie = _watchMovies.firstWhere(
          (m) => m.title.trim().toLowerCase() == winner.trim().toLowerCase(),
        );
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          backgroundColor:
              isDark ? const Color(0xFF1E162B) : Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Decision Made!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'The wheel has chosen for both of you:',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Movie Banner Poster Preview if Movie Category
              if (winningMovie != null &&
                  winningMovie.posterUrl != null &&
                  winningMovie.posterUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: MoviePosterWidget(
                      posterUrl: winningMovie.posterUrl,
                      width: 120,
                      height: 170,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFFFF758C).withValues(alpha: 0.25),
                            const Color(0xFFA18CD1).withValues(alpha: 0.25),
                          ]
                        : [
                            const Color(0xFFFF758C).withValues(alpha: 0.15),
                            const Color(0xFFA18CD1).withValues(alpha: 0.2),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  winner,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Anti-repeat active for next spin',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _onSpinPressed();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFFF758C),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Spin Again',
                            style: TextStyle(
                              color: Color(0xFFFF758C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C)
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Let\'s Do It!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedCategoryIndex == 2) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MovieTrackerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.movie_rounded, size: 16),
                      label: const Text('Open in Movie Diary'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF758C),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Add custom option and sync it online directly to Supabase & SharedPreferences
  void _showAddCustomOptionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Add Custom ${_selectedCategoryIndex == 0 ? "Food & Drink" : "Date & Activity"}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: Theme.of(ctx).brightness == Brightness.dark
                ? Colors.white
                : AppColors.deepCharcoal,
          ),
          decoration: InputDecoration(
            hintText: _selectedCategoryIndex == 0
                ? 'e.g. Samgyupsal, Crispy Sisig, Milk Tea...'
                : 'e.g. Sunset in Manila Bay, Arcade Night...',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFFF758C), width: 1.2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFFF758C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(ctx);
                          await _saveCustomOption(text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Add Option',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Save custom option to local cache (SharedPreferences) and online Supabase database
  Future<void> _saveCustomOption(String text) async {
    final category = _selectedCategoryIndex == 0 ? 'food' : 'activity';

    setState(() {
      if (_selectedCategoryIndex == 0) {
        if (!_foodOptions.contains(text)) _foodOptions.insert(0, text);
      } else {
        if (!_activityOptions.contains(text)) _activityOptions.insert(0, text);
      }
    });

    await _savePersistentData();

    if (mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Added "$text" to wheel options!',
      );
    }

    try {
      final coupleId = _getCoupleId();
      await SupabaseDataService.client.from('decision_ideas').insert({
        if (coupleId.isNotEmpty) 'couple_id': coupleId,
        'category': category,
        'title': text,
        'is_custom': true,
      });
    } catch (_) {}
  }

  /// Delete option from list, local cache (SharedPreferences), and online Supabase database
  Future<void> _removeOption(String option) async {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedCategoryIndex == 0) {
        _foodOptions.remove(option);
      } else if (_selectedCategoryIndex == 1) {
        _activityOptions.remove(option);
      } else {
        _watchOptions.remove(option);
        _watchMovies.removeWhere((m) => m.title.trim() == option.trim());
      }
      _currentHistory.remove(option);
    });

    await _savePersistentData();

    try {
      final coupleId = _getCoupleId();
      if (coupleId.isNotEmpty) {
        await SupabaseDataService.client
            .from('decision_ideas')
            .delete()
            .eq('title', option)
            .eq('couple_id', coupleId);
      } else {
        await SupabaseDataService.client
            .from('decision_ideas')
            .delete()
            .eq('title', option);
      }
    } catch (_) {}

    if (mounted) {
      SnackbarHelper.showInfo(context, 'Removed "$option"');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text(
          'Decision Spinner',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            children: [
              // Mode Switcher (Visual Wheel vs Quick Slot)
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
                      child: _buildModeTab(
                        index: 0,
                        label: 'Spin Wheel',
                        icon: Icons.rotate_right_rounded,
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildModeTab(
                        index: 1,
                        label: 'Quick Roulette',
                        icon: Icons.casino_rounded,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Categories Header Chips (Food & Drinks vs Dates & Activities vs Movie Watchlist)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryBadge(
                      index: 0,
                      label: 'Food & Drinks',
                      icon: Icons.restaurant_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryBadge(
                      index: 1,
                      label: 'Dates & Activities',
                      icon: Icons.local_activity_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryBadge(
                      index: 2,
                      label: 'Movie Watchlist',
                      icon: Icons.movie_filter_rounded,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Spinner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E162B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFFF758C).withValues(alpha: 0.25)
                        : const Color(0xFFFF758C).withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Online Connection Indicator Badge
                    if (_selectedCategoryIndex != 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wifi_rounded,
                              size: 13,
                              color: Color(0xFFFF758C),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Online Suggestion Pool Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.deepCharcoal,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_spinnerModeIndex == 0)
                      // Visual Physical Wheel Mode
                      _buildVisualWheel(context, isDark)
                    else
                      // Slot Machine / Carousel Mode
                      _buildSlotMachineView(context, isDark),
                    const SizedBox(height: 18),

                    // Spin Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: _isSpinning ||
                                (_selectedCategoryIndex == 2 &&
                                    _watchOptions.length < 2)
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFFF758C),
                                  Color(0xFFA18CD1)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isSpinning ||
                                (_selectedCategoryIndex == 2 &&
                                    _watchOptions.length < 2)
                            ? (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300)
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isSpinning ||
                                (_selectedCategoryIndex == 2 &&
                                    _watchOptions.length < 2)
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFFFF758C)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSpinning ? null : _onSpinPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: AnimatedRotation(
                          turns: _isSpinning ? 2.0 : 0.0,
                          duration: const Duration(milliseconds: 1200),
                          child: Icon(
                            _spinnerModeIndex == 0
                                ? Icons.rotate_right_rounded
                                : Icons.casino_rounded,
                            size: 24,
                          ),
                        ),
                        label: Text(
                          _isSpinning
                              ? 'Spinning...'
                              : 'Spin Wheel',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Active Wheel Options List & Movie Banners
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedCategoryIndex == 2
                                  ? 'Watchlist Movies (${_watchMovies.length})'
                                  : 'Custom Options (${_currentOptions.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.deepCharcoal,
                              ),
                            ),
                            if (_selectedCategoryIndex != 2) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.cloud_done_rounded,
                                size: 15,
                                color: Color(0xFFFF758C),
                              ),
                            ],
                          ],
                        ),
                        if (_selectedCategoryIndex != 2)
                          TextButton.icon(
                            onPressed: _showAddCustomOptionDialog,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Custom'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF758C),
                              padding: EdgeInsets.zero,
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MovieTrackerScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.movie_rounded, size: 15),
                            label: const Text('Open Movie Diary'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF758C),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),

                    // Persistent Reset Excluded Options Banner
                    if (_currentHistory.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2B1D3A)
                              : const Color(0xFFFF758C)
                                  .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: Color(0xFFFF758C),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_currentHistory.length} excluded from spin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.deepCharcoal,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _resetCurrentHistory,
                              icon: const Icon(Icons.refresh_rounded,
                                  size: 14),
                              label: const Text('Reset Pool'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF758C),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Empty State
                    if (_currentOptions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        child: Column(
                          children: [
                            Icon(
                              _selectedCategoryIndex == 0
                                  ? Icons.restaurant_outlined
                                  : _selectedCategoryIndex == 1
                                      ? Icons.local_activity_outlined
                                      : Icons.movie_outlined,
                              size: 38,
                              color: const Color(0xFFFF758C)
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedCategoryIndex == 0
                                  ? 'No custom food options added'
                                  : _selectedCategoryIndex == 1
                                      ? 'No custom activity options added'
                                      : 'No unwatched movies in Watchlist',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.deepCharcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedCategoryIndex != 2
                                  ? 'Spinning suggests dynamic online Filipino ideas. Tap Add Custom to include your own!'
                                  : 'Add movies to your Watchlist in Movie Diary.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_selectedCategoryIndex != 2)
                              OutlinedButton.icon(
                                onPressed: _showAddCustomOptionDialog,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Custom Option'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFFFF758C)),
                                  foregroundColor: const Color(0xFFFF758C),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MovieTrackerScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.movie_rounded,
                                    size: 16),
                                label: const Text('Open Movie Diary'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF758C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (_selectedCategoryIndex == 2 &&
                        _watchMovies.isNotEmpty)
                      // Horizontal Movie Poster Banner Carousel
                      SizedBox(
                        height: 195,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _watchMovies.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final movie = _watchMovies[index];
                            final isExcluded =
                                _watchHistory.contains(movie.title);

                            return Container(
                              width: 115,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E162B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isExcluded
                                      ? Colors.transparent
                                      : const Color(0xFFFF758C)
                                          .withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                                boxShadow: isExcluded
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFFFF758C)
                                              .withValues(alpha: 0.22),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Poster with Media Tag Badge & Exclusion Overlay
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(14)),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          MoviePosterWidget(
                                            posterUrl: movie.posterUrl,
                                            fit: BoxFit.cover,
                                            showShadow: false,
                                          ),
                                          // Top Corner Colored Badge
                                          Positioned(
                                            top: 6,
                                            left: 6,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                gradient:
                                                    const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFF758C),
                                                    Color(0xFFA18CD1)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    movie.mediaType ==
                                                                'series' ||
                                                            movie.mediaType ==
                                                                'tv'
                                                        ? Icons.tv_rounded
                                                        : Icons.movie_rounded,
                                                    color: Colors.white,
                                                    size: 9,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    movie.mediaType ==
                                                                'series' ||
                                                            movie.mediaType ==
                                                                'tv'
                                                        ? 'Series'
                                                        : 'Movie',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 8.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (isExcluded)
                                            Container(
                                              color: Colors.black54,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.block_rounded,
                                                  color: Colors.white70,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Colored Title Ribbon
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [
                                                const Color(0xFF2A1B36),
                                                const Color(0xFF1E1428),
                                              ]
                                            : [
                                                const Color(0xFFFFF0F3),
                                                const Color(0xFFF6ECF8),
                                              ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        bottom: Radius.circular(14),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      movie.title,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        color: isExcluded
                                            ? (isDark
                                                ? Colors.white38
                                                : Colors.grey.shade500)
                                            : (isDark
                                                ? const Color(0xFFFF8DA1)
                                                : const Color(0xFFC2185B)),
                                        decoration: isExcluded
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _currentOptions.map((opt) {
                          final isPickedRecently =
                              _currentHistory.contains(opt);

                          return Chip(
                            avatar: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFF758C),
                              size: 16,
                            ),
                            label: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isPickedRecently
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: isPickedRecently
                                    ? (isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500)
                                    : (isDark
                                        ? const Color(0xFFFF8DA1)
                                        : const Color(0xFFC2185B)),
                                decoration: isPickedRecently
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            deleteIcon: const Icon(
                              Icons.close_rounded,
                              size: 14,
                            ),
                            deleteIconColor: const Color(0xFFFF758C),
                            onDeleted: () => _removeOption(opt),
                            backgroundColor: isPickedRecently
                                ? (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade100)
                                : (isDark
                                    ? const Color(0xFFFF758C)
                                        .withValues(alpha: 0.25)
                                    : const Color(0xFFFF758C)
                                        .withValues(alpha: 0.16)),
                            side: BorderSide(
                              color: isPickedRecently
                                  ? Colors.transparent
                                  : const Color(0xFFFF758C)
                                      .withValues(alpha: 0.6),
                              width: 1.4,
                            ),
                          );
                        }).toList(),
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

  Widget _buildVisualWheel(BuildContext context, bool isDark) {
    const wheelSize = 280.0;
    final slices = _wheelDisplaySlices;

    return Column(
      children: [
        SizedBox(
          width: wheelSize,
          height: wheelSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Spinning Canvas Wheel with AnimatedBuilder
              AnimatedBuilder(
                animation: _wheelAnimation,
                builder: (context, child) {
                  final angle = _wheelController.isAnimating
                      ? _startWheelAngle +
                          ((_targetWheelAngle - _startWheelAngle) *
                              _wheelAnimation.value)
                      : _currentWheelAngle;

                  return CustomPaint(
                    size: const Size(wheelSize, wheelSize),
                    painter: _DecisionWheelPainter(
                      slices: slices,
                      angle: angle,
                      isDark: isDark,
                    ),
                  );
                },
              ),

              // Interactive Center Spin Hub
              GestureDetector(
                onTap: _isSpinning ? null : _onSpinPressed,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFFF758C).withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'SPIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Top Arrow Pointer
              Positioned(
                top: -8,
                child: Container(
                  width: 28,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Color(0xFFFF758C),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlotMachineView(BuildContext context, bool isDark) {
    MovieModel? currentPreviewMovie;
    if (_selectedCategoryIndex == 2 && _watchMovies.isNotEmpty) {
      try {
        currentPreviewMovie = _watchMovies.firstWhere(
          (m) =>
              m.title.trim().toLowerCase() ==
              _currentDisplayResult.trim().toLowerCase(),
        );
      } catch (_) {}
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFFF758C).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF758C).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Quick Decision Roulette',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color:
                      isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Movie Poster banner thumbnail in slot roulette
          if (currentPreviewMovie != null &&
              currentPreviewMovie.posterUrl != null &&
              currentPreviewMovie.posterUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MoviePosterWidget(
                posterUrl: currentPreviewMovie.posterUrl,
                width: 90,
                height: 125,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            child: Text(
              _currentDisplayResult,
              key: ValueKey<String>(_currentDisplayResult),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.deepCharcoal,
                fontWeight: FontWeight.w900,
                fontSize: 19,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _spinnerModeIndex == index;
    return GestureDetector(
      onTap: () {
        if (_isSpinning) return;
        HapticFeedback.lightImpact();
        setState(() => _spinnerModeIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E223E) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFFFF758C)
                  : (isDark ? Colors.white60 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFFFF758C)
                    : (isDark ? Colors.white60 : Colors.grey.shade700),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedCategoryIndex == index;

    return InkWell(
      onTap: () {
        if (_isSpinning) return;
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCategoryIndex = index;
          _currentDisplayResult = 'Tap Spin to Decide!';
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.deepCharcoal),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter for the Merged Decision Wheel
/// - Renders custom labels on custom wedges
/// - Renders Material online icons on online suggestion wedges
class _DecisionWheelPainter extends CustomPainter {
  final List<_WheelSliceItem> slices;
  final double angle;
  final bool isDark;

  _DecisionWheelPainter({
    required this.slices,
    required this.angle,
    required this.isDark,
  });

  static const List<List<Color>> sliceGradients = [
    [Color(0xFFFF6584), Color(0xFFFF8DA1)],
    [Color(0xFF8E7CC3), Color(0xFFA18CD1)],
    [Color(0xFFFF7E95), Color(0xFFFFAAA6)],
    [Color(0xFF7E57C2), Color(0xFF9575CD)],
    [Color(0xFFFF80AB), Color(0xFFF48FB1)],
    [Color(0xFFBA68C8), Color(0xFFCE93D8)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    final count = slices.isNotEmpty ? slices.length : 8;
    final sliceAngle = (2 * pi) / count;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Draw Slices
    for (int i = 0; i < count; i++) {
      final startAngle = i * sliceAngle;
      final sweepAngle = sliceAngle;

      final gradientPair = sliceGradients[i % sliceGradients.length];
      final slicePaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: gradientPair,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        true,
        slicePaint,
      );

      // Slice separator line
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final endX = radius * cos(startAngle);
      final endY = radius * sin(startAngle);
      canvas.drawLine(Offset.zero, Offset(endX, endY), linePaint);

      // Radial slice rendering
      canvas.save();
      final textAngle = startAngle + sweepAngle / 2;
      canvas.rotate(textAngle);

      final slice = i < slices.length
          ? slices[i]
          : const _WheelSliceItem(
              label: '',
              isCustom: false,
              onlineIcon: Icons.language_rounded,
            );

      if (slice.isCustom && slice.label.isNotEmpty) {
        // Draw Custom Option / Movie Label
        final label = slice.label;
        final maxChars = count > 8 ? 10 : 14;
        final displayLabel = label.length > maxChars
            ? '${label.substring(0, maxChars)}...'
            : label;

        final textSpan = TextSpan(
          text: displayLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: count > 8 ? 9.5 : 11.5,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout(maxWidth: radius * 0.62);

        final textOffset = Offset(radius * 0.28, -textPainter.height / 2);
        textPainter.paint(canvas, textOffset);
      } else {
        // Draw Material Online Icon on slice
        final iconData = slice.onlineIcon;
        final textSpan = TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: 16,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            color: Colors.white.withValues(alpha: 0.9),
            shadows: const [
              Shadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(radius * 0.52 - textPainter.width / 2,
              -textPainter.height / 2),
        );
      }

      canvas.restore();
    }

    // Outer rim ring
    final rimPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, radius, rimPaint);

    // Perimeter decorative studs
    final dotPaint = Paint()..color = Colors.white;
    const dotCount = 20;
    for (int d = 0; d < dotCount; d++) {
      final dotAngle = d * (2 * pi / dotCount);
      final dotX = (radius - 2) * cos(dotAngle);
      final dotY = (radius - 2) * sin(dotAngle);
      canvas.drawCircle(Offset(dotX, dotY), 1.8, dotPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DecisionWheelPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.slices != slices ||
        oldDelegate.isDark != isDark;
  }
}
