import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

/// Senior Date & Food Decision Spinner Screen with Back Button returning to Features Selection Sheet
class DecisionSpinnerScreen extends StatefulWidget {
  const DecisionSpinnerScreen({super.key});

  @override
  State<DecisionSpinnerScreen> createState() => _DecisionSpinnerScreenState();
}

class _DecisionSpinnerScreenState extends State<DecisionSpinnerScreen> {
  final Random _random = Random();
  int _selectedCategoryIndex = 0; // 0: Food, 1: Activities
  bool _isSpinning = false;
  String _currentDisplayResult = 'Tap Spin to Decide! 🎲';
  Timer? _spinTimer;

  static const List<String> _foodOptions = [
    'Samgyupsal 🥓',
    'Coffee Date ☕',
    'Fast Food 🍔',
    'Cook Together 🍳',
    'Milk Tea 🧋',
    'Dessert / Ice Cream 🍦',
    'Ramen & Sushi 🍜',
    'Pizza & Pasta 🍕',
  ];

  static const List<String> _activityOptions = [
    'Movie Night 🍿',
    'Walk in the Park 🌳',
    'Gaming Together 🎮',
    'Karaoke 🎤',
    'Long Drive 🚗',
    'Stargazing 🌟',
    'Board Games & Cards 🃏',
    'Shopping & Arcade 🕹️',
  ];

  List<String> get _currentOptions =>
      _selectedCategoryIndex == 0 ? _foodOptions : _activityOptions;

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  void _startRouletteSpin() {
    if (_isSpinning) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSpinning = true;
    });

    int ticks = 0;
    const totalTicks = 18;

    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      ticks++;
      HapticFeedback.selectionClick();

      final randomIndex = _random.nextInt(_currentOptions.length);
      setState(() {
        _currentDisplayResult = _currentOptions[randomIndex];
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        _finalizeDecision();
      }
    });
  }

  void _finalizeDecision() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSpinning = false;
    });

    final winner = _currentDisplayResult;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2C)
            : Colors.white,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎉', style: TextStyle(fontSize: 26)),
            SizedBox(width: 8),
            Text(
              'Decision Made!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.softRose,
              ),
            ),
            SizedBox(width: 8),
            Text('🎉', style: TextStyle(fontSize: 26)),
          ],
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
            child: const Text('Let\'s Do It! ❤️', style: TextStyle(fontWeight: FontWeight.bold)),
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
          'Date & Food Picker 🎲',
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.casino_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                      'Select a category below and tap spin for a random date idea or food choice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Toggle Tabs: Food 🍔 vs Activities 🎬
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
                              label: 'Food 🍔',
                            ),
                          ),
                          Expanded(
                            child: _buildCategoryTab(
                              index: 1,
                              label: 'Activities 🎬',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

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
                    const SizedBox(height: 20),

                    // Spin Roulette Button
                    SizedBox(
                      width: double.infinity,
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
                          _isSpinning ? 'Spinning Roulette...' : 'Spin the Wheel 🎲',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
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
          _currentDisplayResult = 'Tap Spin to Decide! 🎲';
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
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
