import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum LoveNudgeIconType { kiss, hug, heart }

/// Unique Custom Vector Emblem for Love Nudge Brand (Interlocking Infinite Heart Touch)
class LoveNudgeHeaderIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showGlow;

  const LoveNudgeHeaderIcon({
    super.key,
    this.size = 28,
    this.color,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: (color ?? AppColors.softRose).withValues(alpha: 0.5),
                  blurRadius: size * 0.4,
                  spreadRadius: size * 0.1,
                ),
              ],
            )
          : null,
      child: CustomPaint(
        painter: _HDLoveNudgeEmblemPainter(
          primaryColor: color ?? AppColors.softRose,
        ),
      ),
    );
  }
}

class _HDLoveNudgeEmblemPainter extends CustomPainter {
  final Color primaryColor;

  _HDLoveNudgeEmblemPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dual Interlocking Infinity Hearts Path
    final path = Path();
    path.moveTo(w * 0.50, h * 0.82);
    path.cubicTo(w * 0.14, h * 0.98, 0, h * 0.62, w * 0.12, h * 0.36);
    path.cubicTo(w * 0.22, h * 0.10, w * 0.44, h * 0.18, w * 0.50, h * 0.38);
    path.cubicTo(w * 0.56, h * 0.18, w * 0.78, h * 0.10, w * 0.88, h * 0.36);
    path.cubicTo(w * 1.00, h * 0.62, w * 0.86, h * 0.98, w * 0.50, h * 0.82);
    path.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          primaryColor == Colors.white
              ? Colors.white.withValues(alpha: 0.9)
              : const Color(0xFFAB47BC),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, fillPaint);

    // Inner Touch Reflection Sparkle
    final innerPath = Path();
    innerPath.moveTo(w * 0.50, h * 0.44);
    innerPath.cubicTo(w * 0.40, h * 0.34, w * 0.30, h * 0.46, w * 0.38, h * 0.56);
    innerPath.cubicTo(w * 0.46, h * 0.66, w * 0.50, h * 0.68, w * 0.50, h * 0.68);
    innerPath.cubicTo(w * 0.50, h * 0.68, w * 0.54, h * 0.66, w * 0.62, h * 0.56);
    innerPath.cubicTo(w * 0.70, h * 0.46, w * 0.60, h * 0.34, w * 0.50, h * 0.44);
    innerPath.close();

    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// HD Vector Kiss Lips Icon with Gradient & Gloss Highlights
class KissLipsIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showGlow;

  const KissLipsIcon({
    super.key,
    this.size = 28,
    this.color,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.78,
      decoration: showGlow
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: (color ?? AppColors.softRose).withValues(alpha: 0.5),
                  blurRadius: size * 0.4,
                  spreadRadius: size * 0.1,
                ),
              ],
            )
          : null,
      child: CustomPaint(
        painter: _HDKissLipsPainter(
          primaryColor: color ?? AppColors.softRose,
        ),
      ),
    );
  }
}

class _HDKissLipsPainter extends CustomPainter {
  final Color primaryColor;

