import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../models/social_link_model.dart';

/// Pixel-perfect, official brand vector icon renderer for social platforms
class PlatformBrandIcon extends StatelessWidget {
  final SocialPlatform platform;
  final double size;
  final bool showBackground;
  final double borderRadius;
  final Color? color;

  const PlatformBrandIcon({
    super.key,
    required this.platform,
    this.size = 24.0,
    this.showBackground = true,
    this.borderRadius = 12.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = showBackground ? size * 0.54 : size;

    final iconWidget = FaIcon(
      platform.icon,
      size: iconSize,
      color: color ?? (showBackground ? Colors.white : platform.primaryColor),
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
