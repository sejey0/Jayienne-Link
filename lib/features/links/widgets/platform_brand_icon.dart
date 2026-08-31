import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../models/social_link_model.dart';

/// Ultra-vibrant, pixel-perfect official brand vector and real website icon renderer
class PlatformBrandIcon extends StatelessWidget {
  final SocialPlatform platform;
  final String? customUrl;
  final double size;
  final bool showBackground;
  final double borderRadius;
  final Color? color;

  const PlatformBrandIcon({
    super.key,
    required this.platform,
    this.customUrl,
    this.size = 24.0,
    this.showBackground = true,
    this.borderRadius = 12.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = showBackground ? size * 0.54 : size;

    final domain = (platform == SocialPlatform.website &&
            customUrl != null &&
            customUrl!.trim().isNotEmpty)
        ? SocialPlatform.extractDomain(customUrl!)
        : null;

    final isCustomWithDomain = domain != null && domain.isNotEmpty && domain.contains('.');

    // Real brand icon color (e.g. black for Snapchat, white for others)
    final effectiveIconColor = color ??
        (showBackground ? platform.iconColor : platform.primaryColor);

    final Widget fallbackIcon = FaIcon(
      platform.icon,
      size: iconSize,
      color: effectiveIconColor,
    );

    if (isCustomWithDomain) {
      final faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=128';

      final realFaviconWidget = Image.network(
        faviconUrl,
        width: showBackground ? size * 0.58 : size,
        height: showBackground ? size * 0.58 : size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallbackIcon,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallbackIcon;
        },
      );

      if (!showBackground) {
        return SizedBox(
          width: size,
          height: size,
          child: Center(child: realFaviconWidget),
        );
      }

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF221A30) : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: platform.primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: platform.primaryColor.withValues(alpha: 0.22),
              blurRadius: math.max(4, size * 0.2),
              offset: Offset(0, size * 0.08),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(math.max(3, borderRadius * 0.4)),
            child: realFaviconWidget,
          ),
        ),
      );
    }

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: fallbackIcon),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: platform.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: platform.primaryColor.withValues(alpha: 0.38),
            blurRadius: math.max(5, size * 0.24),
            offset: Offset(0, size * 0.09),
          ),
        ],
      ),
      child: Center(child: fallbackIcon),
    );
  }
}
