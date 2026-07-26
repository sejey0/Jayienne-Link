import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/heartbeat_provider.dart';

/// High-Performance CustomPainter for rendering interactive touch canvas:
/// - Smooth touch glows
/// - Fading historic touch trails
/// - Proximity collision pulse & ripple animations
class HeartbeatCanvasPainter extends CustomPainter {
  final Offset? localTouch;
  final Offset? partnerTouch;
  final bool isLocalTouching;
  final bool isPartnerTouching;
  final List<TouchTrailPoint> localTrail;
  final List<TouchTrailPoint> partnerTrail;
  final bool isColliding;
  final Offset? collisionPoint;
  final double collisionRippleRadius;

  HeartbeatCanvasPainter({
    required this.localTouch,
    required this.partnerTouch,
    required this.isLocalTouching,
    required this.isPartnerTouching,
    required this.localTrail,
    required this.partnerTrail,
    required this.isColliding,
    required this.collisionPoint,
    required this.collisionRippleRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Fading Historic Touch Trails
    _drawTrail(canvas, localTrail, AppColors.softRose);
    _drawTrail(canvas, partnerTrail, AppColors.lavender);

    // 2. Draw Active Touch Glows
    if (isLocalTouching && localTouch != null) {
      _drawGlowPoint(canvas, localTouch!, AppColors.softRose, 'You');
    }

    if (isPartnerTouching && partnerTouch != null) {
      _drawGlowPoint(canvas, partnerTouch!, AppColors.lavender, 'Partner');
    }

    // 3. Draw Proximity Collision Ripple Rings
    if (isColliding && collisionPoint != null) {
      _drawCollisionRipple(canvas, collisionPoint!, collisionRippleRadius);
    }
  }

  /// Render decaying touch trail
  void _drawTrail(Canvas canvas, List<TouchTrailPoint> trail, Color color) {
    for (int i = 0; i < trail.length; i++) {
      final point = trail[i];
      final opacity = point.opacity;
      if (opacity <= 0.0) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final radius = 14.0 * opacity;
      canvas.drawCircle(point.position, radius, paint);
    }
  }

  /// Render pulsating glow point with radial gradient
  void _drawGlowPoint(Canvas canvas, Offset center, Color color, String label) {
    // Outer Ambient Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 45))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(center, 45, glowPaint);

    // Core Solid Touch Circle
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 16, corePaint);

    // White Inner Heart Accent
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6, innerPaint);
  }

  /// Render expanding collision pulse ripple animation
  void _drawCollisionRipple(Canvas canvas, Offset center, double radius) {
    const maxRadius = 60.0;
    final progress = (radius / maxRadius).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    final ripplePaint = Paint()
      ..color = AppColors.softRose.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, radius, ripplePaint);

    final innerRipplePaint = Paint()
      ..color = AppColors.lavender.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, (radius * 0.6), innerRipplePaint);
  }

  @override
  bool shouldRepaint(covariant HeartbeatCanvasPainter oldDelegate) {
    return true; // Continuously repaint during touch activity & lerp animation
  }
}
