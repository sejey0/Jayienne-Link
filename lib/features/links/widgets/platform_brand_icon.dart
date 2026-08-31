import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../models/social_link_model.dart';

/// Pixel-perfect, official brand vector icon renderer for social platforms
/// with auto-detection of real website icons for custom links.
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
    final iconSize = showBackground ? size * 0.56 : size;

    final domain = (platform == SocialPlatform.website && customUrl != null && customUrl!.trim().isNotEmpty)
        ? SocialPlatform.extractDomain(customUrl!)
        : null;

    final Widget fallbackIcon = FaIcon(
      platform.icon,
      size: iconSize,
      color: color ?? (showBackground ? Colors.white : platform.primaryColor),
    );

    Widget iconWidget = fallbackIcon;

    if (domain != null && domain.isNotEmpty && domain.contains('.')) {
      final faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(math.max(3, borderRadius * 0.35)),
        child: Image.network(
          faviconUrl,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallbackIcon,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallbackIcon;
          },
        ),
      );
    }

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
        boxShadow: [
          BoxShadow(
            color: platform.primaryColor.withValues(alpha: 0.35),
            blurRadius: math.max(4, size * 0.2),
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Center(child: iconWidget),
    );
  }
}
