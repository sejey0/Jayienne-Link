import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../providers/couple_provider.dart';

/// Vector Kiss Lips Mark Painter guaranteeing 100% crisp visibility across ALL devices & themes
class KissLipsIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KissLipsIcon({
    super.key,
    this.size = 26,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.75,
      child: CustomPaint(
        painter: _KissLipsPainter(color: color),
      ),
    );
  }
}

class _KissLipsPainter extends CustomPainter {
  final Color color;

  _KissLipsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Top Lip
    final topLip = Path();
    topLip.moveTo(0, h * 0.45);
    topLip.cubicTo(w * 0.22, h * 0.05, w * 0.38, h * 0.35, w * 0.5, h * 0.22);
    topLip.cubicTo(w * 0.62, h * 0.35, w * 0.78, h * 0.05, w, h * 0.45);
    topLip.cubicTo(w * 0.75, h * 0.52, w * 0.5, h * 0.42, w * 0.5, h * 0.42);
    topLip.cubicTo(w * 0.5, h * 0.42, w * 0.25, h * 0.52, 0, h * 0.45);
    topLip.close();
    canvas.drawPath(topLip, paint);

    // Bottom Lip
    final bottomLip = Path();
    bottomLip.moveTo(w * 0.08, h * 0.50);
    bottomLip.cubicTo(w * 0.3, h * 0.52, w * 0.5, h * 0.54, w * 0.5, h * 0.54);
    bottomLip.cubicTo(w * 0.5, h * 0.54, w * 0.7, h * 0.52, w * 0.92, h * 0.50);
    bottomLip.cubicTo(w * 0.8, h * 0.98, w * 0.2, h * 0.98, w * 0.08, h * 0.50);
    bottomLip.close();
    canvas.drawPath(bottomLip, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Senior Love Nudge Screen with Back Button returning to Features Selection Sheet
class LoveNudgeScreen extends StatefulWidget {
  const LoveNudgeScreen({super.key});

  @override
  State<LoveNudgeScreen> createState() => _LoveNudgeScreenState();
}

class _LoveNudgeScreenState extends State<LoveNudgeScreen> {
  bool _isKissPressed = false;
  bool _isHugPressed = false;

  void _triggerNudge({required bool isKiss, required String partnerName}) {
    HapticFeedback.mediumImpact();

    // Spawn Floating Hearts Particle Overlay across screen
    _showFloatingHeartsOverlay(context, isKiss: isKiss);

    final actionText = isKiss ? 'Virtual Kiss' : 'Virtual Hug';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              isKiss
                  ? const KissLipsIcon(size: 22, color: Colors.white)
                  : const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$actionText sent to $partnerName!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isKiss ? AppColors.softRose : const Color(0xFF8E24AA),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  void _showFloatingHeartsOverlay(BuildContext context, {required bool isKiss}) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _FloatingHeartsParticleWidget(
        isKiss: isKiss,
        onFinished: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.watch<CoupleProvider>();
    final partner = coupleProvider.partner;
    final partnerName = (partner != null && partner.displayName.isNotEmpty)
        ? partner.displayName
        : 'Aienne';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Love Nudge ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            KissLipsIcon(size: 20, color: Colors.white),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.softRose, AppColors.lavender],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Big Hero Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.softRose.withValues(alpha: 0.9),
                      AppColors.lavender.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softRose.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const KissLipsIcon(size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Send a Touch to $partnerName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap below to send a virtual kiss or hug with live floating screen effects!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Send Kiss Card Option
              GestureDetector(
                onTapDown: (_) => setState(() => _isKissPressed = true),
                onTapUp: (_) {
                  setState(() => _isKissPressed = false);
                  _triggerNudge(isKiss: true, partnerName: partnerName);
                },
                onTapCancel: () => setState(() => _isKissPressed = false),
                child: AnimatedScale(
                  scale: _isKissPressed ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.softRose.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.softRose.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4081), Color(0xFFFF5252)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4081).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const KissLipsIcon(size: 30, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Send Virtual Kiss ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const KissLipsIcon(
                                    size: 18,
                                    color: Color(0xFFFF4081),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Spawns flying rose hearts across screen',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.softRose,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Send Hug Card Option
              GestureDetector(
                onTapDown: (_) => setState(() => _isHugPressed = true),
                onTapUp: (_) {
                  setState(() => _isHugPressed = false);
                  _triggerNudge(isKiss: false, partnerName: partnerName);
                },
                onTapCancel: () => setState(() => _isHugPressed = false),
                child: AnimatedScale(
                  scale: _isHugPressed ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.lavender.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.lavender.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB47BC).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Warm Hug 🤗',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Spawns floating purple heart particles',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.lavender,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingHeartsParticleWidget extends StatefulWidget {
  final bool isKiss;
  final VoidCallback onFinished;

  const _FloatingHeartsParticleWidget({
    required this.isKiss,
    required this.onFinished,
  });

  @override
  State<_FloatingHeartsParticleWidget> createState() =>
      _FloatingHeartsParticleWidgetState();
}

class _FloatingHeartsParticleWidgetState
    extends State<_FloatingHeartsParticleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_HeartParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    for (int i = 0; i < 18; i++) {
      _particles.add(
        _HeartParticle(
          xRatio: 0.1 + _random.nextDouble() * 0.8,
          startScale: 0.7 + _random.nextDouble() * 0.7,
          speedY: 250 + _random.nextDouble() * 320,
          driftX: (_random.nextDouble() - 0.5) * 130,
          icon: widget.isKiss
              ? (_random.nextBool() ? Icons.favorite_rounded : Icons.favorite_border_rounded)
              : Icons.favorite_rounded,
          color: widget.isKiss
              ? Color.lerp(const Color(0xFFFF4081), const Color(0xFFFF5252), _random.nextDouble())!
              : Color.lerp(const Color(0xFFAB47BC), const Color(0xFF7B1FA2), _random.nextDouble())!,
          useKissMark: widget.isKiss && _random.nextDouble() < 0.4,
        ),
      );
    }

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return IgnorePointer(
          child: Stack(
            children: _particles.map((particle) {
              final currentY = screenSize.height * 0.7 - (particle.speedY * progress);
              final currentX = screenSize.width * particle.xRatio + (particle.driftX * progress);

              return Positioned(
                left: currentX,
                top: currentY,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: particle.startScale * (1.0 + progress * 0.3),
                    child: particle.useKissMark
                        ? KissLipsIcon(size: 26, color: particle.color)
                        : Icon(
                            particle.icon,
                            color: particle.color,
                            size: 28,
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _HeartParticle {
  final double xRatio;
  final double startScale;
  final double speedY;
  final double driftX;
  final IconData icon;
  final Color color;
  final bool useKissMark;

  const _HeartParticle({
    required this.xRatio,
    required this.startScale,
    required this.speedY,
    required this.driftX,
    required this.icon,
    required this.color,
    required this.useKissMark,
  });
}
