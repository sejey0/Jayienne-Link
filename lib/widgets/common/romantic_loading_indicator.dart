import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Senior Romantic Animated Loading Indicator & Screen
/// Features glowing pulsing gradient hearts, floating orbital particles, and smooth typography.
class RomanticLoadingIndicator extends StatefulWidget {
  final double size;
  final String? message;
  final bool showParticles;
  final Color? primaryColor;
  final Color? secondaryColor;

  const RomanticLoadingIndicator({
    super.key,
    this.size = 72.0,
    this.message = 'Loading your love space...',
    this.showParticles = true,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<RomanticLoadingIndicator> createState() =>
      _RomanticLoadingIndicatorState();
}

class _RomanticLoadingIndicatorState extends State<RomanticLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _orbitController;
  late final AnimationController _dotsController;

  late final Animation<double> _pulseScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    // 1. Heart Pulse Animation (mimicking a gentle heartbeat)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.06)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20,
      ),
    ]).animate(_pulseController);

    _glowOpacity = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // 2. Orbital Particles Rotation
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // 3. Loading Text Dots Animation (1, 2, 3 dots)
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.primaryColor ?? const Color(0xFFFF758C);
    final secondary = widget.secondaryColor ?? const Color(0xFFA18CD1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glowing Gradient Aura
              AnimatedBuilder(
                animation: _glowOpacity,
                builder: (context, _) {
                  return Container(
                    width: widget.size * 1.3,
                    height: widget.size * 1.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: _glowOpacity.value * 0.4),
                          blurRadius: 28,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: secondary.withValues(alpha: _glowOpacity.value * 0.3),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Orbital Sparkling Floating Dots
              if (widget.showParticles)
                AnimatedBuilder(
                  animation: _orbitController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(widget.size * 1.45, widget.size * 1.45),
                      painter: _OrbitalHeartsPainter(
                        progress: _orbitController.value,
                        primaryColor: primary,
                        secondaryColor: secondary,
                      ),
                    );
                  },
                ),

              // Pulsing Heart Centerpiece
              AnimatedBuilder(
                animation: _pulseScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseScale.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [primary, secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: widget.size * 0.54,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Animated Romantic Subtitle with Animated Ellipsis
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _dotsController,
            builder: (context, _) {
              final dotCount = (_dotsController.value * 4).floor() % 4;
              final dots = '.' * dotCount;
              return Text(
                '${widget.message!}$dots',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF6A5570),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Custom painter for smooth orbital particles revolving around the heart
class _OrbitalHeartsPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _OrbitalHeartsPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    const particleCount = 4;
    for (int i = 0; i < particleCount; i++) {
      final angle = (progress * 2 * math.pi) + (i * (2 * math.pi / particleCount));
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final particleRadius = (i % 2 == 0) ? 3.5 : 2.5;
      final color = (i % 2 == 0) ? primaryColor : secondaryColor;
      final opacity = 0.4 + 0.6 * math.sin(progress * 2 * math.pi + i);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.2, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(x, y), particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalHeartsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Fullscreen Romantic Loading Screen (Perfect for first login & screen transitions)
class RomanticLoadingScreen extends StatelessWidget {
  final String message;
  final String? subtitle;

  const RomanticLoadingScreen({
    super.key,
    this.message = 'Connecting your hearts...',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF140E1B) : const Color(0xFFFFF7F9),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RomanticLoadingIndicator(
                  size: 80,
                  message: null,
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF2C1930),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