  _HDKissLipsPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gradient = LinearGradient(
      colors: [
        primaryColor,
        primaryColor == Colors.white
            ? Colors.white
            : const Color(0xFFE91E63),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Upper Lip Path
    final upperLip = Path();
    upperLip.moveTo(w * 0.04, h * 0.44);
    upperLip.cubicTo(w * 0.22, h * 0.02, w * 0.38, h * 0.30, w * 0.50, h * 0.18);
    upperLip.cubicTo(w * 0.62, h * 0.30, w * 0.78, h * 0.02, w * 0.96, h * 0.44);
    upperLip.cubicTo(w * 0.74, h * 0.52, w * 0.52, h * 0.40, w * 0.50, h * 0.40);
    upperLip.cubicTo(w * 0.48, h * 0.40, w * 0.26, h * 0.52, w * 0.04, h * 0.44);
    upperLip.close();
    canvas.drawPath(upperLip, fillPaint);

    // Lower Lip Path
    final lowerLip = Path();
    lowerLip.moveTo(w * 0.08, h * 0.48);
    lowerLip.cubicTo(w * 0.30, h * 0.52, w * 0.48, h * 0.54, w * 0.50, h * 0.54);
    lowerLip.cubicTo(w * 0.52, h * 0.54, w * 0.70, h * 0.52, w * 0.92, h * 0.48);
    lowerLip.cubicTo(w * 0.82, h * 0.98, w * 0.18, h * 0.98, w * 0.08, h * 0.48);
    lowerLip.close();
    canvas.drawPath(lowerLip, fillPaint);

    // Lip Gloss Highlight
    final glossPath = Path();
    glossPath.moveTo(w * 0.30, h * 0.62);
    glossPath.cubicTo(w * 0.40, h * 0.76, w * 0.60, h * 0.76, w * 0.70, h * 0.62);
    glossPath.cubicTo(w * 0.60, h * 0.70, w * 0.40, h * 0.70, w * 0.30, h * 0.62);
    glossPath.close();
    canvas.drawPath(glossPath, glossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// HD Warm Hug Emblem Icon (Two Embracing Arms around a Heart)
class WarmHugIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const WarmHugIcon({
    super.key,
    this.size = 28,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HDWarmHugPainter(
          primaryColor: color ?? const Color(0xFFAB47BC),
        ),
      ),
    );
  }
}

class _HDWarmHugPainter extends CustomPainter {
  final Color primaryColor;

  _HDWarmHugPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Heart Path
    final heartPath = Path();
    heartPath.moveTo(w * 0.5, h * 0.85);
    heartPath.cubicTo(w * 0.08, h * 0.60, 0, h * 0.30, w * 0.26, h * 0.12);
    heartPath.cubicTo(w * 0.38, h * 0.04, w * 0.46, h * 0.10, w * 0.5, h * 0.20);
    heartPath.cubicTo(w * 0.54, h * 0.10, w * 0.62, h * 0.04, w * 0.74, h * 0.12);
    heartPath.cubicTo(w * 1.0, h * 0.30, w * 0.92, h * 0.60, w * 0.5, h * 0.85);
    heartPath.close();

    final heartPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          primaryColor == Colors.white
              ? Colors.white.withValues(alpha: 0.9)
              : const Color(0xFF8E24AA),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(heartPath, heartPaint);

    // Embracing Arms (Bold White wrapping stroke)
    final armColor = primaryColor == Colors.white ? primaryColor : Colors.white;
    final armPaint = Paint()
      ..color = armColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Left Arm Curve
    final leftArm = Path();
    leftArm.moveTo(w * 0.10, h * 0.40);
    leftArm.cubicTo(w * 0.16, h * 0.58, w * 0.36, h * 0.68, w * 0.54, h * 0.58);
    canvas.drawPath(leftArm, armPaint);

    // Right Arm Curve
    final rightArm = Path();
    rightArm.moveTo(w * 0.90, h * 0.40);
    rightArm.cubicTo(w * 0.84, h * 0.58, w * 0.64, h * 0.68, w * 0.46, h * 0.58);
    canvas.drawPath(rightArm, armPaint);

    // Hands at ends of arms
    final handPaint = Paint()
      ..color = armColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(Offset(w * 0.54, h * 0.58), w * 0.075, handPaint);
    canvas.drawCircle(Offset(w * 0.46, h * 0.58), w * 0.075, handPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Clean Animated Love Nudge Logo Widget (No overlapping icons)
class LoveNudgeLogoWidget extends StatefulWidget {
  final double size;
  final bool animate;
  final LoveNudgeIconType iconType;

  const LoveNudgeLogoWidget({
    super.key,
    this.size = 54,
    this.animate = true,
    this.iconType = LoveNudgeIconType.kiss,
  });

  @override
  State<LoveNudgeLogoWidget> createState() => _LoveNudgeLogoWidgetState();
}

class _LoveNudgeLogoWidgetState extends State<LoveNudgeLogoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.animate) {
      _pulseController.repeat(reverse: true);
    }

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: widget.iconType == LoveNudgeIconType.hug
                ? const [Color(0xFFAB47BC), Color(0xFF7B1FA2)]
                : const [Color(0xFFFF4081), Color(0xFFD81B60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (widget.iconType == LoveNudgeIconType.hug
                      ? const Color(0xFFAB47BC)
                      : const Color(0xFFFF4081))
                  .withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Top Right Sparkle Accent
              Positioned(
                right: s * 0.16,
                top: s * 0.14,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: s * 0.22,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              // Single Clean Centered Icon
              if (widget.iconType == LoveNudgeIconType.hug)
                WarmHugIcon(
                  size: s * 0.54,
                  color: Colors.white,
                )
              else if (widget.iconType == LoveNudgeIconType.heart)
                LoveNudgeHeaderIcon(
                  size: s * 0.54,
                  color: Colors.white,
                )
              else
                KissLipsIcon(
                  size: s * 0.52,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
