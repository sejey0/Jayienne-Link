import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/social_link_model.dart';

/// Pixel-perfect, high-fidelity vector icon renderer for social platforms
class PlatformBrandIcon extends StatelessWidget {
  final SocialPlatform platform;
  final double size;
  final bool showBackground;
  final double borderRadius;

  const PlatformBrandIcon({
    super.key,
    required this.platform,
    this.size = 24.0,
    this.showBackground = true,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconContent = CustomPaint(
      size: Size(size, size),
      painter: _PlatformIconPainter(platform: platform),
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: iconContent),
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
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.62),
          painter: _PlatformIconPainter(platform: platform, isMonochromeWhite: true),
        ),
      ),
    );
  }
}

class _PlatformIconPainter extends CustomPainter {
  final SocialPlatform platform;
  final bool isMonochromeWhite;

  _PlatformIconPainter({
    required this.platform,
    this.isMonochromeWhite = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokeWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (platform) {
      case SocialPlatform.website:
        _drawWebsite(canvas, size, strokeWhite);
        break;
      case SocialPlatform.instagram:
        _drawInstagram(canvas, size, strokeWhite, whitePaint);
        break;
      case SocialPlatform.tiktok:
        _drawTikTok(canvas, size, strokeWhite, whitePaint);
        break;
      case SocialPlatform.spotify:
        _drawSpotify(canvas, size, strokeWhite, whitePaint);
        break;
      case SocialPlatform.facebook:
        _drawFacebook(canvas, size, whitePaint);
        break;
      case SocialPlatform.twitter:
        _drawXTwitter(canvas, size, strokeWhite, whitePaint);
        break;
      case SocialPlatform.youtube:
        _drawYouTube(canvas, size, strokeWhite, whitePaint);
        break;
      case SocialPlatform.snapchat:
        _drawSnapchat(canvas, size, strokeWhite, whitePaint);
        break;
      case SocialPlatform.telegram:
        _drawTelegram(canvas, size, whitePaint);
        break;
      case SocialPlatform.discord:
        _drawDiscord(canvas, size, strokeWhite, whitePaint);
        break;
      case SocialPlatform.github:
        _drawGitHub(canvas, size, whitePaint);
        break;
      case SocialPlatform.pinterest:
        _drawPinterest(canvas, size, strokeWhite, whitePaint);
        break;
    }
  }

  void _drawWebsite(Canvas canvas, Size size, Paint stroke) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;
    stroke.strokeWidth = math.max(1.5, size.width * 0.09);

    // Outer globe circle
    canvas.drawCircle(center, radius, stroke);

    // Horizontal equator
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      stroke,
    );

