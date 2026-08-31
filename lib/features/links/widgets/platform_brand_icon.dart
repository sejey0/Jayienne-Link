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

    // Default gradient/vector icon fallback
    final Widget defaultCustomFallback = _buildDefaultIcon(iconSize);

    if (isCustomWithDomain) {
      final faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=128';

      return Image.network(
        faviconUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            if (!showBackground) {
              return SizedBox(
                width: size,
                height: size,
                child: Center(child: child),
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
                child: Padding(
                  padding: EdgeInsets.all(size * 0.18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(math.max(2, borderRadius * 0.35)),
                    child: child,
                  ),
                ),
              ),
            );
          }
          return defaultCustomFallback;
        },
        errorBuilder: (context, error, stackTrace) {
          // If favicon cannot be found or network fails, cleanly render default custom icon
          return defaultCustomFallback;
        },
      );
    }

    return defaultCustomFallback;
  }

  Widget _buildDefaultIcon(double iconSize) {
    final effectiveIconColor = color ??
        (showBackground ? platform.iconColor : platform.primaryColor);

    final Widget iconWidget = FaIcon(
      platform.icon,
      size: iconSize,
      color: effectiveIconColor,
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: iconWidget),
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
      child: Center(child: iconWidget),
    );
  }
}
