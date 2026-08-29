import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/supabase_data_service.dart';

/// Senior Date & Food Decision Spinner Screen with Online Sync & Anti-Duplicate Guarantee
class DecisionSpinnerScreen extends StatefulWidget {
  const DecisionSpinnerScreen({super.key});

  @override
  State<DecisionSpinnerScreen> createState() => _DecisionSpinnerScreenState();
}

class _DecisionSpinnerScreenState extends State<DecisionSpinnerScreen> {
  final Random _random = Random();
  int _selectedCategoryIndex = 0; // 0: Food, 1: Activities
  bool _isSpinning = false;
  bool _isLoadingOnline = false;
  String _currentDisplayResult = 'Tap Spin to Decide!';
  Timer? _spinTimer;

  // History tracking to prevent duplicates / repeating results
  final List<String> _foodHistory = [];
  final List<String> _activityHistory = [];

  // Base curated options without emojis
  final List<String> _foodOptions = [
    'Samgyupsal / Unlimited K-BBQ',
    'Jollibee Chickenjoy & Burgers',
    'Milk Tea & Boba',
    'Coffee Shop & Pastry Date',
    'Pares & Mami Night',
    'Sisig & Inasal Grill',
    'Lechon Manok & Liempo',
    'Ramen & Japanese Bento',
    'Pizza & Pasta',
    'Cook Sinigang or Adobo Together',
    'Street Food (Fishball, Kwek-Kwek, Isaw)',
    'Dessert, Ice Cream & Halo-Halo',
  ];

  final List<String> _activityOptions = [
    'Mall Strolling & Window Shopping',
    'Cinema Movie Night & Popcorn',
    'Videoke & Karaoke Singing Session',
    'Sunset Walk at Baywalk or Park',
    'Arcade Games & Basketball Shootout',
    'Night Drive & Convenience Store Tambay',
    'Park Picnic & Photo Shoot',
    'Food Park & Night Market Trip',
    'Co-op Mobile Gaming Session',
    'Coffee Shop Chitchat & Board Games',
    'Grocery Date & Supermarket Run',
    'Bowling & Billiards Match',
  ];

  List<String> get _currentOptions =>
      _selectedCategoryIndex == 0 ? _foodOptions : _activityOptions;

  List<String> get _currentHistory =>
      _selectedCategoryIndex == 0 ? _foodHistory : _activityHistory;

