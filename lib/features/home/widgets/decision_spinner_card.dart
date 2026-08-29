import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

/// Senior Date & Food Decision Spinner Card Widget with Slot-Machine Shuffle Animation
class DecisionSpinnerCard extends StatefulWidget {
  const DecisionSpinnerCard({super.key});

  @override
  State<DecisionSpinnerCard> createState() => _DecisionSpinnerCardState();
}

class _DecisionSpinnerCardState extends State<DecisionSpinnerCard> {
  final Random _random = Random();
  int _selectedCategoryIndex = 0; // 0: Food, 1: Activities
  bool _isSpinning = false;
  String _currentDisplayResult = 'Tap Spin to Decide!';
  Timer? _spinTimer;

  static const List<String> _foodOptions = [
    'Samgyupsal',
    'Coffee Date',
    'Fast Food',
    'Cook Together',
    'Milk Tea',
    'Dessert & Ice Cream',
    'Ramen & Sushi',
    'Pizza & Pasta',
  ];

  static const List<String> _activityOptions = [
    'Movie Night',
    'Walk in the Park',
    'Gaming Together',
    'Karaoke',
    'Long Drive',
    'Stargazing',
    'Board Games & Cards',
    'Shopping & Arcade',
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
            Icon(Icons.celebration_rounded, color: AppColors.softRose, size: 24),
            SizedBox(width: 8),
            Text(
              'Decision Made!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.softRose,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.celebration_rounded, color: AppColors.softRose, size: 24),
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
            child: const Text('Let\'s Do It!', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.softRose.withValues(alpha: 0.88),
              AppColors.lavender.withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.softRose.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.casino_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Decision Spinner',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Date & food picker',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 16),

            // Slot-Machine Display Window
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
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
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Spin Roulette Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSpinning ? null : _startRouletteSpin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.softRose,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: AnimatedRotation(
                  turns: _isSpinning ? 2.0 : 0.0,
                  duration: const Duration(milliseconds: 1200),
                  child: const Icon(Icons.casino_rounded, size: 22),
                ),
                label: Text(
                  _isSpinning ? 'Spinning Roulette...' : 'Spin the Wheel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
