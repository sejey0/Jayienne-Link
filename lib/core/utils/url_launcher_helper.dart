import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'snackbar_helper.dart';

class UrlLauncherHelper {
  UrlLauncherHelper._();

  /// Safely open a web URL or social profile in external app / browser.
  static Future<bool> launchLink(BuildContext context, String rawUrl) async {
    final cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'No URL provided.');
      }
      return false;
    }

    // Ensure valid scheme
    String formattedUrl = cleanUrl;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final uri = Uri.tryParse(formattedUrl);
    if (uri == null) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Invalid URL format: $cleanUrl');
      }
      return false;
    }

    try {
      HapticFeedback.lightImpact();
      
      // Attempt 1: Launch in external native application (e.g. Instagram app, Spotify app)
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Attempt 2: Fallback to in-app web view / platform default
        final inAppFallback = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (!inAppFallback && context.mounted) {
          SnackbarHelper.showError(context, 'Could not open link: $formattedUrl');
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[UrlLauncherHelper] Launch error: $e');
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Unable to open link: $e');
      }
      return false;
    }
  }

  /// Copy link or username to clipboard with haptic feedback & confirmation toast
  static Future<void> copyToClipboard(
    BuildContext context,
    String text, {
    String? label,
  }) async {
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      SnackbarHelper.showSuccess(
        context,
        label != null ? 'Copied $label to clipboard!' : 'Copied to clipboard!',
      );
    }
  }
}
