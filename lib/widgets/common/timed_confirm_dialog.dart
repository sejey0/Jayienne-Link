import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Shows a standardized destructive confirmation dialog with a 5-second countdown timer.
/// The confirm button remains locked until the 5 seconds elapse to prevent accidental taps.
Future<bool?> showTimedConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.delete_outline_rounded,
  int countdownSeconds = 5,
  List<Color>? gradientColors,
}) {
  HapticFeedback.mediumImpact();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Icon Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFF5252), size: 30),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
            ),
          ),
          const SizedBox(height: 10),

          // Message
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 22),

          // Action Buttons: Confirm (Timed) and Cancel
          TimedDestructiveButton(
            label: confirmLabel,
            countdownSeconds: countdownSeconds,
            icon: icon,
            gradientColors: gradientColors,
            onPressed: () => Navigator.pop(ctx, true),
          ),
          const SizedBox(height: 10),
          SecondaryCancelButton(
            label: cancelLabel,
            height: 44,
            borderRadius: 14,
            onPressed: () => Navigator.pop(ctx, false),
          ),
        ],
      ),
    ),
  );
}

/// A standalone destructive action button with a mandatory countdown timer.
/// Displays "$label (5s)" ... "$label" and remains disabled until the timer expires.
class TimedDestructiveButton extends StatefulWidget {
  final String label;
  final int countdownSeconds;
  final VoidCallback onPressed;
  final IconData icon;
  final List<Color>? gradientColors;
  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const TimedDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.countdownSeconds = 5,
    this.icon = Icons.delete_outline_rounded,
    this.gradientColors,
    this.width = double.infinity,
    this.height = 46,
    this.borderRadius = 14,
    this.fontSize = 14,
    this.padding,
  });

  @override
  State<TimedDestructiveButton> createState() => _TimedDestructiveButtonState();
}

class _TimedDestructiveButtonState extends State<TimedDestructiveButton> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.countdownSeconds;
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_secondsLeft <= 1) {
          timer.cancel();
          HapticFeedback.lightImpact();
          setState(() {
            _secondsLeft = 0;
          });
        } else {
          setState(() {
            _secondsLeft--;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _secondsLeft > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradient = widget.gradientColors ??
        const [Color(0xFFFF5252), Color(0xFFD81B60)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: isLocked
            ? null
            : LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isLocked
            ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200)
            : null,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: isLocked ? null : widget.onPressed,
        icon: Icon(
          isLocked ? Icons.timer_outlined : widget.icon,
          size: 18,
          color: isLocked
              ? (isDark ? Colors.white38 : Colors.grey.shade500)
              : Colors.white,
        ),
        label: Text(
          isLocked ? '${widget.label} (${_secondsLeft}s)' : widget.label,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: isLocked
                ? (isDark ? Colors.white38 : Colors.grey.shade500)
                : Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

/// A standardized secondary / cancel button featuring a romantic outlined border,
/// soft tinted background, and themed typography matching the app's aesthetic.
class SecondaryCancelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const SecondaryCancelButton({
    super.key,
    this.label = 'Cancel',
    required this.onPressed,
    this.width = double.infinity,
    this.height = 44,
    this.borderRadius = 14,
    this.fontSize = 14,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFFFF8FA3) : const Color(0xFFFF758C);
    final borderColor = isDark
        ? const Color(0xFFA18CD1).withValues(alpha: 0.45)
        : const Color(0xFFFF758C).withValues(alpha: 0.45);
    final bgColor = isDark
        ? const Color(0xFFA18CD1).withValues(alpha: 0.08)
        : const Color(0xFFFF758C).withValues(alpha: 0.06);

    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: fontSize,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
