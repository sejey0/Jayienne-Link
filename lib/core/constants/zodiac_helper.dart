import 'dart:math' as math;
import 'package:flutter/material.dart';

class ZodiacInfo {
  final String name;
  final String dateRange;
  final String element;
  final Color color;

  const ZodiacInfo({
    required this.name,
    required this.dateRange,
    required this.element,
    required this.color,
  });
}

const List<ZodiacInfo> kZodiacSigns = [
  ZodiacInfo(name: 'Aries',       dateRange: 'Mar 21 – Apr 19', element: 'Fire',  color: Color(0xFFE53935)),
  ZodiacInfo(name: 'Taurus',      dateRange: 'Apr 20 – May 20', element: 'Earth', color: Color(0xFF43A047)),
  ZodiacInfo(name: 'Gemini',      dateRange: 'May 21 – Jun 20', element: 'Air',   color: Color(0xFFFDD835)),
  ZodiacInfo(name: 'Cancer',      dateRange: 'Jun 21 – Jul 22', element: 'Water', color: Color(0xFF1E88E5)),
  ZodiacInfo(name: 'Leo',         dateRange: 'Jul 23 – Aug 22', element: 'Fire',  color: Color(0xFFFB8C00)),
  ZodiacInfo(name: 'Virgo',       dateRange: 'Aug 23 – Sep 22', element: 'Earth', color: Color(0xFF8BC34A)),
  ZodiacInfo(name: 'Libra',       dateRange: 'Sep 23 – Oct 22', element: 'Air',   color: Color(0xFFEC407A)),
  ZodiacInfo(name: 'Scorpio',     dateRange: 'Oct 23 – Nov 21', element: 'Water', color: Color(0xFF6D4C41)),
  ZodiacInfo(name: 'Sagittarius', dateRange: 'Nov 22 – Dec 21', element: 'Fire',  color: Color(0xFF7B1FA2)),
  ZodiacInfo(name: 'Capricorn',   dateRange: 'Dec 22 – Jan 19', element: 'Earth', color: Color(0xFF455A64)),
  ZodiacInfo(name: 'Aquarius',    dateRange: 'Jan 20 – Feb 18', element: 'Air',   color: Color(0xFF039BE5)),
  ZodiacInfo(name: 'Pisces',      dateRange: 'Feb 19 – Mar 20', element: 'Water', color: Color(0xFF5C6BC0)),
];

class ZodiacHelper {
  static ZodiacInfo? getZodiac(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final lower = name.trim().toLowerCase();
    for (final z in kZodiacSigns) {
      if (z.name.toLowerCase() == lower) return z;
    }
    return null;
  }
}

/// A crisp, modern vector icon for any zodiac sign (No Emojis)
class ZodiacIcon extends StatelessWidget {
  final String zodiac;
  final double size;
  final Color? color;
  final double strokeWidth;

  const ZodiacIcon({
    super.key,
    required this.zodiac,
    this.size = 24,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ZodiacPainter(
          zodiac: zodiac.trim().toLowerCase(),
          color: themeColor,
          strokeWidth: strokeWidth * (size / 24.0),
        ),
      ),
    );
  }
}

class _ZodiacPainter extends CustomPainter {
  final String zodiac;
  final Color color;
  final double strokeWidth;

  _ZodiacPainter({
    required this.zodiac,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, strokeWidth)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    switch (zodiac) {
      case 'aries':
        _paintAries(canvas, paint, w, h);
        break;
      case 'taurus':
        _paintTaurus(canvas, paint, w, h);
        break;
      case 'gemini':
        _paintGemini(canvas, paint, w, h);
        break;
      case 'cancer':
        _paintCancer(canvas, paint, w, h);
        break;
      case 'leo':
        _paintLeo(canvas, paint, w, h);
        break;
      case 'virgo':
        _paintVirgo(canvas, paint, w, h);
        break;
      case 'libra':
        _paintLibra(canvas, paint, w, h);
        break;
      case 'scorpio':
        _paintScorpio(canvas, paint, fillPaint, w, h);
        break;
      case 'sagittarius':
        _paintSagittarius(canvas, paint, w, h);
        break;
      case 'capricorn':
        _paintCapricorn(canvas, paint, w, h);
        break;
      case 'aquarius':
        _paintAquarius(canvas, paint, w, h);
        break;
      case 'pisces':
        _paintPisces(canvas, paint, w, h);
        break;
      default:
        // Default star icon fallback
        final path = Path();
        path.moveTo(w * 0.5, h * 0.1);
        path.lineTo(w * 0.62, h * 0.38);
        path.lineTo(w * 0.92, h * 0.38);
        path.lineTo(w * 0.68, h * 0.56);
        path.lineTo(w * 0.77, h * 0.85);
        path.lineTo(w * 0.5, h * 0.67);
        path.lineTo(w * 0.23, h * 0.85);
        path.lineTo(w * 0.32, h * 0.56);
        path.lineTo(w * 0.08, h * 0.38);
        path.lineTo(w * 0.38, h * 0.38);
        path.close();
        canvas.drawPath(path, paint);
    }
  }

