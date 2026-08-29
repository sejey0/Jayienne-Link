import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_data_service.dart';
import '../../../services/supabase_movie_service.dart';
import '../../movies/screens/movie_tracker_screen.dart';

/// Date, Food & Movie Decision Spinner Screen with Interactive Visual Wheel, Watchlist Integration & Anti-Duplicate Guarantee
class DecisionSpinnerScreen extends StatefulWidget {
  const DecisionSpinnerScreen({super.key});

  @override
  State<DecisionSpinnerScreen> createState() => _DecisionSpinnerScreenState();
}

class _DecisionSpinnerScreenState extends State<DecisionSpinnerScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  final SupabaseMovieService _movieService = SupabaseMovieService();

  int _selectedCategoryIndex = 0; // 0: Filipino Food, 1: Date Activities, 2: Movie Watchlist
  int _spinnerModeIndex = 0; // 0: Spin Wheel, 1: Quick Roulette
  bool _isSpinning = false;
  bool _isLoadingOnline = false;
  String _currentDisplayResult = 'Tap Spin to Decide!';

  // Wheel Physics Animation
  late AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  double _currentWheelAngle = 0.0;
  Timer? _quickSlotTimer;

  // History tracking to prevent duplicates / repeating results
  final List<String> _foodHistory = [];
  final List<String> _activityHistory = [];
  final List<String> _watchHistory = [];

  // Authentic Filipino Food Favorites
  final List<String> _foodOptions = [
    'Sinigang na Baboy',
    'Crispy Pork Sisig',
    'Beef Pares & Mami',
    'Chicken & Pork Adobo',
    'Kare-Kare with Bagoong',
    'Chicken Inasal with Garlic Rice',
    'Lechon Kawali & Mang Tomas',
    'Hot Beef Bulalo Soup',
    'Spicy Bicol Express',
    'Jollibee Chickenjoy Feast',
    'Samgyupsal / Unlimited K-BBQ',
    'Halo-Halo & Ice Cream Date',
    'Street Food Night (Kwek-Kwek & Isaw)',
  ];

  // Dynamic Couple Dates & Activities (starts empty or fetched online/custom)
  final List<String> _activityOptions = [];

  // Online curated suggestions pack for date activities
  static const List<String> _curatedDateActivities = [
    'Cinema Movie Night & Popcorn',
    'Sunset Walk in the Park',
    'Videoke & Karaoke Singing',
    'Arcade & Basketball Shootout',
    'Night Drive & Convenience Store',
    'Park Picnic & Photo Shoot',
    'Night Market Food Park Trip',
    'Coffee Shop & Board Games',
    'Co-op Mobile Gaming Session',
    'Supermarket & Grocery Date',
    'Bowling & Billiards Match',
    'Cook a New Recipe Together',
  ];

  // Movies & Series (Synced with Movie Diary Watchlist)
  final List<String> _watchOptions = [
    'Romantic Comedy Movie',
    'K-Drama Series Marathon',
    'Studio Ghibli Animated Film',
    'Psychological Thriller',
    'Horror Movie & Blanket Night',
    'Sci-Fi Adventure Film',
    'Nostalgic Childhood Classic',
    'Action Comedy Movie',
  ];

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
      _fetchOnlineIdeas();
    });
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _quickSlotTimer?.cancel();
    super.dispose();
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

  /// Connect to Supabase to fetch dynamic date ideas and Movie Diary Watchlist
  Future<void> _fetchOnlineIdeas() async {
    setState(() => _isLoadingOnline = true);
    try {
      // 1. Fetch from decision_ideas table if available
      final response = await SupabaseDataService.client
          .from('decision_ideas')
          .select()
          .limit(30);

      final records = List<Map<String, dynamic>>.from(response);

      final onlineFood = <String>[];
      final onlineActivities = <String>[];

      if (records.isNotEmpty) {
        for (final row in records) {
          final category = row['category']?.toString().toLowerCase() ?? '';
          final title = row['title']?.toString() ?? '';
          if (title.isNotEmpty) {
            if (category == 'food' && !_foodOptions.contains(title)) {
              onlineFood.add(title);
            } else if (category == 'activity' &&
                !_activityOptions.contains(title)) {
              onlineActivities.add(title);
            }
          }
        }
      }

      // If online activities are empty, load curated suggestions pack
      if (onlineActivities.isEmpty && _activityOptions.isEmpty) {
        onlineActivities.addAll(_curatedDateActivities);
      }

      if (mounted) {
        setState(() {
          _foodOptions.addAll(onlineFood);
          for (final act in onlineActivities) {
            if (!_activityOptions.contains(act)) {
              _activityOptions.add(act);
            }
          }
        });
      }

      // 2. Fetch movies directly from couple's Watchlist in Movie Diary (EXCLUDING watched movies)
      final coupleId = _getCoupleId();
      if (coupleId.isNotEmpty) {
        final movies = await _movieService.fetchMovies(coupleId);
        if (movies.isNotEmpty) {
          final unWatchedTitles = movies
              .where((m) =>
                  !m.isWatched &&
                  m.status.toLowerCase() != 'watched' &&
                  m.status.toLowerCase() != 'already watched')
              .map((m) => m.title.trim())
              .where((t) => t.isNotEmpty)
              .toList();

          if (unWatchedTitles.isNotEmpty && mounted) {
            setState(() {
              _watchOptions.clear();
              _watchOptions.addAll(unWatchedTitles);
            });
          }
        }
      }
    } catch (_) {
      // Fallback: If network is offline and activities are empty, load curated activity pack
      if (mounted && _activityOptions.isEmpty) {
        setState(() {
          _activityOptions.addAll(_curatedDateActivities);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOnline = false);
      }
    }
  }

  /// Trigger the appropriate spin mode
  void _onSpinPressed() {
    if (_isSpinning) return;
    if (_currentOptions.length < 2) {
      HapticFeedback.vibrate();
      SnackbarHelper.showError(
        context,
        'Please add or fetch at least 2 options to spin the wheel!',
      );
      return;
    }

    if (_spinnerModeIndex == 0) {
      _startVisualWheelSpin();
    } else {
      _startQuickSlotSpin();
    }
  }

  /// Interactive Visual Wheel Physics Spin
  void _startVisualWheelSpin() {
    final availableOptions = _currentOptions
        .where((item) => !_currentHistory.contains(item))
        .toList();

    final poolToUse =
        availableOptions.isNotEmpty ? availableOptions : _currentOptions;
    if (availableOptions.isEmpty) {
      _currentHistory.clear();
    }

    if (poolToUse.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSpinning = true;
    });

    final winnerIndex = _random.nextInt(poolToUse.length);
    final winner = poolToUse[winnerIndex];

    // Calculate angle alignment for pointer at the top (-pi/2)
    final sliceAngle = (2 * pi) / poolToUse.length;
    final targetWedgeLocalCenter = (winnerIndex + 0.5) * sliceAngle;

    final targetNormalizedAngle =
        (-pi / 2 - targetWedgeLocalCenter) % (2 * pi);

    final currentNormalized = _currentWheelAngle % (2 * pi);
    double diff = targetNormalizedAngle - currentNormalized;
    if (diff < 0) diff += 2 * pi;

    final extraTurns = 5 + _random.nextInt(3); // 5 to 7 full rotations
    final finalTargetAngle = _currentWheelAngle + (2 * pi * extraTurns) + diff;

    final startAngle = _currentWheelAngle;
    final totalDistance = finalTargetAngle - startAngle;

    int lastTickIndex = -1;
    void tickListener() {
      final currentAngle = startAngle + (totalDistance * _wheelAnimation.value);
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
      _finalizeDecision(winner);
    });
  }

  /// Quick Slot-Machine Carousel Spin
  void _startQuickSlotSpin() {
    final availableOptions = _currentOptions
        .where((item) => !_currentHistory.contains(item))
        .toList();

    final poolToUse =
        availableOptions.isNotEmpty ? availableOptions : _currentOptions;
    if (availableOptions.isEmpty) {
      _currentHistory.clear();
    }

    if (poolToUse.isEmpty) return;

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

      final randomIndex = _random.nextInt(poolToUse.length);
      setState(() {
        _currentDisplayResult = poolToUse[randomIndex];
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        final winnerIndex = _random.nextInt(poolToUse.length);
        _finalizeDecision(poolToUse[winnerIndex]);
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    fontSize: 20,
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
              child: Row(
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
            ),
          ],
        );
      },
    );
  }

  /// Dialog to add custom choice for food or activities
  void _showAddCustomOptionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Add Custom ${_getCategoryName(_selectedCategoryIndex)}',
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
            hintText: 'Enter custom option...',
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
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          setState(() {
                            if (_selectedCategoryIndex == 0) {
                              _foodOptions.insert(0, text);
                            } else if (_selectedCategoryIndex == 1) {
                              _activityOptions.insert(0, text);
                            }
                          });
                          Navigator.pop(ctx);
                          SnackbarHelper.showSuccess(
                            context,
                            'Added "$text" to options!',
                          );
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

  void _removeOption(String option) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedCategoryIndex == 0) {
        _foodOptions.remove(option);
      } else if (_selectedCategoryIndex == 1) {
        _activityOptions.remove(option);
      } else {
        _watchOptions.remove(option);
      }
      _currentHistory.remove(option);
    });
    SnackbarHelper.showInfo(context, 'Removed "$option"');
  }

  String _getCategoryName(int index) {
    switch (index) {
      case 0:
        return 'Filipino Food';
      case 1:
        return 'Date Activity';
      default:
        return 'Movie';
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
        actions: [
          IconButton(
            icon: _isLoadingOnline
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Sync Ideas & Watchlist',
            onPressed: _isLoadingOnline ? null : _fetchOnlineIdeas,
          ),
        ],
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

              // Categories Header Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryBadge(
                      index: 0,
                      label: 'Filipino Food',
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
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
                    if (_spinnerModeIndex == 0)
                      // Visual Physical Wheel Mode
                      _buildVisualWheel(context, isDark)
                    else
                      // Slot Machine / Carousel Mode
                      _buildSlotMachineView(context, isDark),
                    const SizedBox(height: 20),

                    // Spin Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: _isSpinning || _currentOptions.length < 2
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFFF758C),
                                  Color(0xFFA18CD1)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isSpinning || _currentOptions.length < 2
                            ? (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300)
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isSpinning || _currentOptions.length < 2
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
                              ? 'Spinning the Wheel...'
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

              // Active Wheel Options List & Reset Excluded Control
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
                        Text(
                          'Options (${_currentOptions.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : AppColors.deepCharcoal,
                          ),
                        ),
                        Row(
                          children: [
                            if (_selectedCategoryIndex == 1)
                              TextButton.icon(
                                onPressed: _isLoadingOnline ? null : _fetchOnlineIdeas,
                                icon: const Icon(Icons.cloud_download_rounded, size: 15),
                                label: const Text('Fetch Ideas'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF758C),
                                  padding: const EdgeInsets.only(right: 8),
                                ),
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
                                  ).then((_) => _fetchOnlineIdeas());
                                },
                                icon: const Icon(Icons.movie_rounded, size: 15),
                                label: const Text('Movie Diary'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF758C),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Reset Excluded Options Banner
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
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _currentHistory.clear();
                                });
                                SnackbarHelper.showSuccess(
                                  context,
                                  'Excluded options reset! All items are ready to spin again.',
                                );
                              },
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

                    // Empty State if no options
                    if (_currentOptions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        child: Column(
                          children: [
                            Icon(
                              _selectedCategoryIndex == 1
                                  ? Icons.local_activity_outlined
                                  : Icons.restaurant_outlined,
                              size: 38,
                              color: const Color(0xFFFF758C)
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedCategoryIndex == 1
                                  ? 'No activity options in wheel'
                                  : 'No food options in wheel',
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
                              'Add your own custom dates or fetch suggestions online.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _showAddCustomOptionDialog,
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Add Custom'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFFFF758C)),
                                    foregroundColor: const Color(0xFFFF758C),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _fetchOnlineIdeas,
                                  icon: const Icon(
                                      Icons.cloud_download_rounded,
                                      size: 16),
                                  label: const Text('Fetch Online'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF758C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                            label: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isPickedRecently
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                color: isPickedRecently
                                    ? (isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500)
                                    : (isDark
                                        ? Colors.white
                                        : AppColors.deepCharcoal),
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
                            onDeleted: _selectedCategoryIndex != 2
                                ? () => _removeOption(opt)
                                : null,
                            backgroundColor: isPickedRecently
                                ? (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade100)
                                : (isDark
                                    ? const Color(0xFFFF758C)
                                        .withValues(alpha: 0.15)
                                    : const Color(0xFFFF758C)
                                        .withValues(alpha: 0.08)),
                            side: BorderSide(
                              color: isPickedRecently
                                  ? Colors.transparent
                                  : const Color(0xFFFF758C)
                                      .withValues(alpha: 0.25),
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

    return Column(
      children: [
        SizedBox(
          width: wheelSize,
          height: wheelSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Spinning Canvas Wheel
              AnimatedBuilder(
                animation: _wheelAnimation,
                builder: (context, child) {
                  final angle = _wheelController.isAnimating
                      ? _currentWheelAngle +
                          ((_wheelController.value) *
                              (2 * pi * 5))
                      : _currentWheelAngle;

                  return CustomPaint(
                    size: const Size(wheelSize, wheelSize),
                    painter: _DecisionWheelPainter(
                      options: _currentOptions,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                  Icons.casino_rounded,
                  color: Colors.white,
                  size: 24,
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
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            child: Text(
              _currentDisplayResult,
              key: ValueKey<String>(_currentDisplayResult),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.deepCharcoal,
                fontWeight: FontWeight.w900,
                fontSize: 20,
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

/// Custom Painter for the Interactive Visual Decision Wheel
class _DecisionWheelPainter extends CustomPainter {
  final List<String> options;
  final double angle;
  final bool isDark;

  _DecisionWheelPainter({
    required this.options,
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

    if (options.isEmpty) {
      final paint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade200
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);

      final rimPaint = Paint()
        ..color = const Color(0xFFFF758C).withValues(alpha: 0.35)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius, rimPaint);

      final textSpan = TextSpan(
        text: 'Add Options to Spin',
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(
          canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      return;
    }

    final sliceAngle = (2 * pi) / options.length;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Draw Slices
    for (int i = 0; i < options.length; i++) {
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

      // Text along radial slice
      canvas.save();
      final textAngle = startAngle + sweepAngle / 2;
      canvas.rotate(textAngle);

      final label = options[i];
      final maxChars = options.length > 8 ? 12 : 16;
      final displayLabel = label.length > maxChars
          ? '${label.substring(0, maxChars)}...'
          : label;

      final textSpan = TextSpan(
        text: displayLabel,
        style: TextStyle(
          color: Colors.white,
          fontSize: options.length > 10 ? 9.5 : 11,
          fontWeight: FontWeight.bold,
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
        oldDelegate.options != options ||
        oldDelegate.isDark != isDark;
  }
}
