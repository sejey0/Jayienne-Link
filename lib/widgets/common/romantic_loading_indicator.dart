import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Ultra-Premium Romantic Animated Loading Indicator
///
/// Features:
/// - Official App Logo in the center with authentic diastole-systole heartbeat pulse
/// - Layered romantic heart backdrop with soft gradient ShaderMask
/// - Frosted glassmorphic circular disc with multi-layer luminous glow
/// - Orbital revolving floating sparkle particles
/// - Animated typography with dancing ellipsis dots
class RomanticLoadingIndicator extends StatefulWidget {
  final double size;
  final String? message;
  final bool showParticles;
  final Color? primaryColor;
  final Color? secondaryColor;

  const RomanticLoadingIndicator({
    super.key,
    this.size = 76.0,
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
  AnimationController? _pulseController;
  AnimationController? _orbitController;
  AnimationController? _dotsController;

  Animation<double>? _pulseScale;
  Animation<double>? _glowOpacity;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Re-initialize animations smoothly on hot reload
    _initAnimations();
  }

  void _initAnimations() {
    _disposeControllers();

    // 1. Natural Diastole-Systole Heartbeat Pulse for App Logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 35,
      ),
    ]).animate(_pulseController!);

    // Glowing Aura Opacity
    _glowOpacity = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(
        parent: _pulseController!,
        curve: Curves.easeInOut,
      ),
    );

    // 2. Orbital Particles Rotation
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // 3. Loading Text Dots Animation
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _disposeControllers() {
    _pulseController?.dispose();
    _orbitController?.dispose();
    _dotsController?.dispose();
    _pulseController = null;
    _orbitController = null;
    _dotsController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pulseController == null || _pulseScale == null || _glowOpacity == null) {
      _initAnimations();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.primaryColor ?? const Color(0xFFFF758C);
    final secondary = widget.secondaryColor ?? const Color(0xFFA18CD1);

    final containerSize = widget.size * 1.5;
    final heartSize = widget.size * 1.1;
    final logoSize = widget.size * 0.62;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: containerSize,
          height: containerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Glowing Gradient Halo Aura
              AnimatedBuilder(
                animation: _glowOpacity!,
                builder: (context, _) {
                  return Container(
                    width: widget.size * 1.35,
                    height: widget.size * 1.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(
                              alpha: _glowOpacity!.value * (isDark ? 0.45 : 0.35)),
                          blurRadius: 32,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: secondary.withValues(
                              alpha: _glowOpacity!.value * (isDark ? 0.35 : 0.25)),
                          blurRadius: 40,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 2. Orbital Sparkling Floating Particles
              if (widget.showParticles && _orbitController != null)
                AnimatedBuilder(
                  animation: _orbitController!,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(widget.size * 1.45, widget.size * 1.45),
                      painter: _OrbitalHeartsPainter(
                        progress: _orbitController!.value,
                        primaryColor: primary,
                        secondaryColor: secondary,
                      ),
                    );
                  },
                ),

              // 3. Frosted Glassmorphism Disc
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.size * 0.75),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: widget.size * 1.25,
                    height: widget.size * 1.25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.65),
                      border: Border.all(
                        width: 1.4,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.30)
                              : primary.withValues(alpha: 0.16),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Outer Soft Romantic Heart Backdrop
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [primary, secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Icon(
                  Icons.favorite_rounded,
                  size: heartSize,
                  color: Colors.white.withValues(alpha: isDark ? 0.28 : 0.35),
                ),
              ),

              // 5. Inner Romantic Heart Card
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF281838), const Color(0xFF1B1028)]
                      : [Colors.white, const Color(0xFFFFF0F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Icon(
                  Icons.favorite_rounded,
                  size: heartSize * 0.86,
                  color: Colors.white,
                ),
              ),

              // 6. Delicate Heart Border
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [primary, secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Icon(
                  Icons.favorite_outline_rounded,
                  size: heartSize * 0.86,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),

              // 7. Official App Logo Centerpiece with Heartbeat Scale
              AnimatedBuilder(
                animation: _pulseScale!,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _pulseScale!.value,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Image.asset(
                        'assets/icon/road_to_forever, no bg.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Animated Romantic Message with Animated Dots
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _dotsController!,
            builder: (context, _) {
              final dotCount = (_dotsController!.value * 4).floor() % 4;
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

/// Custom painter for smooth orbital particles revolving around the centerpiece
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
      final angle =
          (progress * 2 * math.pi) + (i * (2 * math.pi / particleCount));
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

/// Fullscreen Romantic Loading Screen (Used on Home, Profile, Timeline, and screen transitions)
class RomanticLoadingScreen extends StatefulWidget {
  final String message;
  final String? subtitle;

  const RomanticLoadingScreen({
    super.key,
    this.message = 'Connecting your hearts...',
    this.subtitle,
  });

  @override
  State<RomanticLoadingScreen> createState() => _RomanticLoadingScreenState();
}

class _RomanticLoadingScreenState extends State<RomanticLoadingScreen>
    with TickerProviderStateMixin {
  AnimationController? _particlesController;
  AnimationController? _shimmerController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimations();
  }

  void _initAnimations() {
    _particlesController?.dispose();
    _shimmerController?.dispose();

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _particlesController?.dispose();
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particlesController == null || _shimmerController == null) {
      _initAnimations();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    const rosePink = Color(0xFFFF758C);
    const softLavender = Color(0xFFA18CD1);
    const deepPlum = Color(0xFF140D1C);
    const nocturnalNavy = Color(0xFF1E1128);

    final bgColors = isDark
        ? const [deepPlum, nocturnalNavy, Color(0xFF0F0816)]
        : const [Color(0xFFFFF7F9), Color(0xFFFDEEF2), Color(0xFFFBF0F6)];

    final titleColor = isDark ? Colors.white : const Color(0xFF2C1930);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF6E5676);

    return Scaffold(
      backgroundColor: bgColors.first,
      body: Stack(
        children: [
          // 1. Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bgColors,
                ),
              ),
            ),
          ),

          // 2. Floating Ambient Sparkle Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particlesController!,
              builder: (context, _) {
                return CustomPaint(
                  painter: _LoadingScreenParticlesPainter(
                    progress: _particlesController!.value,
                    primaryColor: rosePink,
                    secondaryColor: softLavender,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 3. Centerpiece & Typography
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RomanticLoadingIndicator(
                    size: 84,
                    message: null,
                    primaryColor: rosePink,
                    secondaryColor: softLavender,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.message,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 30),

                  // Sleek Romantic Capsule Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 140,
                      height: 5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      child: AnimatedBuilder(
                        animation: _shimmerController!,
                        builder: (context, _) {
                          return FractionallySizedBox(
                            alignment: Alignment(
                              -1.2 + (_shimmerController!.value * 2.4),
                              0.0,
                            ),
                            widthFactor: 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    rosePink,
                                    softLavender,
                                    rosePink,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: rosePink.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for romantic floating ambient particle drift on full screen loading
class _LoadingScreenParticlesPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  static final List<({double x, double speed, double size, bool isPrimary})>
      _particles = [
    (x: 0.15, speed: 1.0, size: 3.2, isPrimary: true),
    (x: 0.28, speed: 0.8, size: 2.2, isPrimary: false),
    (x: 0.42, speed: 1.2, size: 3.6, isPrimary: true),
    (x: 0.55, speed: 0.9, size: 2.5, isPrimary: false),
    (x: 0.68, speed: 1.1, size: 3.0, isPrimary: true),
    (x: 0.82, speed: 0.7, size: 2.0, isPrimary: false),
    (x: 0.22, speed: 1.3, size: 2.8, isPrimary: false),
    (x: 0.74, speed: 1.0, size: 3.4, isPrimary: true),
    (x: 0.35, speed: 0.85, size: 2.0, isPrimary: true),
    (x: 0.88, speed: 1.15, size: 2.6, isPrimary: false),
  ];

  _LoadingScreenParticlesPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final currentYProgress = (progress * p.speed + (i * 0.12)) % 1.0;
      final y = size.height * (1.0 - currentYProgress);
      final x =
          (size.width * p.x) + (12 * math.sin((progress * 2 * math.pi) + i));
      final opacity =
          math.sin(currentYProgress * math.pi) * (isDark ? 0.65 : 0.40);
      final color = p.isPrimary ? primaryColor : secondaryColor;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.4);

      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoadingScreenParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