  void _paintAries(Canvas canvas, Paint paint, double w, double h) {
    // Left horn
    final pathLeft = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..lineTo(w * 0.5, h * 0.45)
      ..cubicTo(w * 0.45, h * 0.18, w * 0.15, h * 0.15, w * 0.12, h * 0.42);
    canvas.drawPath(pathLeft, paint);

    // Right horn
    final pathRight = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..lineTo(w * 0.5, h * 0.45)
      ..cubicTo(w * 0.55, h * 0.18, w * 0.85, h * 0.15, w * 0.88, h * 0.42);
    canvas.drawPath(pathRight, paint);
  }

  void _paintTaurus(Canvas canvas, Paint paint, double w, double h) {
    // Head circle
    canvas.drawCircle(Offset(w * 0.5, h * 0.62), w * 0.26, paint);

    // Horns
    final horns = Path()
      ..moveTo(w * 0.18, h * 0.18)
      ..cubicTo(w * 0.28, h * 0.36, w * 0.72, h * 0.36, w * 0.82, h * 0.18);
    canvas.drawPath(horns, paint);
  }

  void _paintGemini(Canvas canvas, Paint paint, double w, double h) {
    // Top arch
    final top = Path()
      ..moveTo(w * 0.15, h * 0.18)
      ..quadraticBezierTo(w * 0.5, h * 0.28, w * 0.85, h * 0.18);
    canvas.drawPath(top, paint);

    // Bottom arch
    final bottom = Path()
      ..moveTo(w * 0.15, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.72, w * 0.85, h * 0.82);
    canvas.drawPath(bottom, paint);

    // Vertical pillars
    canvas.drawLine(Offset(w * 0.35, h * 0.25), Offset(w * 0.35, h * 0.75), paint);
    canvas.drawLine(Offset(w * 0.65, h * 0.25), Offset(w * 0.65, h * 0.75), paint);
  }

  void _paintCancer(Canvas canvas, Paint paint, double w, double h) {
    // Top circle & claw
    canvas.drawCircle(Offset(w * 0.32, h * 0.34), w * 0.14, paint);
    final topClaw = Path()
      ..moveTo(w * 0.32, h * 0.20)
      ..cubicTo(w * 0.65, h * 0.16, w * 0.86, h * 0.32, w * 0.75, h * 0.45);
    canvas.drawPath(topClaw, paint);

    // Bottom circle & claw
    canvas.drawCircle(Offset(w * 0.68, h * 0.66), w * 0.14, paint);
    final bottomClaw = Path()
      ..moveTo(w * 0.68, h * 0.80)
      ..cubicTo(w * 0.35, h * 0.84, w * 0.14, h * 0.68, w * 0.25, h * 0.55);
    canvas.drawPath(bottomClaw, paint);
  }

  void _paintLeo(Canvas canvas, Paint paint, double w, double h) {
    // Head circle
    canvas.drawCircle(Offset(w * 0.25, h * 0.68), w * 0.13, paint);

    // Mane arch & tail
    final mane = Path()
      ..moveTo(w * 0.25, h * 0.55)
      ..cubicTo(w * 0.25, h * 0.18, w * 0.68, h * 0.12, w * 0.68, h * 0.48)
      ..cubicTo(w * 0.68, h * 0.75, w * 0.88, h * 0.75, w * 0.88, h * 0.85);
    canvas.drawPath(mane, paint);
  }

  void _paintVirgo(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      // First M loop
      ..moveTo(w * 0.12, h * 0.80)
      ..lineTo(w * 0.12, h * 0.32)
      ..cubicTo(w * 0.12, h * 0.18, w * 0.34, h * 0.18, w * 0.34, h * 0.32)
      ..lineTo(w * 0.34, h * 0.80)
      // Second M loop
      ..moveTo(w * 0.34, h * 0.32)
      ..cubicTo(w * 0.34, h * 0.18, w * 0.56, h * 0.18, w * 0.56, h * 0.32)
      ..lineTo(w * 0.56, h * 0.80)
      // Third stroke with loop cross
      ..moveTo(w * 0.56, h * 0.32)
      ..cubicTo(w * 0.56, h * 0.18, w * 0.76, h * 0.18, w * 0.76, h * 0.45)
      ..lineTo(w * 0.76, h * 0.85)
      ..cubicTo(w * 0.76, h * 0.95, w * 0.62, h * 0.95, w * 0.62, h * 0.70)
      ..lineTo(w * 0.88, h * 0.70);
    canvas.drawPath(path, paint);
  }

