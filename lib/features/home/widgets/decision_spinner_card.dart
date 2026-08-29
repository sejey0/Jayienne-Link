import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../screens/decision_spinner_screen.dart';

/// Senior Date & Food Decision Spinner Card Widget with Slot-Machine Shuffle Animation & Full Wheel Navigation
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
    'Samgyupsal / K-BBQ',
    'Coffee Date & Pastry',
    'Jollibee Chickenjoy',
    'Cook Dinner Together',
    'Milk Tea & Boba',
    'Dessert & Ice Cream',
    'Ramen & Bento Box',
    'Pizza & Pasta Date',
  ];

  static const List<String> _activityOptions = [
    'Cinema Movie Night',
    'Sunset Walk in Park',
    'Co-op Gaming Session',
    'Videoke / Karaoke',
    'Night Drive & Snacks',
    'Park Picnic & Photos',
    'Board Games Match',
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
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor:
              isDark ? const Color(0xFF1E162B) : Colors.white,
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.celebration_rounded,
                  color: Color(0xFFFF758C), size: 24),
              SizedBox(width: 8),
              Text(
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
                'The roulette has spoken:',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF758C).withValues(alpha: 0.2),
                      const Color(0xFFA18CD1).withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
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
                        'Close',
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
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
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
                          style: TextStyle(fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E162B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFFFF758C).withValues(alpha: 0.25)
                : const Color(0xFFFF758C).withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF758C).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header Row with Squircle icon and Open Wheel action
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.casino_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Decision Spinner',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Date & food picker roulette',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open Interactive Wheel',
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  color: const Color(0xFFFF758C),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DecisionSpinnerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toggle Tabs: Food vs Activities
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCategoryTab(
                      index: 0,
                      label: 'Food',
                      icon: Icons.restaurant_rounded,
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _buildCategoryTab(
                      index: 1,
                      label: 'Activities',
                      icon: Icons.local_activity_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Slot-Machine Display Window
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFFF758C).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                child: Text(
                  _currentDisplayResult,
                  key: ValueKey<String>(_currentDisplayResult),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Spin Roulette Button
            Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                gradient: _isSpinning
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _isSpinning
                    ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                    : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isSpinning
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isSpinning ? null : _startRouletteSpin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor:
                      isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: AnimatedRotation(
                  turns: _isSpinning ? 2.0 : 0.0,
                  duration: const Duration(milliseconds: 1200),
                  child: const Icon(Icons.casino_rounded, size: 20),
                ),
                label: Text(
                  _isSpinning ? 'Spinning Roulette...' : 'Spin Roulette',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
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
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.grey.shade700),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.grey.shade700),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