  @override
  void initState() {
    super.initState();
    _fetchOnlineIdeas();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  /// Connect to Supabase / Internet to fetch live online date & food ideas
  Future<void> _fetchOnlineIdeas() async {
    setState(() => _isLoadingOnline = true);
    try {
      final response = await SupabaseDataService.client
          .from('decision_ideas')
          .select()
          .limit(30);

      final records = List<Map<String, dynamic>>.from(response);

      if (records.isNotEmpty) {
        final onlineFood = <String>[];
        final onlineActivities = <String>[];

        for (final row in records) {
          final category = row['category']?.toString().toLowerCase() ?? '';
          final title = row['title']?.toString() ?? '';
          if (title.isNotEmpty) {
            if (category == 'food' && !_foodOptions.contains(title)) {
              onlineFood.add(title);
            } else if (category == 'activity' && !_activityOptions.contains(title)) {
              onlineActivities.add(title);
            }
          }
        }

        if (mounted) {
          setState(() {
            _foodOptions.addAll(onlineFood);
            _activityOptions.addAll(onlineActivities);
          });
        }
      }
    } catch (_) {
      // Silent fallback to local pool if table does not exist in Supabase schema yet
    } finally {
      if (mounted) {
        setState(() => _isLoadingOnline = false);
      }
    }
  }

  /// Start roulette spin with guaranteed non-duplicate filtering
  void _startRouletteSpin() {
    if (_isSpinning) return;

    // Filter out options that were recently picked to ensure NO duplicates
    final availableOptions = _currentOptions
        .where((item) => !_currentHistory.contains(item))
        .toList();

    // If all options have been picked in history, clear history to restart loop
    final poolToUse = availableOptions.isNotEmpty ? availableOptions : _currentOptions;
    if (availableOptions.isEmpty) {
      _currentHistory.clear();
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSpinning = true;
    });

    int ticks = 0;
    const totalTicks = 20;

    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 65), (timer) {
      ticks++;
      HapticFeedback.selectionClick();

      final randomIndex = _random.nextInt(poolToUse.length);
      setState(() {
        _currentDisplayResult = poolToUse[randomIndex];
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        _finalizeDecision(poolToUse);
      }
    });
  }

  void _finalizeDecision(List<String> poolUsed) {
    HapticFeedback.heavyImpact();

    // Pick final winner guaranteed from non-duplicate pool
    final winnerIndex = _random.nextInt(poolUsed.length);
    final winner = poolUsed[winnerIndex];

    setState(() {
      _isSpinning = false;
      _currentDisplayResult = winner;
      _currentHistory.add(winner);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2C)
            : Colors.white,
        title: const Text(
          'Decision Made!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.softRose,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The roulette has spoken:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.softRose.withValues(alpha: 0.18),
                    AppColors.lavender.withValues(alpha: 0.28),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.softRose.withValues(alpha: 0.3),
                ),
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
            const SizedBox(height: 10),
            const Text(
              'Non-Duplicate Anti-Repeat Active',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('Let\'s Do It!', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Dialog to add custom choice
  void _showAddCustomOptionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Custom ${_selectedCategoryIndex == 0 ? "Food" : "Activity"}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter custom option...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  if (_selectedCategoryIndex == 0) {
                    _foodOptions.insert(0, text);
                  } else {
                    _activityOptions.insert(0, text);
                  }
                });
                Navigator.pop(context);
                SnackbarHelper.showSuccess(
                  context,
                  'Added "$text" to options!',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softRose,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text(
          'Date & Food Picker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.softRose, AppColors.lavender],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Fetch Online Ideas',
            onPressed: _fetchOnlineIdeas,
          ),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Main Card Container
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.softRose.withValues(alpha: 0.9),
                      AppColors.lavender.withValues(alpha: 0.92),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softRose.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.casino_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isLoadingOnline)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.wifi_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Online Sync',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Can\'t Decide? Spin the Wheel!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Guaranteed anti-duplicate roulette with online dynamic suggestions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Toggle Tabs: Food vs Activities
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCategoryTab(
                              index: 0,
                              label: 'Food',
                            ),
                          ),
                          Expanded(
                            child: _buildCategoryTab(
                              index: 1,
                              label: 'Activities',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Slot-Machine Display Window
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 100),
                        child: Text(
                          _currentDisplayResult,
                          key: ValueKey<String>(_currentDisplayResult),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Spin Roulette Button & Add Custom Option Button Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSpinning ? null : _startRouletteSpin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.softRose,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: AnimatedRotation(
                              turns: _isSpinning ? 2.0 : 0.0,
                              duration: const Duration(milliseconds: 1200),
                              child: const Icon(Icons.casino_rounded, size: 24),
                            ),
                            label: Text(
                              _isSpinning ? 'Spinning...' : 'Spin Roulette',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _showAddCustomOptionDialog,
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'Add Custom Option',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Recent Picked History Chips (Anti-Duplicate Guarantee Display)
              if (_currentHistory.isNotEmpty) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recently Picked (Excluded from next spin):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _currentHistory.map((picked) {
                    return Chip(
                      label: Text(
                        picked,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: AppColors.softRose.withValues(alpha: 0.15),
                      side: BorderSide(color: AppColors.softRose.withValues(alpha: 0.3)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab({required int index, required String label}) {
    final isSelected = _selectedCategoryIndex == index;

    return GestureDetector(
      onTap: () {
        if (_isSpinning) return;
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCategoryIndex = index;
          _currentDisplayResult = 'Tap Spin to Decide!';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.softRose : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
