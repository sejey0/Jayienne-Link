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

                  // Hero Icon with Glowing Rings
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFF758C).withValues(alpha: 0.25),
                                const Color(0xFFA18CD1).withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF1E162B).withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.95),
                            border: Border.all(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: HeartAnimation(size: 64),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 24),

                  // App Title & Tagline
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    ).createShader(bounds),
                    child: const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(duration: 500.ms),

                  const SizedBox(height: 8),

                  Text(
                    AppStrings.appTagline,
                    style: GoogleFonts.playfairDisplay(
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFFA18CD1) : const Color(0xFF8E24AA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

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

                  // Bottom Romantic Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite, size: 14, color: Color(0xFFFF758C)),
                      const SizedBox(width: 6),
                      Text(
                        'Designed exclusively for couples',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
