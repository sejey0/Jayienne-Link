import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../widgets/common/heart_animation.dart';

/// Redesigned Romantic Preview Welcome Screen with
/// Signature Ambient Glow, Feature Badges, and Glassmorphism Actions
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canGoBack = kDebugMode && Navigator.canPop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF140E1B) : const Color(0xFFFFF7F9),
      body: Stack(
        children: [
          // 1. Ambient Background Gradient Accents
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF758C).withValues(alpha: isDark ? 0.25 : 0.35),
                    const Color(0xFFFF758C).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA18CD1).withValues(alpha: isDark ? 0.25 : 0.3),
                    const Color(0xFFA18CD1).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  if (canGoBack) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFFFF758C),
                            size: 18,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  // Hero Section: Winding Road to Forever leading into the Beating Heart Emblem
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Winding Romantic Road Path behind and leading to the heart
                        Positioned(
                          bottom: -40,
                          child: SizedBox(
                            width: 240,
                            height: 120,
                            child: CustomPaint(
                              painter: RomanticRoadPainter(isDark: isDark),
                            ),
                          ),
                        ),

                        // Beating Heart Emblem Container
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient Outer Heart Glow
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 290,
                                color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.45),
                              ),
                            ),
                            // Inner Romantic Heart Card
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF261A34), const Color(0xFF191124)]
                                    : [Colors.white, const Color(0xFFFFF0F5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.favorite_rounded,
                                size: 250,
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
                                size: 250,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                            // Content Inside Heart: Logo + Name + Tagline Quote
                            Padding(
                              padding: const EdgeInsets.only(top: 28.0, left: 24, right: 24),
                              child: SizedBox(
                                width: 200,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // App Logo
                                    Image.asset(
                                      'assets/icon/road_to_forever, no bg.png',
                                      width: 66,
                                      height: 66,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 6),

                                    // App Name inside Heart
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      child: const Text(
                                        AppStrings.appName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 3),

                                    // Quote inside Heart
                                    Text(
                                      AppStrings.appTagline,
                                      style: GoogleFonts.playfairDisplay(
                                        textStyle: TextStyle(
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                          color: isDark
                                              ? const Color(0xFFA18CD1)
                                              : const Color(0xFF8E24AA),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                            .animate(onPlay: (controller) => controller.repeat(reverse: true))
                            .scale(
                              begin: const Offset(1.0, 1.0),
                              end: const Offset(1.06, 1.06),
                              duration: 950.ms,
                              curve: Curves.easeInOut,
                            ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Primary Button: Get Started (Register)
                  _buildPrimaryActionButton(
                    context,
                    label: 'Get Started with Email',
                    icon: Icons.favorite_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push(RouteNames.register);
                    },
                  ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 14),

                  // Secondary Button: Sign In
                  _buildSecondaryActionButton(
                    context,
                    label: 'I Already Have an Account',
                    icon: Icons.login_rounded,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push(RouteNames.login);
                    },
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.2, end: 0),

                  const Spacer(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF758C).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFF758C).withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFF758C), size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.deepCharcoal,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the winding romantic "Road to Forever" pathway
class RomanticRoadPainter extends CustomPainter {
  final bool isDark;

  const RomanticRoadPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Graceful S-curve road path leading into the bottom of the heart
    final roadPath = Path();
    roadPath.moveTo(w * 0.12, h * 0.95);
    roadPath.cubicTo(
      w * 0.02, h * 0.60,
      w * 0.92, h * 0.40,
      w * 0.50, h * 0.05,
    );

    // Glowing road aura
    final glowPaint = Paint()
      ..color = const Color(0xFFFF758C).withValues(alpha: isDark ? 0.22 : 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(roadPath, glowPaint);

    // Road gradient ribbon
    final roadPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x00FF758C),
          Color(0x88FF758C),
          Color(0xFFA18CD1),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(roadPath, roadPaint);

    // Dashed center road markings
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.7 : 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final metrics = roadPath.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      const dashWidth = 5.0;
      const dashSpace = 4.0;
      while (distance < metric.length) {
        final extractPath =
            metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, dashPaint);
        distance += dashWidth + dashSpace;
      }

      // Glowing heart milestone dots along the road
      final milestoneT = [0.25, 0.55, 0.82];
      for (final t in milestoneT) {
        final tangent = metric.getTangentForOffset(metric.length * t);
        if (tangent != null) {
          final haloPaint = Paint()
            ..color = const Color(0xFFFF758C).withValues(alpha: 0.5)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(tangent.position, 5.5, haloPaint);

          final dotPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(tangent.position, 2.5, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant RomanticRoadPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