  void _paintLibra(Canvas canvas, Paint paint, double w, double h) {
    // Bottom line
    canvas.drawLine(Offset(w * 0.12, h * 0.82), Offset(w * 0.88, h * 0.82), paint);

    // Upper scale arch
    final top = Path()
      ..moveTo(w * 0.12, h * 0.48)
      ..lineTo(w * 0.32, h * 0.48)
      ..cubicTo(w * 0.32, h * 0.18, w * 0.68, h * 0.18, w * 0.68, h * 0.48)
      ..lineTo(w * 0.88, h * 0.48);
    canvas.drawPath(top, paint);
  }

  void _paintScorpio(Canvas canvas, Paint paint, Paint fillPaint, double w, double h) {
    final path = Path()
      // First M loop
      ..moveTo(w * 0.12, h * 0.80)
      ..lineTo(w * 0.12, h * 0.32)
      ..cubicTo(w * 0.12, h * 0.18, w * 0.34, h * 0.18, w * 0.34, h * 0.32)
      ..lineTo(w * 0.34, h * 0.80)
      // Second M loop
      ..moveTo(w * 0.34, h * 0.32)
      ..cubicTo(w * 0.34, h * 0.18, w * 0.56, h * 0.18, w * 0.56, h * 0.32)
      ..lineTo(w * 0.56, h * 0.80)
      // Third stroke with stinger tail
      ..moveTo(w * 0.56, h * 0.32)
      ..cubicTo(w * 0.56, h * 0.18, w * 0.78, h * 0.18, w * 0.78, h * 0.45)
      ..lineTo(w * 0.78, h * 0.75)
      ..cubicTo(w * 0.78, h * 0.88, w * 0.88, h * 0.88, w * 0.92, h * 0.72);
    canvas.drawPath(path, paint);

    // Arrow tip on tail
    final arrow = Path()
      ..moveTo(w * 0.84, h * 0.66)
      ..lineTo(w * 0.95, h * 0.68)
      ..lineTo(w * 0.93, h * 0.80)
      ..close();
    canvas.drawPath(arrow, fillPaint);
  }

  void _paintSagittarius(Canvas canvas, Paint paint, double w, double h) {
    // Diagonal shaft
    canvas.drawLine(Offset(w * 0.18, h * 0.82), Offset(w * 0.82, h * 0.18), paint);

    // Arrow head
    final head = Path()
      ..moveTo(w * 0.52, h * 0.18)
      ..lineTo(w * 0.82, h * 0.18)
      ..lineTo(w * 0.82, h * 0.48);
    canvas.drawPath(head, paint);

    // Crossbar
    canvas.drawLine(Offset(w * 0.32, h * 0.48), Offset(w * 0.52, h * 0.68), paint);
  }

  void _paintCapricorn(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      // Left V / Horn
      ..moveTo(w * 0.15, h * 0.28)
      ..lineTo(w * 0.35, h * 0.82)
      ..lineTo(w * 0.55, h * 0.28)
      // Fish tail loop
      ..cubicTo(w * 0.72, h * 0.28, w * 0.88, h * 0.48, w * 0.78, h * 0.72)
      ..cubicTo(w * 0.68, h * 0.95, w * 0.55, h * 0.80, w * 0.62, h * 0.65)
      ..cubicTo(w * 0.68, h * 0.52, w * 0.85, h * 0.62, w * 0.85, h * 0.85);
    canvas.drawPath(path, paint);
  }

  void _paintAquarius(Canvas canvas, Paint paint, double w, double h) {
    // Upper water wave
    final wave1 = Path()
      ..moveTo(w * 0.12, h * 0.38)
      ..lineTo(w * 0.30, h * 0.25)
      ..lineTo(w * 0.50, h * 0.38)
      ..lineTo(w * 0.70, h * 0.25)
      ..lineTo(w * 0.88, h * 0.38);
    canvas.drawPath(wave1, paint);

    // Lower water wave
    final wave2 = Path()
      ..moveTo(w * 0.12, h * 0.65)
      ..lineTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.50, h * 0.65)
      ..lineTo(w * 0.70, h * 0.52)
      ..lineTo(w * 0.88, h * 0.65);
    canvas.drawPath(wave2, paint);
  }

  void _paintPisces(Canvas canvas, Paint paint, double w, double h) {
    // Left fish arc
    final left = Path()
      ..moveTo(w * 0.35, h * 0.18)
      ..quadraticBezierTo(w * 0.15, h * 0.50, w * 0.35, h * 0.82);
    canvas.drawPath(left, paint);

    // Right fish arc
    final right = Path()
      ..moveTo(w * 0.65, h * 0.18)
      ..quadraticBezierTo(w * 0.85, h * 0.50, w * 0.65, h * 0.82);
    canvas.drawPath(right, paint);

    // Connecting band
    canvas.drawLine(Offset(w * 0.18, h * 0.50), Offset(w * 0.82, h * 0.50), paint);
  }

  @override
  bool shouldRepaint(covariant _ZodiacPainter oldDelegate) {
    return oldDelegate.zodiac != zodiac ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
