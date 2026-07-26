import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

/// Senior Daily Love Quote & Sweet Note Glassmorphism Card Widget
class DailyQuoteCard extends StatefulWidget {
  const DailyQuoteCard({super.key});

  @override
  State<DailyQuoteCard> createState() => _DailyQuoteCardState();
}

class _DailyQuoteCardState extends State<DailyQuoteCard> {
  final Random _random = Random();
  late int _currentIndex;

  static const List<String> _romanticQuotes = [
    'Every love story is beautiful, but ours is my favorite.',
    'Together is my favorite place to be.',
    'In CJay & Aienne\'s world, love grows stronger every single day.',
    'You are my today and all of my tomorrows.',
    'I loved you yesterday, love you still, always have, always will.',
    'My heart is, and always will be, yours.',
    'Whatever our souls are made of, yours and mine are the same.',
    'Distance means so little when someone means so much.',
    'Two souls with but a single thought, two hearts that beat as one.',
    'Home is wherever I am with you.',
    'With you, every moment is a beautiful memory in the making.',
    'You are my sun, my moon, and all of my stars.',
    'I look at you and see the rest of my life in your eyes.',
    'The best thing to hold onto in life is each other.',
    'Loving you is the easiest and sweetest choice I make every day.',
    'You are my favorite notification.',
    'Side by side or miles apart, we are always connected at heart.',
    'In your smile, I see something more beautiful than stars.',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = _random.nextInt(_romanticQuotes.length);
  }

  void _shuffleQuote() {
    HapticFeedback.lightImpact();
    setState(() {
      int nextIndex;
      do {
        nextIndex = _random.nextInt(_romanticQuotes.length);
      } while (nextIndex == _currentIndex && _romanticQuotes.length > 1);
      _currentIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: GestureDetector(
        onTap: _shuffleQuote,
        child: Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E2C).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.9),
            gradient: LinearGradient(
              colors: [
                AppColors.softRose.withValues(alpha: isDark ? 0.15 : 0.1),
                AppColors.lavender.withValues(alpha: isDark ? 0.25 : 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.softRose.withValues(alpha: 0.22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.softRose.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header: Quote Icon + "Sweet Daily Note" + Shuffle Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.softRose.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.format_quote_rounded,
                          color: AppColors.softRose,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sweet Daily Note',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.softRose,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _shuffleQuote,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.softRose.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.softRose,
                        size: 16,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'New quote',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Animated Quote Body Text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  key: ValueKey<int>(_currentIndex),
                  padding: const EdgeInsets.only(left: 4.0, right: 4.0),
                  child: Text(
                    '"${_romanticQuotes[_currentIndex]}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
