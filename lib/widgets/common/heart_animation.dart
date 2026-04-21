import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HeartAnimation extends StatelessWidget {
  final double size;
  final Color? color;
  static const String _assetPath = 'assets/icon/road_to_forever, no bg.png';

  const HeartAnimation({
    super.key,
    this.size = 48.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.15, 1.15),
          duration: 800.ms,
          curve: Curves.easeInOut,
        )
        .fadeIn(duration: 400.ms);
  }
}