    // Vertical meridian oval
    final ovalRect = Rect.fromCenter(
      center: center,
      width: radius * 1.1,
      height: radius * 2,
    );
    canvas.drawOval(ovalRect, stroke);
  }

  void _drawInstagram(Canvas canvas, Size size, Paint stroke, Paint fill) {
    stroke.strokeWidth = math.max(1.5, size.width * 0.1);
    final r = size.width * 0.18;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.05, size.width * 0.9, size.height * 0.9),
      Radius.circular(r),
    );

    // Outer squircle
    canvas.drawRRect(rect, stroke);

    // Center lens circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.22, stroke);

    // Flash dot at top right
    fill.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.26),
      size.width * 0.06,
      fill,
    );
  }

  void _drawTikTok(Canvas canvas, Size size, Paint stroke, Paint fill) {
    stroke.strokeWidth = math.max(2.0, size.width * 0.12);
    final path = Path();

    // Musical note with hook
    final startX = size.width * 0.42;
    final startY = size.height * 0.15;
    
    path.moveTo(startX, startY);
    path.lineTo(startX, size.height * 0.65);
    
    // Bottom note circle
    path.addOval(Rect.fromCircle(
      center: Offset(startX - size.width * 0.14, size.height * 0.68),
      radius: size.width * 0.14,
    ));

    // Top hook
    final hookPath = Path();
    hookPath.moveTo(startX, startY);
    hookPath.cubicTo(
      startX + size.width * 0.1,
      startY + size.height * 0.12,
      startX + size.width * 0.35,
      startY + size.height * 0.14,
      startX + size.width * 0.42,
      startY + size.height * 0.02,
    );

    canvas.drawPath(path, fill);
    canvas.drawPath(hookPath, stroke);
  }

  void _drawSpotify(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.46;

    stroke.strokeWidth = math.max(1.5, size.width * 0.09);

    // 3 Curved sound lines
    final arc1 = Path();
    arc1.addArc(
      Rect.fromCircle(center: Offset(cx, cy + size.height * 0.1), radius: r * 0.8),
      -math.pi * 0.8,
      math.pi * 0.6,
    );
    canvas.drawPath(arc1, stroke);

    final arc2 = Path();
    stroke.strokeWidth = math.max(1.3, size.width * 0.08);
    arc2.addArc(
      Rect.fromCircle(center: Offset(cx, cy + size.height * 0.14), radius: r * 0.58),
      -math.pi * 0.8,
      math.pi * 0.6,
    );
    canvas.drawPath(arc2, stroke);

    final arc3 = Path();
    stroke.strokeWidth = math.max(1.1, size.width * 0.07);
    arc3.addArc(
      Rect.fromCircle(center: Offset(cx, cy + size.height * 0.18), radius: r * 0.38),
      -math.pi * 0.8,
      math.pi * 0.6,
    );
    canvas.drawPath(arc3, stroke);
  }

  void _drawFacebook(Canvas canvas, Size size, Paint fill) {
    fill.color = Colors.white;
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Stylized Facebook lowercase 'f'
    path.moveTo(w * 0.65, h);
    path.lineTo(w * 0.48, h);
    path.lineTo(w * 0.48, h * 0.54);
    path.lineTo(w * 0.35, h * 0.54);
    path.lineTo(w * 0.35, h * 0.38);
    path.lineTo(w * 0.48, h * 0.38);
    path.lineTo(w * 0.48, h * 0.25);
    path.cubicTo(w * 0.48, h * 0.12, w * 0.56, h * 0.05, w * 0.72, h * 0.05);
    path.lineTo(w * 0.82, h * 0.05);
    path.lineTo(w * 0.82, h * 0.22);
    path.lineTo(w * 0.72, h * 0.22);
    path.cubicTo(w * 0.65, h * 0.22, w * 0.65, h * 0.26, w * 0.65, h * 0.32);
    path.lineTo(w * 0.65, h * 0.38);
    path.lineTo(w * 0.81, h * 0.38);
    path.lineTo(w * 0.78, h * 0.54);
    path.lineTo(w * 0.65, h * 0.54);
    path.close();

    canvas.drawPath(path, fill);
  }

  void _drawXTwitter(Canvas canvas, Size size, Paint stroke, Paint fill) {
    fill.color = Colors.white;
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Geometric 𝕏 logo
    path.moveTo(w * 0.15, h * 0.15);
    path.lineTo(w * 0.45, h * 0.55);
    path.lineTo(w * 0.15, h * 0.85);
    path.lineTo(w * 0.28, h * 0.85);
    path.lineTo(w * 0.52, h * 0.63);
    path.lineTo(w * 0.74, h * 0.85);
    path.lineTo(w * 0.88, h * 0.85);
    path.lineTo(w * 0.58, h * 0.45);
    path.lineTo(w * 0.85, h * 0.15);
    path.lineTo(w * 0.72, h * 0.15);
    path.lineTo(w * 0.50, h * 0.38);
    path.lineTo(w * 0.30, h * 0.15);
    path.close();

    canvas.drawPath(path, fill);
  }

  void _drawYouTube(Canvas canvas, Size size, Paint stroke, Paint fill) {
    fill.color = Colors.white;
    final w = size.width;
    final h = size.height;

    // Centered Play Triangle
    final triPath = Path();
    triPath.moveTo(w * 0.40, h * 0.30);
    triPath.lineTo(w * 0.68, h * 0.50);
    triPath.lineTo(w * 0.40, h * 0.70);
    triPath.close();

    canvas.drawPath(triPath, fill);
  }

  void _drawSnapchat(Canvas canvas, Size size, Paint stroke, Paint fill) {
    fill.color = Colors.white;
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Snapchat Ghost Outline
    path.moveTo(w * 0.5, h * 0.15);
    path.cubicTo(w * 0.32, h * 0.15, w * 0.30, h * 0.35, w * 0.30, h * 0.55);
    path.cubicTo(w * 0.20, h * 0.58, w * 0.18, h * 0.65, w * 0.28, h * 0.70);
    path.cubicTo(w * 0.24, h * 0.82, w * 0.38, h * 0.85, w * 0.50, h * 0.82);
    path.cubicTo(w * 0.62, h * 0.85, w * 0.76, h * 0.82, w * 0.72, h * 0.70);
    path.cubicTo(w * 0.82, h * 0.65, w * 0.80, h * 0.58, w * 0.70, h * 0.55);
    path.cubicTo(w * 0.70, h * 0.35, w * 0.68, h * 0.15, w * 0.50, h * 0.15);
    path.close();

    canvas.drawPath(path, fill);
  }

  void _drawTelegram(Canvas canvas, Size size, Paint fill) {
    fill.color = Colors.white;
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Paper Airplane
    path.moveTo(w * 0.15, h * 0.48);
    path.lineTo(w * 0.82, h * 0.20);
    path.lineTo(w * 0.68, h * 0.80);
    path.lineTo(w * 0.46, h * 0.64);
    path.lineTo(w * 0.38, h * 0.75);
    path.lineTo(w * 0.36, h * 0.58);
    path.lineTo(w * 0.65, h * 0.34);
    path.lineTo(w * 0.28, h * 0.52);
    path.close();

    canvas.drawPath(path, fill);
  }

  void _drawDiscord(Canvas canvas, Size size, Paint stroke, Paint fill) {
    fill.color = Colors.white;
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Discord Clyde controller face
    path.moveTo(w * 0.25, h * 0.30);
    path.cubicTo(w * 0.35, h * 0.22, w * 0.65, h * 0.22, w * 0.75, h * 0.30);
    path.lineTo(w * 0.85, h * 0.65);
    path.cubicTo(w * 0.75, h * 0.78, w * 0.62, h * 0.78, w * 0.56, h * 0.72);
    path.lineTo(w * 0.52, h * 0.64);
    path.lineTo(w * 0.48, h * 0.64);
    path.lineTo(w * 0.44, h * 0.72);
    path.cubicTo(w * 0.38, h * 0.78, w * 0.25, h * 0.78, w * 0.15, h * 0.65);
    path.close();

    canvas.drawPath(path, fill);

    // Eyes (dark punch holes)
    final eyePaint = Paint()
      ..color = const Color(0xFF5865F2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.38, h * 0.48), w * 0.06, eyePaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.48), w * 0.06, eyePaint);
  }

  void _drawGitHub(Canvas canvas, Size size, Paint fill) {
    fill.color = Colors.white;
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Octocat silhouette
    path.addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.38));

    // Ears
    final ear1 = Path();
    ear1.moveTo(w * 0.25, h * 0.35);
    ear1.lineTo(w * 0.32, h * 0.18);
    ear1.lineTo(w * 0.42, h * 0.25);
    ear1.close();

    final ear2 = Path();
    ear2.moveTo(w * 0.75, h * 0.35);
    ear2.lineTo(w * 0.68, h * 0.18);
    ear2.lineTo(w * 0.58, h * 0.25);
    ear2.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(ear1, fill);
    canvas.drawPath(ear2, fill);
  }

  void _drawPinterest(Canvas canvas, Size size, Paint stroke, Paint fill) {
    fill.color = Colors.white;
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Stylized Pinterest Pin 'P'
    path.moveTo(w * 0.45, h * 0.20);
    path.cubicTo(w * 0.32, h * 0.20, w * 0.25, h * 0.32, w * 0.28, h * 0.48);
    path.cubicTo(w * 0.30, h * 0.56, w * 0.36, h * 0.62, w * 0.40, h * 0.60);
    path.cubicTo(w * 0.42, h * 0.58, w * 0.40, h * 0.52, w * 0.38, h * 0.45);
    path.lineTo(w * 0.32, h * 0.85);
    path.lineTo(w * 0.42, h * 0.85);
    path.lineTo(w * 0.45, h * 0.65);
    path.cubicTo(w * 0.50, h * 0.68, w * 0.65, h * 0.65, w * 0.70, h * 0.50);
    path.cubicTo(w * 0.75, h * 0.35, w * 0.65, h * 0.20, w * 0.45, h * 0.20);
    path.close();

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _PlatformIconPainter oldDelegate) =>
      oldDelegate.platform != platform || oldDelegate.isMonochromeWhite != isMonochromeWhite;
}
