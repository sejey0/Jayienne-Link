import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

/// Ultra-Premium Romantic Sign In & Login Loading Screen
///
/// Features:
/// - Official App Logo in the center with breathing heartbeat animation & romantic heart backdrop
/// - Frosted glassmorphism card with glowing multi-layer gradient auras
/// - Floating ambient romantic particle drift (custom particle canvas)
/// - Rotating romantic status messages with smooth animated crossfade
/// - Polished glowing capsule progress indicator
/// - Interactive Developer Diagnostics preview controls (Light/Dark theme toggle & instant dismiss)
class SignInLoadingScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final bool isPreview;
  final VoidCallback? onCancel;

  const SignInLoadingScreen({
    super.key,
    this.title,
    this.subtitle,
    this.isPreview = false,
    this.onCancel,
  });

  @override
  State<SignInLoadingScreen> createState() => _SignInLoadingScreenState();
}

class _SignInLoadingScreenState extends State<SignInLoadingScreen>
    with TickerProviderStateMixin {
  // 1. Synchronized Heartbeat Animation Controllers (resilient against Hot Reload)
  AnimationController? _heartPulseController;
  AnimationController? _heartGlowController;
  Animation<double>? _logoHeartPulse;
  Animation<double>? _glowRadius;

  // 2. Ambient Particles & Shimmer
  AnimationController? _particlesController;
  AnimationController? _shimmerController;
  AnimationController? _dotsController;

  // 3. Dynamic Romantic Messages Cycling
  Timer? _messageTimer;
  int _currentMessageIndex = 0;

  final List<({String title, String subtitle})> _defaultMessages = const [
    (
      title: 'Opening Your Love Space',
      subtitle: 'Connecting hearts across the distance',
    ),
    (
      title: 'Unlocking Shared Memories',
      subtitle: 'Synchronizing your love letters and moments',
    ),
    (
      title: 'Preparing Your Private World',
      subtitle: 'Almost ready for you and your love',
    ),
  ];

  // Developer diagnostics theme toggle override
  bool? _previewDarkModeOverride;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startMessageTimer();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Re-initialize animations smoothly if hot reload is triggered while screen is open
    _initAnimations();
  }

  void _initAnimations() {
    _disposeControllers();

    // 1. Natural Diastole-Systole Heartbeat Pulse for App Logo
    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _logoHeartPulse = TweenSequence<double>([
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
    ]).animate(_heartPulseController!);

    // Glowing Aura Breathing Animation
    _heartGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowRadius = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(
        parent: _heartGlowController!,
        curve: Curves.easeInOut,
      ),
    );

    // 2. Ambient Particles Controller
    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    // 3. Shimmer Progress Controller
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // 4. Ellipsis Dots Controller
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _startMessageTimer() {
    _messageTimer?.cancel();
    if (widget.title == null) {
      _messageTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
        if (mounted) {
          setState(() {
            _currentMessageIndex =
                (_currentMessageIndex + 1) % _defaultMessages.length;
          });
        }
      });
    }
  }

  void _disposeControllers() {
    _heartPulseController?.dispose();
    _heartGlowController?.dispose();
    _particlesController?.dispose();
    _shimmerController?.dispose();
    _dotsController?.dispose();
    _heartPulseController = null;
    _heartGlowController = null;
    _particlesController = null;
    _shimmerController = null;
    _dotsController = null;
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Self-healing check: ensure animations exist even after hot reload
    if (_glowRadius == null || _heartPulseController == null || _logoHeartPulse == null) {
      _initAnimations();
    }

    final systemDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = _previewDarkModeOverride ?? systemDark;

    // Signature Romantic Color Palette
    const rosePink = Color(0xFFFF758C);
    const softLavender = Color(0xFFA18CD1);
    const deepPlum = Color(0xFF140D1C);
    const nocturnalNavy = Color(0xFF1E1128);

    // Background Palette
    final bgColors = isDark
        ? const [deepPlum, nocturnalNavy, Color(0xFF0F0816)]
        : const [Color(0xFFFFF7F9), Color(0xFFFDEEF2), Color(0xFFFBF0F6)];

    final titleColor = isDark ? Colors.white : const Color(0xFF2C1930);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF6E5676);

    // Active title & subtitle
    final activeTitle = widget.title ?? _defaultMessages[_currentMessageIndex].title;
    final activeSubtitle =
        widget.subtitle ?? _defaultMessages[_currentMessageIndex].subtitle;

    return Scaffold(
      backgroundColor: bgColors.first,
      body: Stack(
        children: [
          // ==========================================
          // 1. ROMANTIC GRADIENT CANVAS & VIGNETTE
          // ==========================================
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

          // Luminous Ambient Radial Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowRadius!,
              builder: (context, _) {
                return Opacity(
                  opacity: _glowRadius!.value * (isDark ? 0.40 : 0.26),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.0, -0.15),
                        radius: 0.95,
                        colors: [
                          rosePink,
                          softLavender,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ==========================================
          // 2. FLOATING AMBIENT SPARKLE PARTICLES
          // ==========================================
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particlesController!,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RomanticParticlesPainter(
                    progress: _particlesController!.value,
                    primaryColor: rosePink,
                    secondaryColor: softLavender,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // ==========================================
          // 3. MAIN CENTERPIECE: APP LOGO IN HEART CARD
          // ==========================================
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Frosted Glassmorphism App Logo Centerpiece
                  _buildGlassmorphicLogoContainer(
                    isDark: isDark,
                    rosePink: rosePink,
                    softLavender: softLavender,
                  ),

                  const SizedBox(height: 36),

                  // Animated Status Typography with Ellipsis
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.15),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      key: ValueKey<String>(activeTitle),
                      children: [
                        // Title with Animated Dots
                        AnimatedBuilder(
                          animation: _dotsController!,
                          builder: (context, _) {
                            final dotCount =
                                (_dotsController!.value * 4).floor() % 4;
                            final dots = '.' * dotCount;
                            return Text(
                              '$activeTitle$dots',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.35,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        // Subtitle
                        Text(
                          activeSubtitle,
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
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sleek Romantic Capsule Progress Bar
                  _buildProgressCapsule(
                    isDark: isDark,
                    rosePink: rosePink,
                    softLavender: softLavender,
                  ),

                  // Optional Cancel Action
                  if (widget.onCancel != null) ...[
                    const SizedBox(height: 28),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onCancel?.call();
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel Sign In'),
                      style: TextButton.styleFrom(
                        foregroundColor: subtitleColor,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ==========================================
          // 4. DEVELOPER DIAGNOSTICS PREVIEW OVERLAY
          // ==========================================
          if (widget.isPreview) ...[
            // Top Preview Header Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dismiss Button with Glassmorphism
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.10),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 20,
                          ),
                          tooltip: 'Close Preview',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),

                  // Interactive Theme Switcher Button
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.10),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _previewDarkModeOverride = !isDark;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDark
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                size: 16,
                                color:
                                    isDark ? softLavender : rosePink,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isDark ? 'Dark Theme' : 'Light Theme',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Diagnostics Banner Pill
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.developer_mode_rounded,
                            size: 15,
                            color: rosePink,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Sign In Loading Preview - Developer Diagnostics',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: rosePink,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Centerpiece Glassmorphism Card with App Logo & Romantic Heart Backdrop
  Widget _buildGlassmorphicLogoContainer({
    required bool isDark,
    required Color rosePink,
    required Color softLavender,
  }) {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Luminous Outer Glowing Halo
          AnimatedBuilder(
            animation: _glowRadius!,
            builder: (context, _) {
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: rosePink.withValues(
                          alpha: _glowRadius!.value * (isDark ? 0.45 : 0.35)),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: softLavender.withValues(
                          alpha: _glowRadius!.value * (isDark ? 0.35 : 0.25)),
                      blurRadius: 48,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              );
            },
          ),

          // Frosted Glassmorphism Disc
          ClipRRect(
            borderRadius: BorderRadius.circular(85),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: 134,
                height: 134,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.65),
                  border: Border.all(
                    width: 1.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.85),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : rosePink.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Outer Soft Romantic Heart Backdrop
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Icon(
              Icons.favorite_rounded,
              size: 104,
              color: Colors.white.withValues(alpha: isDark ? 0.28 : 0.35),
            ),
          ),

          // Inner Romantic Heart Card
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: isDark
                  ? [const Color(0xFF281838), const Color(0xFF1B1028)]
                  : [Colors.white, const Color(0xFFFFF0F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Icon(
              Icons.favorite_rounded,
              size: 90,
              color: Colors.white,
            ),
          ),

          // Delicate Heart Border
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 90,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),

          // Official App Logo with Synchronized Heartbeat Breathing Animation
          AnimatedBuilder(
            animation: _logoHeartPulse!,
            builder: (context, _) {
              return Transform.scale(
                scale: _logoHeartPulse!.value,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Image.asset(
                    'assets/icon/road_to_forever, no bg.png',
                    width: 58,
                    height: 58,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Sleek Glowing Capsule Progress Indicator
  Widget _buildProgressCapsule({
    required bool isDark,
    required Color rosePink,
    required Color softLavender,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
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
                  gradient: LinearGradient(
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
    );
  }
}

/// Custom painter for romantic floating ambient particle drift
class _RomanticParticlesPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  // Fixed seeded relative particle trajectories
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

  _RomanticParticlesPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      // Particles drift upward smoothly with wraparound
      final currentYProgress = (progress * p.speed + (i * 0.12)) % 1.0;
      final y = size.height * (1.0 - currentYProgress);
      // Gentle horizontal wave oscillation
      final x = (size.width * p.x) + (12 * math.sin((progress * 2 * math.pi) + i));

      // Fade in near bottom and fade out near top
      final opacity = math.sin(currentYProgress * math.pi) * (isDark ? 0.65 : 0.40);

      final color = p.isPrimary ? primaryColor : secondaryColor;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.4);

      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RomanticParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
