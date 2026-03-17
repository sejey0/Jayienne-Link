import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class HeartAnimation extends StatelessWidget {
  final double size;
  final Color? color;

  const HeartAnimation({
    super.key,
    this.size = 48.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.favorite,
      size: size,
      color: color ?? AppColors.softRose,
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
