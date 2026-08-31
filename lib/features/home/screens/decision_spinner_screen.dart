import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../../widgets/common/app_text_field.dart';

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

/// Pure Custom & Online Decision Spinner Screen with Swapped Positions:
/// 0: Movie Watchlist (Front) | 1: Dates & Activities | 2: Food & Drinks
class DecisionSpinnerScreen extends StatefulWidget {
  const DecisionSpinnerScreen({super.key});

  @override
  State<DecisionSpinnerScreen> createState() => _DecisionSpinnerScreenState();
}

class _DecisionSpinnerScreenState extends State<DecisionSpinnerScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  final SupabaseMovieService _movieService = SupabaseMovieService();
  final GlobalKey<_WheelPointerWidgetState> _pointerKey = GlobalKey();

  int _selectedCategoryIndex = 0; // 0: Movie Watchlist (Front), 1: Dates & Activities, 2: Food & Drinks
  int _spinnerModeIndex = 0; // 0: Spin Wheel, 1: Quick Roulette
  bool _isSpinning = false;
  bool _isInitialized = false;
  bool _isMoviesLoading = true; // True until Supabase stream delivers first batch
  String _currentDisplayResult = 'Tap Spin to Decide!';
  RealtimeChannel? _spinnerChannel;
  MovieModel? _pickedMovie;
  String? _lastActivityResult;
  String? _lastFoodResult;

  // Wheel Physics Animation
  late AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  double _currentWheelAngle = 0.0;
  double _startWheelAngle = 0.0;
  double _targetWheelAngle = 0.0;
  Timer? _quickSlotTimer;
  StreamSubscription<List<MovieModel>>? _moviesSubscription;

  // Persistent History tracking across navigations to prevent auto-resetting
  final List<String> _watchHistory = [];
  final List<String> _activityHistory = [];
  final List<String> _foodHistory = [];

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
  final List<String> _watchOptions = [];
  final List<MovieModel> _watchMovies = [];
  final List<String> _activityOptions = [];
  final List<String> _foodOptions = [];

  List<String> get _currentOptions {
    switch (_selectedCategoryIndex) {
      case 0:
        return _watchOptions;
      case 1:
        return _activityOptions;
      default:
        return _foodOptions;
    }
  }

  List<String> get _currentHistory {
    switch (_selectedCategoryIndex) {
      case 0:
        return _watchHistory;
      case 1:
        return _activityHistory;
      default:
        return _foodHistory;
    }
  }

  /// Merged wheel slices: Custom options + Online icon slices together on the wheel!
  List<_WheelSliceItem> get _wheelDisplaySlices {
    if (_selectedCategoryIndex == 0) {
      // Movie Watchlist (Front tab)
      if (_watchOptions.isEmpty) {
        return List.generate(
          8,
          (i) => const _WheelSliceItem(
            label: '',
            isCustom: false,
            onlineIcon: Icons.movie_rounded,
          ),
        );
      }
      if (_watchOptions.length == 1) {
        return List.generate(
          6,
          (i) => _WheelSliceItem(
            label: _watchOptions[0],
            isCustom: true,
            onlineIcon: Icons.movie_rounded,
          ),
        );
      }
      if (_watchOptions.length == 2) {
        return List.generate(
          6,
          (i) => _WheelSliceItem(
            label: _watchOptions[i % 2],
            isCustom: true,
            onlineIcon: Icons.movie_rounded,
          ),
        );
      }
      if (_watchOptions.length == 3) {
        return List.generate(
          6,
          (i) => _WheelSliceItem(
            label: _watchOptions[i % 3],
            isCustom: true,
            onlineIcon: Icons.movie_rounded,
          ),
        );
      }
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

    if (customList.length == 1) {
      return List.generate(
        6,
        (i) => i % 2 == 0
            ? _WheelSliceItem(
                label: customList[0],
                isCustom: true,
                onlineIcon: Icons.star_rounded,
              )
            : _WheelSliceItem(
                label: '',
                isCustom: false,
                onlineIcon: _onlineSliceIcons[i % _onlineSliceIcons.length],
              ),
      );
    }

    if (customList.length == 2) {
      return List.generate(
        6,
        (i) => i % 2 == 0
            ? _WheelSliceItem(
                label: customList[(i ~/ 2) % 2],
                isCustom: true,
                onlineIcon: Icons.star_rounded,
              )
            : _WheelSliceItem(
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

    _loadPersistentData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeChannel();
      _fetchOnlineSyncedData();
      _initMovieDiaryStream();
    });
  }

  @override
  void dispose() {
    if (_spinnerChannel != null) {
      try {
        SupabaseDataService.client.removeChannel(_spinnerChannel!);
      } catch (_) {}
    }
    _moviesSubscription?.cancel();
    _wheelController.dispose();
    _quickSlotTimer?.cancel();
    super.dispose();
  }

  /// Setup Real-time Supabase Broadcast Channel for Live Dual Spinner Sync
  void _setupRealtimeChannel() {
    final coupleId = _getCoupleId();
    if (coupleId.isEmpty) return;

    try {
      _spinnerChannel =
          SupabaseDataService.client.channel('decision_spinner:$coupleId');

      _spinnerChannel!.onBroadcast(
        event: 'spin_start',
        callback: (payload) {
          if (!mounted) return;
          final senderId = payload['userId']?.toString();
          final myUserId =
              Provider.of<UserProvider>(context, listen: false).user?.uid;
          if (senderId != null && senderId == myUserId) return;

          final catIndex = payload['categoryIndex'] as int? ?? 0;
          final modeIndex = payload['modeIndex'] as int? ?? 0;
          final winner = payload['winner']?.toString();
          final targetSliceIndex = payload['targetSliceIndex'] as int?;
          final extraTurns = payload['extraTurns'] as int?;
          final posterUrl = payload['posterUrl']?.toString();
          final mediaType = payload['mediaType']?.toString();
          final watchCount = payload['watchCount'] as int? ?? 1;
          final movieId = payload['movieId']?.toString();

          setState(() {
            _selectedCategoryIndex = catIndex;
            _spinnerModeIndex = modeIndex;
          });

          if (modeIndex == 0) {
            _startVisualWheelSpin(
              fromRemote: true,
              remoteWinner: winner,
              remoteTargetSliceIndex: targetSliceIndex,
              remoteExtraTurns: extraTurns,
              remotePosterUrl: posterUrl,
              remoteMediaType: mediaType,
              remoteWatchCount: watchCount,
              remoteMovieId: movieId,
            );
          } else {
            _startQuickSlotSpin(
              fromRemote: true,
              remoteWinner: winner,
              remotePosterUrl: posterUrl,
              remoteMediaType: mediaType,
              remoteWatchCount: watchCount,
              remoteMovieId: movieId,
            );
          }
        },
      );

      _spinnerChannel!.onBroadcast(
        event: 'decision_made',
        callback: (payload) {
          if (!mounted) return;
          final senderId = payload['userId']?.toString();
          final myUserId =
              Provider.of<UserProvider>(context, listen: false).user?.uid;
          final winner = payload['winner']?.toString() ?? '';
          final catIndex = payload['categoryIndex'] as int? ?? 0;
          final posterUrl = payload['posterUrl']?.toString();
          final mediaType = payload['mediaType']?.toString() ?? 'movie';
          final watchCount = payload['watchCount'] as int? ?? 1;
          final movieId = payload['movieId']?.toString();

          setState(() {
            _selectedCategoryIndex = catIndex;
            _currentDisplayResult = winner;
            _isSpinning = false;
            if (catIndex == 1) {
              _lastActivityResult = winner;
            } else if (catIndex == 2) {
              _lastFoodResult = winner;
            }
          });
          _savePersistentData();

          if (catIndex == 0 && winner.isNotEmpty) {
            _checkAndSetPickedMovie(
              winner,
              posterUrl: posterUrl,
              mediaType: mediaType,
              watchCount: watchCount,
              movieId: movieId,
            );
          }

          if (senderId != null && senderId != myUserId && winner.isNotEmpty) {
            _finalizeDecision(
              winner,
              fromRemote: true,
              posterUrl: posterUrl,
              mediaType: mediaType,
              watchCount: watchCount,
              movieId: movieId,
            );
          }
        },
      );

      _spinnerChannel!.onBroadcast(
        event: 'reset_spinner',
        callback: (_) {
          if (!mounted) return;
          setState(() {
            _pickedMovie = null;
            _watchHistory.clear();
            _currentDisplayResult = 'Tap Spin to Decide!';
          });
          _savePersistentData();
        },
      );

      _spinnerChannel!.onBroadcast(
        event: 'reset_pool',
        callback: (payload) {
          if (!mounted) return;
          final catIndex =
              payload['categoryIndex'] as int? ?? _selectedCategoryIndex;
          setState(() {
            if (catIndex == 1) {
              _activityHistory.clear();
              _lastActivityResult = null;
            } else if (catIndex == 2) {
              _foodHistory.clear();
              _lastFoodResult = null;
            } else {
              _currentHistory.clear();
            }
            if (_selectedCategoryIndex == catIndex) {
              _currentDisplayResult = 'Tap Spin to Decide!';
            }
          });
          _savePersistentData();
        },
      );

      _spinnerChannel!.onBroadcast(
        event: 'pool_updated',
        callback: (_) {
          if (!mounted) return;
          _fetchOnlineSyncedData();
        },
      );

      _spinnerChannel!.subscribe();
    } catch (e) {
      debugPrint('Error setting up spinner realtime channel: $e');
    }
  }

  /// Load persistent custom options and excluded history from SharedPreferences
  Future<void> _loadPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        // Always default to Movie Watchlist (Tab 0) when opening the Decision Spinner
        _selectedCategoryIndex = 0;

        // Load Cached Movie Watchlist Options for instant zero-delay wheel rendering
        final cachedWatch =
            prefs.getStringList('decision_spinner_cached_watch_options') ?? [];
        if (cachedWatch.isNotEmpty) {
          _watchOptions.clear();
          _watchOptions.addAll(cachedWatch);
        }

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

        // Load Last Spin Results per category
        _lastActivityResult =
            prefs.getString('decision_spinner_last_activity_result');
        _lastFoodResult =
            prefs.getString('decision_spinner_last_food_result');

        // Load Active Picked Movie from Local Cache
        final cachedMovieTitle =
            prefs.getString('decision_spinner_picked_movie_title');
        final cachedMoviePoster =
            prefs.getString('decision_spinner_picked_movie_poster');
        if (cachedMovieTitle != null && cachedMovieTitle.isNotEmpty) {
          _pickedMovie = MovieModel(
            coupleId: _getCoupleId(),
            title: cachedMovieTitle,
            posterUrl: cachedMoviePoster,
            status: 'watchlist',
            mediaType: 'movie',
            createdAt: DateTime.now(),
          );
        }

        // Initial display result for Movie Watchlist (Front tab)
        _currentDisplayResult = _pickedMovie?.title ?? 'Tap Spin to Decide!';

        _isInitialized = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  /// Save persistent custom options and excluded history to SharedPreferences
  Future<void> _savePersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_watchOptions.isNotEmpty) {
        await prefs.setStringList(
            'decision_spinner_cached_watch_options', _watchOptions);
      }
      await prefs.setStringList('decision_spinner_custom_food', _foodOptions);
      await prefs.setStringList(
          'decision_spinner_custom_activities', _activityOptions);
      await prefs.setStringList('decision_spinner_food_history', _foodHistory);
      await prefs.setStringList(
          'decision_spinner_activity_history', _activityHistory);
      await prefs.setStringList('decision_spinner_watch_history', _watchHistory);

      if (_lastActivityResult != null && _lastActivityResult!.isNotEmpty) {
        await prefs.setString(
            'decision_spinner_last_activity_result', _lastActivityResult!);
      } else {
        await prefs.remove('decision_spinner_last_activity_result');
      }

      if (_lastFoodResult != null && _lastFoodResult!.isNotEmpty) {
        await prefs.setString(
            'decision_spinner_last_food_result', _lastFoodResult!);
      } else {
        await prefs.remove('decision_spinner_last_food_result');
      }

      if (_pickedMovie != null) {
        await prefs.setString(
            'decision_spinner_picked_movie_title', _pickedMovie!.title);
        if (_pickedMovie!.posterUrl != null &&
            _pickedMovie!.posterUrl!.isNotEmpty) {
          await prefs.setString(
              'decision_spinner_picked_movie_poster', _pickedMovie!.posterUrl!);
        }
      } else {
        await prefs.remove('decision_spinner_picked_movie_title');
        await prefs.remove('decision_spinner_picked_movie_poster');
      }
    } catch (_) {}
  }

  /// Reset the excluded history only when the user explicitly triggers it
  Future<void> _resetCurrentHistory() async {
    if (_selectedCategoryIndex == 0 && _pickedMovie != null) {
      if (!kDebugMode) {
        SnackbarHelper.showInfo(
          context,
          'Cannot reset pool while a movie is locked in. Mark it as watched in Movie Diary to unlock.',
        );
        return;
      } else {
        await _forceResetMoviePick();
        return;
      }
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentHistory.clear();
      if (_selectedCategoryIndex == 1) {
        _lastActivityResult = null;
      } else if (_selectedCategoryIndex == 2) {
        _lastFoodResult = null;
      }
      _currentDisplayResult = 'Tap Spin to Decide!';
    });
    await _savePersistentData();

    final coupleId = _getCoupleId();
    if (coupleId.isNotEmpty && _selectedCategoryIndex != 0) {
      final categoryTag = _selectedCategoryIndex == 1
          ? 'active_activity_pick'
          : 'active_food_pick';
      try {
        await SupabaseDataService.client
            .from('decision_ideas')
            .delete()
            .eq('couple_id', coupleId)
            .eq('category', categoryTag);
      } catch (_) {}
    }

    _spinnerChannel?.sendBroadcastMessage(
      event: 'reset_pool',
      payload: {
        'categoryIndex': _selectedCategoryIndex,
      },
    );

    if (mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Pool reset! All options are ready to spin again.',
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

          _isMoviesLoading = false; // Stream delivered — stop loading indicator

          // If a movie was active, check if it was marked as watched
          if (_pickedMovie != null) {
            final matched = unWatched.where(
              (m) =>
                  (m.id != null && m.id == _pickedMovie!.id) ||
                  m.title.trim().toLowerCase() ==
                      _pickedMovie!.title.trim().toLowerCase(),
            ).toList();

            if (matched.isEmpty) {
              final isWatchedInDb = movies.any(
                (m) =>
                    ((m.id != null && m.id == _pickedMovie!.id) ||
                        m.title.trim().toLowerCase() ==
                            _pickedMovie!.title.trim().toLowerCase()) &&
                    (m.isWatched ||
                        m.status.toLowerCase() == 'watched' ||
                        m.status.toLowerCase() == 'already watched'),
              );

              if (isWatchedInDb) {
                // Movie was marked watched or removed! Clear the pick!
                _clearActiveMoviePickInDb();
                _spinnerChannel?.sendBroadcastMessage(
                  event: 'reset_spinner',
                  payload: {},
                );
              }
            } else {
              _pickedMovie = matched.first;
            }
          }
        });
      },
      onError: (e) {
        debugPrint('Error streaming Movie Diary in spinner: $e');
      },
    );
  }

  /// Helper to check and set active picked movie
  void _checkAndSetPickedMovie(
    String title, {
    String? posterUrl,
    String? mediaType,
    int watchCount = 1,
    String? movieId,
  }) {
    if (title.trim().isEmpty) return;

    MovieModel? found;
    try {
      found = _watchMovies.firstWhere(
        (m) => m.title.trim().toLowerCase() == title.trim().toLowerCase(),
      );
    } catch (_) {}

    if (found != null && found.isWatched && !found.isWatchlist) {
      _clearActiveMoviePickInDb();
      return;
    }

    if (found != null) {
      if (watchCount > found.watchCount) {
        found = MovieModel(
          id: found.id ?? movieId,
          coupleId: found.coupleId,
          title: found.title,
          posterUrl: found.posterUrl ?? posterUrl,
          status: found.status,
          mediaType: found.mediaType,
          watchCount: watchCount,
          createdAt: found.createdAt,
          watchedDate: found.watchedDate,
          ratings: found.ratings,
        );
      }
    } else {
      found = MovieModel(
        id: movieId,
        coupleId: _getCoupleId(),
        title: title,
        posterUrl: posterUrl,
        status: 'watchlist',
        mediaType: mediaType ?? 'movie',
        watchCount: watchCount,
        createdAt: DateTime.now(),
      );
    }

    if (mounted) {
      setState(() {
        _pickedMovie = found;
        if (found != null) {
          _currentDisplayResult = found.title;
          if (!_watchHistory.contains(found.title)) {
            _watchHistory.add(found.title);
          }
        }
      });
      _savePersistentData();
    }
  }

  /// Remove active movie pick from Supabase database
  Future<void> _clearActiveMoviePickInDb() async {
    final coupleId = _getCoupleId();
    if (coupleId.isNotEmpty) {
      try {
        await SupabaseDataService.client
            .from('decision_ideas')
            .delete()
            .eq('category', 'active_movie_pick')
            .eq('couple_id', coupleId);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _pickedMovie = null;
        _watchHistory.clear();
      });
      _savePersistentData();
    }
  }

  /// Force Reset Movie Pick (Debug Mode Only)
  Future<void> _forceResetMoviePick() async {
    HapticFeedback.heavyImpact();
    await _clearActiveMoviePickInDb();

    _spinnerChannel?.sendBroadcastMessage(
      event: 'reset_spinner',
      payload: {},
    );

    if (mounted) {
      setState(() {
        _pickedMovie = null;
        _watchHistory.clear();
        _currentDisplayResult = 'Tap Spin to Decide!';
      });
      SnackbarHelper.showSuccess(
        context,
        'Debug: Spinner pool and picked movie reset successfully.',
      );
    }
  }

  /// Debug: Pick & Lock a specific movie directly to test real-time lock & watch reset
  void _showDebugPickMovieDialog(BuildContext context) {
    if (_watchMovies.isEmpty) {
      SnackbarHelper.showInfo(context, 'No unwatched movies in Movie Diary.');
      return;
    }
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bug_report_rounded, color: Colors.amberAccent),
                    SizedBox(width: 8),
                    Text(
                      'Debug: Pick & Lock Movie',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap any movie to instantly lock it on screen for testing:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _watchMovies.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final movie = _watchMovies[idx];
                      return ListTile(
                        leading: movie.posterUrl != null &&
                                movie.posterUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: MoviePosterWidget(
                                  posterUrl: movie.posterUrl,
                                  width: 35,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.movie_rounded,
                                color: Color(0xFFFF758C)),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                movie.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            if (movie.isRewatch) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF758C),
                                      Color(0xFFA18CD1)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  movie.rewatchBadgeLabel,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          movie.mediaType == 'series' ||
                                  movie.mediaType == 'tv'
                              ? 'TV Series'
                              : 'Movie',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: Colors.amberAccent,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _finalizeDecision(
                            movie.title,
                            posterUrl: movie.posterUrl,
                            mediaType: movie.mediaType,
                            watchCount: movie.watchCount,
                            movieId: movie.id,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Fetch user custom ideas from Supabase and merge with local SharedPreferences cache
  Future<void> _fetchOnlineSyncedData() async {
    try {
      final coupleId = _getCoupleId();

      final customFood = <String>[..._foodOptions];
      final customActivities = <String>[..._activityOptions];
      String? activeMovieTitle;
      String? activeActivityTitle;
      String? activeFoodTitle;

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

          if (category == 'active_movie_pick' && title.isNotEmpty) {
            activeMovieTitle = title;
            continue;
          }
          if (category == 'active_activity_pick' && title.isNotEmpty) {
            activeActivityTitle = title;
            continue;
          }
          if (category == 'active_food_pick' && title.isNotEmpty) {
            activeFoodTitle = title;
            continue;
          }

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

          if (activeActivityTitle != null && activeActivityTitle.isNotEmpty) {
            _lastActivityResult = activeActivityTitle;
          }
          if (activeFoodTitle != null && activeFoodTitle.isNotEmpty) {
            _lastFoodResult = activeFoodTitle;
          }

          if (_selectedCategoryIndex == 0) {
            _currentDisplayResult =
                _pickedMovie?.title ?? 'Tap Spin to Decide!';
          } else if (_selectedCategoryIndex == 1) {
            _currentDisplayResult =
                _lastActivityResult ?? 'Tap Spin to Decide!';
          } else if (_selectedCategoryIndex == 2) {
            _currentDisplayResult =
                _lastFoodResult ?? 'Tap Spin to Decide!';
          }
        });

        if (activeMovieTitle != null && activeMovieTitle.isNotEmpty) {
          _checkAndSetPickedMovie(activeMovieTitle);
        }

        _savePersistentData();
      }

      // Fetch movies directly from couple's Watchlist in Movie Diary
      if (coupleId.isNotEmpty) {
        final movies = await _movieService.fetchMovies(coupleId);
        if (movies.isNotEmpty && mounted) {
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
            _watchOptions
                .addAll(unWatched.map((m) => m.title.trim()).toList());
          });

          final titleToSync = activeMovieTitle ?? _pickedMovie?.title;
          if (titleToSync != null && titleToSync.isNotEmpty) {
            _checkAndSetPickedMovie(titleToSync);
          }

          _savePersistentData();
        }
      }
    } catch (_) {}
  }

  /// Weighted winner selection algorithm:
  /// - If 0 (Movie Watchlist): uniform distribution from watch options
  /// - If custom options exist: 80% chance to pick custom option, 20% to fetch online Filipino suggestion.
  /// - If 0 custom options: 100% online dynamic Filipino suggestion.
  String _pickWinner() {
    if (_selectedCategoryIndex == 0) {
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

    final onlinePool = (_selectedCategoryIndex == 2
            ? _onlineFilipinoFood
            : _onlineFilipinoActivities)
        .where((item) => !_currentHistory.contains(item))
        .toList();

    final activeOnlineList = onlinePool.isNotEmpty
        ? onlinePool
        : (_selectedCategoryIndex == 2
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

    if (_selectedCategoryIndex == 0) {
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
    if (_selectedCategoryIndex == 0) {
      if (_pickedMovie != null) {
        HapticFeedback.vibrate();
        SnackbarHelper.showInfo(
          context,
          'Movie is already locked in! Mark it as watched in Movie Diary to unlock the wheel.',
        );
        return;
      }
      if (_watchOptions.length < 2) {
        HapticFeedback.vibrate();
        SnackbarHelper.showError(
          context,
          'Please add at least 2 unwatched movies in Movie Diary to spin!',
        );
        return;
      }
    }

    if (_spinnerModeIndex == 0) {
      _startVisualWheelSpin();
    } else {
      _startQuickSlotSpin();
    }
  }

  /// Interactive Visual Wheel Physics Spin on the merged wheel
  void _startVisualWheelSpin({
    bool fromRemote = false,
    String? remoteWinner,
    int? remoteTargetSliceIndex,
    int? remoteExtraTurns,
    String? remotePosterUrl,
    String? remoteMediaType,
    int? remoteWatchCount,
    String? remoteMovieId,
  }) {
    final slices = _wheelDisplaySlices;
    if (slices.isEmpty) return;

    final String finalWinner;
    final int targetSliceIndex;
    final int extraTurns;
    String? finalPosterUrl = remotePosterUrl;
    String? finalMediaType = remoteMediaType;
    int finalWatchCount = remoteWatchCount ?? 1;
    String? finalMovieId = remoteMovieId;

    if (!fromRemote) {
      final decision = _pickWinnerWithTarget();
      finalWinner = decision.winner;
      targetSliceIndex = decision.targetSliceIndex;
      extraTurns = 5 + _random.nextInt(3); // 5 to 7 full rotations

      if (_selectedCategoryIndex == 0) {
        try {
          final m = _watchMovies.firstWhere(
            (item) => item.title.trim().toLowerCase() == finalWinner.trim().toLowerCase(),
          );
          finalPosterUrl = m.posterUrl;
          finalMediaType = m.mediaType;
          finalWatchCount = m.watchCount;
          finalMovieId = m.id;
        } catch (_) {}
      }

      final myUserId =
          Provider.of<UserProvider>(context, listen: false).user?.uid;
      _spinnerChannel?.sendBroadcastMessage(
        event: 'spin_start',
        payload: {
          'categoryIndex': _selectedCategoryIndex,
          'modeIndex': 0,
          'userId': myUserId,
          'winner': finalWinner,
          'targetSliceIndex': targetSliceIndex,
          'extraTurns': extraTurns,
          'posterUrl': finalPosterUrl,
          'mediaType': finalMediaType ?? 'movie',
          'watchCount': finalWatchCount,
          'movieId': finalMovieId,
        },
      );
    } else {
      finalWinner = remoteWinner ?? _pickWinner();
      if (remoteTargetSliceIndex != null &&
          remoteTargetSliceIndex >= 0 &&
          remoteTargetSliceIndex < slices.length) {
        targetSliceIndex = remoteTargetSliceIndex;
      } else {
        final idx = slices.indexWhere(
            (s) => s.label.trim().toLowerCase() == finalWinner.trim().toLowerCase());
        targetSliceIndex = idx >= 0 ? idx : 0;
      }
      extraTurns = remoteExtraTurns ?? 5;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSpinning = true;
    });

    final sliceCount = slices.length;
    final sliceAngle = (2 * pi) / sliceCount;
    // Dead-center of the target slice in unrotated local coordinates
    final targetWedgeLocalCenter =
        (targetSliceIndex + 0.5) * sliceAngle;

    // Pointer is aligned at top 12 o'clock axis (-pi / 2)
    final targetNormalizedAngle =
        (-pi / 2 - targetWedgeLocalCenter) % (2 * pi);

    final currentNormalized = _currentWheelAngle % (2 * pi);
    double diff = targetNormalizedAngle - currentNormalized;
    if (diff < 0) diff += 2 * pi;

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
        _pointerKey.currentState?.triggerFlick();
      }
    }

    _wheelController.removeListener(tickListener);
    _wheelController.addListener(tickListener);

    _wheelController.reset();
    _wheelController.forward().then((_) {
      _wheelController.removeListener(tickListener);
      _currentWheelAngle = finalTargetAngle;
      _finalizeDecision(
        finalWinner,
        fromRemote: fromRemote,
        posterUrl: finalPosterUrl,
        mediaType: finalMediaType,
        watchCount: finalWatchCount,
        movieId: finalMovieId,
      );
    });
  }

  /// Quick Slot-Machine Carousel Spin
  void _startQuickSlotSpin({
    bool fromRemote = false,
    String? remoteWinner,
    String? remotePosterUrl,
    String? remoteMediaType,
    int? remoteWatchCount,
    String? remoteMovieId,
  }) {
    final displayPool = _selectedCategoryIndex == 0
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

    final String finalWinner;
    String? finalPosterUrl = remotePosterUrl;
    String? finalMediaType = remoteMediaType;
    int finalWatchCount = remoteWatchCount ?? 1;
    String? finalMovieId = remoteMovieId;

    if (!fromRemote) {
      finalWinner = _pickWinner();
      if (_selectedCategoryIndex == 0) {
        try {
          final m = _watchMovies.firstWhere(
            (item) => item.title.trim().toLowerCase() == finalWinner.trim().toLowerCase(),
          );
          finalPosterUrl = m.posterUrl;
          finalMediaType = m.mediaType;
          finalWatchCount = m.watchCount;
          finalMovieId = m.id;
        } catch (_) {}
      }

      final myUserId =
          Provider.of<UserProvider>(context, listen: false).user?.uid;
      _spinnerChannel?.sendBroadcastMessage(
        event: 'spin_start',
        payload: {
          'categoryIndex': _selectedCategoryIndex,
          'modeIndex': 1,
          'userId': myUserId,
          'winner': finalWinner,
          'posterUrl': finalPosterUrl,
          'mediaType': finalMediaType ?? 'movie',
          'watchCount': finalWatchCount,
          'movieId': finalMovieId,
        },
      );
    } else {
      finalWinner = remoteWinner ?? _pickWinner();
    }

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
        _finalizeDecision(
          finalWinner,
          fromRemote: fromRemote,
          posterUrl: finalPosterUrl,
          mediaType: finalMediaType,
          watchCount: finalWatchCount,
          movieId: finalMovieId,
        );
      }
    });
  }

  void _finalizeDecision(
    String winner, {
    bool fromRemote = false,
    String? posterUrl,
    String? mediaType,
    int watchCount = 1,
    String? movieId,
  }) {
    HapticFeedback.heavyImpact();

    MovieModel? winningMovie;
    if (_selectedCategoryIndex == 0) {
      try {
        winningMovie = _watchMovies.firstWhere(
          (m) => m.title.trim().toLowerCase() == winner.trim().toLowerCase(),
        );
      } catch (_) {}

      if (winningMovie != null) {
        if (watchCount > winningMovie.watchCount) {
          winningMovie = MovieModel(
            id: winningMovie.id ?? movieId,
            coupleId: winningMovie.coupleId,
            title: winningMovie.title,
            posterUrl: winningMovie.posterUrl ?? posterUrl,
            status: winningMovie.status,
            mediaType: winningMovie.mediaType,
            watchCount: watchCount,
            createdAt: winningMovie.createdAt,
            watchedDate: winningMovie.watchedDate,
            ratings: winningMovie.ratings,
          );
        }
      } else {
        winningMovie = MovieModel(
          id: movieId,
          coupleId: _getCoupleId(),
          title: winner,
          posterUrl: posterUrl,
          status: 'watchlist',
          mediaType: mediaType ?? 'movie',
          watchCount: watchCount,
          createdAt: DateTime.now(),
        );
      }
    }

    setState(() {
      _isSpinning = false;
      _currentDisplayResult = winner;
      if (_selectedCategoryIndex == 0) {
        if (!_watchHistory.contains(winner)) {
          _watchHistory.add(winner);
        }
        _pickedMovie = winningMovie;
      } else if (_selectedCategoryIndex == 1) {
        _lastActivityResult = winner;
        if (!_activityHistory.contains(winner)) {
          _activityHistory.add(winner);
        }
      } else {
        _lastFoodResult = winner;
        if (!_foodHistory.contains(winner)) {
          _foodHistory.add(winner);
        }
      }
    });

    _savePersistentData();

    if (!fromRemote) {
      final myUserId =
          Provider.of<UserProvider>(context, listen: false).user?.uid;
      _spinnerChannel?.sendBroadcastMessage(
        event: 'decision_made',
        payload: {
          'categoryIndex': _selectedCategoryIndex,
          'winner': winner,
          'posterUrl': winningMovie?.posterUrl,
          'mediaType': winningMovie?.mediaType ?? 'movie',
          'watchCount': winningMovie?.watchCount ?? 1,
          'movieId': winningMovie?.id,
          'userId': myUserId,
        },
      );

      // Persist active pick in Supabase so partner sees it locked on screen immediately
      final coupleId = _getCoupleId();
      if (coupleId.isNotEmpty) {
        final categoryTag = _selectedCategoryIndex == 0
            ? 'active_movie_pick'
            : (_selectedCategoryIndex == 1
                ? 'active_activity_pick'
                : 'active_food_pick');

        SupabaseDataService.client
            .from('decision_ideas')
            .delete()
            .eq('couple_id', coupleId)
            .eq('category', categoryTag)
            .then((_) {
          SupabaseDataService.client.from('decision_ideas').insert({
            'couple_id': coupleId,
            'category': categoryTag,
            'title': winner,
            'is_custom': false,
          }).catchError((e) {
            debugPrint('Error saving active pick: $e');
          });
        }).catchError((_) {});
      }
    }

    // Auto-show winner on screen for all categories without blocking popups!
  }

  /// Add custom option and sync it online directly to Supabase & SharedPreferences
  void _showAddCustomOptionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Add Custom ${_selectedCategoryIndex == 2 ? "Food & Drink" : "Date & Activity"}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: AppTextField(
          controller: controller,
          autofocus: true,
          hintText: _selectedCategoryIndex == 2
              ? 'e.g. Samgyupsal, Crispy Sisig, Milk Tea...'
              : 'e.g. Sunset in Manila Bay, Arcade Night...',
          borderRadius: BorderRadius.circular(14),
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
    final category = _selectedCategoryIndex == 2 ? 'food' : 'activity';

    setState(() {
      if (_selectedCategoryIndex == 2) {
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

      _spinnerChannel?.sendBroadcastMessage(
        event: 'pool_updated',
        payload: {
          'category': category,
          'title': text,
        },
      );
    } catch (_) {}
  }

  /// Delete option from list, local cache (SharedPreferences), and online Supabase database
  Future<void> _removeOption(String option) async {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedCategoryIndex == 0) {
        _watchOptions.remove(option);
        _watchMovies.removeWhere((m) => m.title.trim() == option.trim());
      } else if (_selectedCategoryIndex == 1) {
        _activityOptions.remove(option);
      } else {
        _foodOptions.remove(option);
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

      _spinnerChannel?.sendBroadcastMessage(
        event: 'pool_updated',
        payload: {
          'removed': option,
        },
      );
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
        child: !_isInitialized
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFFF758C),
                ),
              )
            : SingleChildScrollView(
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

              // Categories Header Chips (0: Movie Watchlist, 1: Dates & Activities, 2: Food & Drinks)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryBadge(
                      index: 0,
                      label: 'Movie Watchlist',
                      icon: Icons.movie_filter_rounded,
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
                      label: 'Food & Drinks',
                      icon: Icons.restaurant_rounded,
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
                child: _buildMainSpinnerContent(context, isDark),
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
                child: _selectedCategoryIndex == 0 && _isMoviesLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF758C),
                          ),
                        ),
                      )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedCategoryIndex == 0
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
                            if (_selectedCategoryIndex != 0) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.cloud_done_rounded,
                                size: 15,
                                color: Color(0xFFFF758C),
                              ),
                            ],
                          ],
                        ),
                        if (_selectedCategoryIndex != 0)
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
                    if (_currentHistory.isNotEmpty ||
                        (_selectedCategoryIndex == 0 &&
                            _pickedMovie != null)) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF2B1D3A),
                                    const Color(0xFF1E1528)
                                  ]
                                : [
                                    const Color(0xFFFFEBF0),
                                    const Color(0xFFF5EBF8)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF758C)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _selectedCategoryIndex == 0 &&
                                        _pickedMovie != null
                                    ? Icons.movie_rounded
                                    : Icons.history_rounded,
                                size: 16,
                                color: const Color(0xFFFF758C),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedCategoryIndex == 0 &&
                                            _pickedMovie != null
                                        ? 'Tonight\'s Pick: ${_pickedMovie!.title}'
                                        : 'Anti-Repeat Exclusion Pool',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.deepCharcoal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedCategoryIndex != 0)
                                    Text(
                                      '${_currentHistory.length} recently picked items temporarily excluded',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_selectedCategoryIndex == 0 &&
                                _pickedMovie != null) ...[
                              if (kDebugMode)
                                TextButton.icon(
                                  onPressed: _forceResetMoviePick,
                                  icon: const Icon(Icons.restart_alt_rounded,
                                      size: 14),
                                  label: const Text('Reset (Debug)'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Colors.amberAccent.shade400,
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
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_rounded,
                                        size: 12, color: Color(0xFFFF758C)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Locked',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade500,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                            ] else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF758C),
                                      Color(0xFFA18CD1)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF758C)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _resetCurrentHistory,
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 13, color: Colors.white),
                                  label: const Text(
                                    'Reset Pool',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                  ? Icons.movie_outlined
                                  : _selectedCategoryIndex == 1
                                      ? Icons.local_activity_outlined
                                      : Icons.restaurant_outlined,
                              size: 38,
                              color: const Color(0xFFFF758C)
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedCategoryIndex == 0
                                  ? 'No unwatched movies in Watchlist'
                                  : _selectedCategoryIndex == 1
                                      ? 'No custom activity options added'
                                      : 'No custom food options added',
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
                              _selectedCategoryIndex != 0
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
                            if (_selectedCategoryIndex != 0)
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
                    else if (_selectedCategoryIndex == 0 &&
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

  /// Winner Decision Celebration Card for Dates & Activities and Food & Drinks
  Widget _buildDecisionResultCard(BuildContext context, bool isDark) {
    if (_selectedCategoryIndex == 0) return const SizedBox.shrink();
    if (_currentDisplayResult == 'Tap Spin to Decide!' ||
        _currentDisplayResult == 'Spinning...' ||
        _currentDisplayResult.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final isCustomIdea = _currentOptions.contains(_currentDisplayResult);

    final categoryLabel = _selectedCategoryIndex == 1
        ? 'DATE & ACTIVITY PICKED'
        : 'FOOD & DRINKS CHOICE';

    final originLabel =
        isCustomIdea ? 'Couple Idea ⭐' : 'Online Suggestion 🌐';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF2E1C38),
                  const Color(0xFF1B1124),
                ]
              : [
                  const Color(0xFFFFF0F5),
                  const Color(0xFFF7ECFA),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF758C).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Glowing Header Badge & Origin Tag (Responsive Wrap)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      categoryLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              // Origin Tag
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  originLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. Winner Text in Big Romantic Typography
          Text(
            _currentDisplayResult,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Main Spinner Card Content (Renders Locked Movie Centerpiece for Movies, or Visual Wheel / Slot Machine for Other Tabs)
  Widget _buildMainSpinnerContent(BuildContext context, bool isDark) {
    if (_selectedCategoryIndex == 0 && _pickedMovie != null) {
      return _buildPickedMovieView(context, isDark);
    }

    return Column(
      children: [
        // Online Connection Indicator Badge
        if (_selectedCategoryIndex != 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF758C).withValues(alpha: 0.25),
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

        // Winner Decision Celebration Card for Dates & Food
        _buildDecisionResultCard(context, isDark),

        const SizedBox(height: 16),

        // Spin Button
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: _isSpinning ||
                    (_selectedCategoryIndex == 0 &&
                        _watchOptions.length < 2)
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _isSpinning ||
                    (_selectedCategoryIndex == 0 &&
                        _watchOptions.length < 2)
                ? (isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300)
                : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isSpinning ||
                    (_selectedCategoryIndex == 0 &&
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
              disabledForegroundColor:
                  isDark ? Colors.grey.shade500 : Colors.grey.shade600,
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
                  : (_currentDisplayResult != 'Tap Spin to Decide!' &&
                          _currentDisplayResult.isNotEmpty
                      ? 'Re-Spin Wheel'
                      : 'Spin Wheel'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (kDebugMode &&
            _selectedCategoryIndex == 0 &&
            _watchMovies.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDebugPickMovieDialog(context),
              icon: const Icon(Icons.touch_app_rounded, size: 16),
              label: const Text(
                'Debug: Pick & Lock Movie for Testing',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amberAccent.shade400,
                side: BorderSide(
                  color: Colors.amberAccent.shade400.withValues(alpha: 0.7),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Redesigned Centerpiece View when a Movie is Picked
  Widget _buildPickedMovieView(BuildContext context, bool isDark) {
    if (_pickedMovie == null) return const SizedBox.shrink();

    final movie = _pickedMovie!;

    return Column(
      children: [
        // 1. Romantic Glowing Pill Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'DATE NIGHT MOVIE LOCKED IN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.movie_filter_rounded, color: Colors.white, size: 14),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. Cinematic Glowing Poster Showcase
        Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Aura Glow behind poster
            Container(
              width: 140,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFFA18CD1).withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
            ),

            // Actual Poster Container
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.8),
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: movie.posterUrl != null && movie.posterUrl!.isNotEmpty
                    ? MoviePosterWidget(
                        posterUrl: movie.posterUrl,
                        width: 135,
                        height: 195,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 135,
                        height: 195,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF2E1C38),
                                    const Color(0xFF1B1124)
                                  ]
                                : [
                                    const Color(0xFFFFE4E8),
                                    const Color(0xFFF3E7F7)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.movie_creation_rounded,
                            size: 48,
                            color: Color(0xFFFF758C),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Movie Title & Tags
        Text(
          movie.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepCharcoal,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    movie.mediaType == 'series' || movie.mediaType == 'tv'
                        ? Icons.tv_rounded
                        : Icons.movie_rounded,
                    size: 11,
                    color: const Color(0xFFFF758C),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    movie.mediaType == 'series' || movie.mediaType == 'tv'
                        ? 'TV Series'
                        : 'Movie',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                    ),
                  ),
                ],
              ),
            ),
            if (movie.isRewatch) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  movie.rewatchBadgeLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // Romantic Narrative
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'The Decision Wheel chose this for tonight\'s date night! Grab the popcorn, snuggle up with your love, and enjoy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Primary Action: Open Movie Diary to Mark as Watched
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MovieTrackerScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
            label: const Text(
              'Open in Movie Diary & Rate',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Notice: Pool is locked until watched
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 14,
                color: Color(0xFFFF758C),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wheel is locked until marked as watched in Movie Diary.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Debug Force Reset Button (Debug Mode Only)
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _forceResetMoviePick,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text(
                'Force Reset Spinner (Debug Mode)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amberAccent.shade400,
                side: BorderSide(
                  color: Colors.amberAccent.shade400.withValues(alpha: 0.7),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ],
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

              // Ultra-Visible Precision Needle Flapper / Picker Pointer with Flick Animation
              Positioned(
                top: -14,
                child: _WheelPointerWidget(
                  key: _pointerKey,
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
    if (_selectedCategoryIndex == 0 && _watchMovies.isNotEmpty) {
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
          if (index == 0) {
            _currentDisplayResult =
                _pickedMovie?.title ?? 'Tap Spin to Decide!';
          } else if (index == 1) {
            _currentDisplayResult =
                _lastActivityResult ?? 'Tap Spin to Decide!';
          } else if (index == 2) {
            _currentDisplayResult = _lastFoodResult ?? 'Tap Spin to Decide!';
          }
        });
        _savePersistentData();
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

/// Precision Flapper / Pointer Widget with Dynamic Flick Physics
class _WheelPointerWidget extends StatefulWidget {
  const _WheelPointerWidget({super.key});

  @override
  State<_WheelPointerWidget> createState() => _WheelPointerWidgetState();
}

class _WheelPointerWidgetState extends State<_WheelPointerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flickController;
  late Animation<double> _flickAnimation;

  @override
  void initState() {
    super.initState();
    _flickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _flickAnimation = Tween<double>(begin: 0.0, end: -0.16).chain(
      CurveTween(curve: Curves.easeOutBack),
    ).animate(_flickController);
  }

  void triggerFlick() {
    if (!mounted) return;
    _flickController.forward(from: 0.0).then((_) {
      if (mounted) _flickController.reverse();
    });
  }

  @override
  void dispose() {
    _flickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flickAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _flickAnimation.value,
          alignment: const Alignment(0, -0.6),
          child: CustomPaint(
            size: const Size(36, 46),
            painter: _WheelPointerPainter(),
          ),
        );
      },
    );
  }
}

/// Custom Painter for the Ultra-Visible Radiant Golden Needle Pointer / Flapper
class _WheelPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Multi-layered Deep Drop Shadow Path
    final shadowPath = Path()
      ..moveTo(w / 2, h) // Razor Tip
      ..lineTo(w * 0.88, h * 0.28)
      ..arcToPoint(
        Offset(w * 0.12, h * 0.28),
        radius: Radius.circular(w * 0.38),
      )
      ..close();

    canvas.drawShadow(shadowPath, Colors.black, 8.0, true);

    // Needle Outer Body
    final bodyPath = Path()
      ..moveTo(w / 2, h) // Precision Razor Needle Tip
      ..lineTo(w * 0.86, h * 0.30)
      ..arcToPoint(
        Offset(w * 0.14, h * 0.30),
        radius: Radius.circular(w * 0.36),
      )
      ..close();

    // 24K Radiant Gold Gradient
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFF9C4), // Gleaming Light Gold
          Color(0xFFFFD700), // Pure Gold
          Color(0xFFFF9800), // Rich Amber
          Color(0xFFFF3D00), // Vivid Sunset Red Accent at tip
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(bodyPath, bodyPaint);

    // Thick crisp white border for maximum contrast against any wheel slice
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bodyPath, borderPaint);

    // Center Ridge Specular Highlight Line
    final ridgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(w / 2, h * 0.24), Offset(w / 2, h - 2), ridgePaint);

    // Top Metallic Rivet Bearing / Ruby Center
    final pivotCenter = Offset(w / 2, h * 0.24);
    final pivotOuterPaint = Paint()..color = Colors.white;
    canvas.drawCircle(pivotCenter, 7.5, pivotOuterPaint);

    final pivotInnerPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFF5252), Color(0xFFD50000), Color(0xFF880E4F)],
        stops: [0.2, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: pivotCenter, radius: 5.2));
    canvas.drawCircle(pivotCenter, 5.2, pivotInnerPaint);

    final highlightPaint =
        Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(
        Offset(pivotCenter.dx - 1.5, pivotCenter.dy - 1.5), 1.6, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Painter for the Sleek Decision Wheel
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
      final midAngle = startAngle + sweepAngle / 2;

      final slicePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment(cos(midAngle), sin(midAngle)),
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
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.6
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
            fontSize: count > 8 ? 10.0 : 11.5,
            fontWeight: FontWeight.w900,
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
            color: Colors.white.withValues(alpha: 0.92),
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
  bool shouldRepaint(covariant _DecisionWheelPainter oldDelegate) => true;
}
