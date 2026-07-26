import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../providers/couple_provider.dart';

/// Senior Instant Love Nudge Card with Floating Heart Particle Overlay Animation
class InstantLoveNudgeCard extends StatefulWidget {
  const InstantLoveNudgeCard({super.key});

  @override
  State<InstantLoveNudgeCard> createState() => _InstantLoveNudgeCardState();
}

class _InstantLoveNudgeCardState extends State<InstantLoveNudgeCard> {
  bool _isKissPressed = false;
  bool _isHugPressed = false;

  void _triggerNudge({required bool isKiss, required String partnerName}) {
    HapticFeedback.mediumImpact();

    // Spawn Floating Hearts Particle Overlay across screen
    _showFloatingHeartsOverlay(context, isKiss: isKiss);

    // Show romantic feedback banner
    final emoji = isKiss ? '💋' : '🤗';
    final actionText = isKiss ? 'Virtual Kiss' : 'Virtual Hug';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$actionText sent to $partnerName! $emoji',
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
    final coupleProvider = context.watch<CoupleProvider>();
    final partner = coupleProvider.partner;
    final partnerName = (partner != null && partner.displayName.isNotEmpty)
        ? partner.displayName
        : 'Aienne';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.softRose.withValues(alpha: 0.88),
              AppColors.lavender.withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.softRose.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instant Love Nudge',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap to send a quick virtual kiss or hug!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Two Action Nudge Buttons
            Row(
              children: [
                // Send Kiss Button
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _isKissPressed = true),
                    onTapUp: (_) {
                      setState(() => _isKissPressed = false);
                      _triggerNudge(isKiss: true, partnerName: partnerName);
                    },
                    onTapCancel: () => setState(() => _isKissPressed = false),
                    child: AnimatedScale(
                      scale: _isKissPressed ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('💋', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 6),
                            Text(
                              'Send Kiss',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send Hug Button
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _isHugPressed = true),
                    onTapUp: (_) {
                      setState(() => _isHugPressed = false);
                      _triggerNudge(isKiss: false, partnerName: partnerName);
                    },
                    onTapCancel: () => setState(() => _isHugPressed = false),
                    child: AnimatedScale(
                      scale: _isHugPressed ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade700.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🤗', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 6),
                            Text(
                              'Send Hug',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
          ],
        ),
      ),
    );
  }
}

/// Floating Particle Animation Widget spawned on Overlay
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

    // Generate 16 floating heart particles with random trajectories
    for (int i = 0; i < 16; i++) {
      _particles.add(
        _HeartParticle(
          xRatio: 0.1 + _random.nextDouble() * 0.8,
          startScale: 0.7 + _random.nextDouble() * 0.7,
          speedY: 250 + _random.nextDouble() * 300,
          driftX: (_random.nextDouble() - 0.5) * 120,
          icon: widget.isKiss
              ? (_random.nextBool() ? Icons.favorite_rounded : Icons.favorite_border_rounded)
              : Icons.favorite_rounded,
          color: widget.isKiss
              ? Color.lerp(const Color(0xFFFF4081), const Color(0xFFFF5252), _random.nextDouble())!
              : Color.lerp(const Color(0xFFAB47BC), const Color(0xFF7B1FA2), _random.nextDouble())!,
          emoji: widget.isKiss ? '💋' : '🤗',
          useEmoji: _random.nextDouble() < 0.35,
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
                    child: particle.useEmoji
                        ? Text(
                            particle.emoji,
                            style: const TextStyle(fontSize: 24),
                          )
                        : Icon(
                            particle.icon,
                            color: particle.color,
                            size: 26,
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
  final String emoji;
  final bool useEmoji;

  const _HeartParticle({
    required this.xRatio,
    required this.startScale,
    required this.speedY,
    required this.driftX,
    required this.icon,
    required this.color,
    required this.emoji,
    required this.useEmoji,
  });
}
