import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Senior Pop-up Modal Alert System (Replaces bottom snackbars with romantic centered pop-up modals)
class SnackbarHelper {
  SnackbarHelper._();

  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    String title = 'Success!',
    String buttonText = 'OK',
  }) {
    HapticFeedback.lightImpact();
    return _showModalDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      gradientColors: const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
      buttonText: buttonText,
    );
  }

  static Future<void> showError(
    BuildContext context,
    String message, {
    String title = 'Oops!',
    String buttonText = 'OK',
  }) {
    HapticFeedback.heavyImpact();
    return _showModalDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.error_outline_rounded,
      gradientColors: const [Color(0xFFFF5252), Color(0xFFD81B60)],
      buttonText: buttonText,
    );
  }

  static Future<void> showInfo(
    BuildContext context,
    String message, {
    String title = 'Notice',
    String buttonText = 'OK',
  }) {
    HapticFeedback.lightImpact();
    return _showModalDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.info_outline_rounded,
      gradientColors: const [Color(0xFFFF758C), Color(0xFFA18CD1)],
      buttonText: buttonText,
    );
  }

  static Future<void> showCustom({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required List<Color> gradientColors,
    String buttonText = 'OK',
  }) {
    HapticFeedback.lightImpact();
    return _showModalDialog(
      context: context,
      title: title,
      message: message,
      icon: icon,
      gradientColors: gradientColors,
      buttonText: buttonText,
    );
  }

  static Future<void> _showModalDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required List<Color> gradientColors,
    required String buttonText,
  }) {
    if (!context.mounted) return Future.value();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Glowing Gradient Icon Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
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
            const SizedBox(height: 8),

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
            const SizedBox(height: 20),

            // Gradient Action Button
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors.length >= 2
                      ? gradientColors
                      : [AppColors.softRose, AppColors.lavender],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
