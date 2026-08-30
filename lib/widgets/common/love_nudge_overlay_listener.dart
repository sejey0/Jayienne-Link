import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../services/supabase_love_nudge_service.dart';

/// Global/Screen Wrapper that listens for real-time Love Nudges from the partner
/// and displays interactive live screen overlays with custom photos & particle cascades.
class LoveNudgeOverlayListener extends StatefulWidget {
  final Widget child;

  const LoveNudgeOverlayListener({
    super.key,
    required this.child,
  });

  /// Helper to display the live screen overlay locally for the sender as well
  static void showLocalNudgeEffect(BuildContext context, LoveNudgePayload nudge) {
    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => LoveNudgeLiveScreenOverlay(
        key: UniqueKey(),
        nudge: nudge,
        isLocalSender: true,
        onFinished: () {
          try {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          } catch (_) {}
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  @override
  State<LoveNudgeOverlayListener> createState() => _LoveNudgeOverlayListenerState();
}

class _LoveNudgeOverlayListenerState extends State<LoveNudgeOverlayListener> {
  StreamSubscription<LoveNudgePayload>? _nudgeSubscription;
  String? _currentSubscribedCoupleId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndSubscribe();
  }

  void _checkAndSubscribe() {
    final coupleProvider = context.watch<CoupleProvider>();
    final authProvider = context.watch<AuthProvider>();
    final couple = coupleProvider.couple;
    final currentUserId = authProvider.currentUserId;

    if (couple == null || currentUserId == null || couple.id == null) {
      _nudgeSubscription?.cancel();
      _nudgeSubscription = null;
      _currentSubscribedCoupleId = null;
      return;
    }

    if (_currentSubscribedCoupleId == couple.id) {
      return;
    }

    _currentSubscribedCoupleId = couple.id;
    _nudgeSubscription?.cancel();

    debugPrint('💖 [LoveNudgeOverlayListener] Listening to nudges for couple: ${couple.id}');
    _nudgeSubscription = SupabaseLoveNudgeService()
        .subscribeToLoveNudges(couple.id!)
        .listen((nudge) {
      if (!mounted) return;

      // Only trigger overlay if nudge is from partner
      if (nudge.senderId != currentUserId) {
        _handleIncomingPartnerNudge(nudge);
      }
    });
  }

  void _handleIncomingPartnerNudge(LoveNudgePayload nudge) {
    HapticFeedback.heavyImpact();

    // 1. Show Screen Floating Realtime Photo & Particle Burst Overlay
    _showLiveScreenOverlay(nudge);
  }

  void _showLiveScreenOverlay(LoveNudgePayload nudge) {
    if (!mounted) return;
    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => LoveNudgeLiveScreenOverlay(
        key: UniqueKey(),
        nudge: nudge,
        isLocalSender: false,
        onFinished: () {
          try {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          } catch (_) {}
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  @override
  void dispose() {
    _nudgeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Interactive Full-Screen Live Nudge Overlay featuring real-time photo card and particle stream
class LoveNudgeLiveScreenOverlay extends StatefulWidget {
  final LoveNudgePayload nudge;
  final bool isLocalSender;
  final VoidCallback onFinished;

  const LoveNudgeLiveScreenOverlay({
    super.key,
    required this.nudge,
    this.isLocalSender = false,
    required this.onFinished,
  });

  @override
  State<LoveNudgeLiveScreenOverlay> createState() => _LoveNudgeLiveScreenOverlayState();
}

class _LoveNudgeLiveScreenOverlayState extends State<LoveNudgeLiveScreenOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final List<_LoveParticle> _particles = [];
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();

    // 1. Entrance Bounce & Fade Controller
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );

    // 2. Continuous Heartbeat / Ambient Pulse Controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Ambient Floating Particle Animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _initParticles();
    _entryController.forward();

    // Auto-dismiss after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      _dismissOverlay();
    });
  }

  void _initParticles() {
    final isKiss = widget.nudge.nudgeType == 'kiss';
    final random = math.Random();

    final kissIcons = [
      Icons.favorite_rounded,
      Icons.favorite_border_rounded,
      Icons.auto_awesome,
      Icons.star_rounded,
      Icons.spa_rounded,
      Icons.flare_rounded,
    ];

    final kissColors = [
      const Color(0xFFFF4081),
      const Color(0xFFFF758C),
      const Color(0xFFFF2E93),
      const Color(0xFFFFB2C9),
      Colors.white,
    ];

    final hugIcons = [
      Icons.volunteer_activism_rounded,
      Icons.favorite_rounded,
      Icons.auto_awesome,
      Icons.all_inclusive_rounded,
      Icons.star_rounded,
      Icons.bubble_chart_rounded,
    ];

    final hugColors = [
      const Color(0xFFAB47BC),
      const Color(0xFFBA68C8),
      const Color(0xFF7C4DFF),
      const Color(0xFFCE93D8),
      Colors.white,
    ];

    final icons = isKiss ? kissIcons : hugIcons;
    final colors = isKiss ? kissColors : hugColors;

    for (int i = 0; i < 22; i++) {
      _particles.add(
        _LoveParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          speed: 0.15 + random.nextDouble() * 0.25,
          size: 14.0 + random.nextDouble() * 14.0,
          wobbleSpeed: 1.0 + random.nextDouble() * 2.0,
          wobbleAmount: 0.02 + random.nextDouble() * 0.04,
          opacity: 0.45 + random.nextDouble() * 0.45,
          icon: icons[random.nextInt(icons.length)],
          color: colors[random.nextInt(colors.length)],
        ),
      );
    }
  }

  void _dismissOverlay() {
    if (!mounted || _isDismissed) return;
    _isDismissed = true;
    _entryController.reverse().then((_) {
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Widget _buildPhotoWidget(String photoUrl) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? photoUrl.substring(commaIdx + 1) : photoUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {}
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      cacheKey: '${photoUrl}_${widget.nudge.timestamp}',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.white12,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFFFF758C),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black45,
        child: const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKiss = widget.nudge.nudgeType == 'kiss';
    final hasPhoto = widget.nudge.photoUrl != null && widget.nudge.photoUrl!.isNotEmpty;
    final hasMessage = widget.nudge.message != null && widget.nudge.message!.trim().isNotEmpty;

    final primaryColor = isKiss ? const Color(0xFFFF3377) : const Color(0xFFAB47BC);
    final secondaryColor = isKiss ? const Color(0xFFFF758C) : const Color(0xFF7C4DFF);
    final accentGlow = isKiss ? const Color(0xFFFF2E93) : const Color(0xFF8E24AA);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Frosted Backdrop Blur & Ambient Glow with tap-to-dismiss
          GestureDetector(
            onTap: _dismissOverlay,
            behavior: HitTestBehavior.opaque,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 16 * value,
                    sigmaY: 16 * value,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 1.1,
                        colors: [
                          accentGlow.withValues(alpha: 0.32 * value),
                          Colors.black.withValues(alpha: 0.65 * value),
                          Colors.black.withValues(alpha: 0.85 * value),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Animated Floating Particle Stream
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _LoveParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                );
              },
            ),
          ),

          // 3. Central Pop-Up Hero Card
          Center(
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _scaleAnimation.value.clamp(0.0, 1.15),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: _dismissOverlay,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  constraints: const BoxConstraints(maxWidth: 350),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF261536),
                        Color(0xFF1B0D28),
                        Color(0xFF12071C),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.65),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentGlow.withValues(alpha: 0.42),
                        blurRadius: 36,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      children: [
                        // Subtle Top Glowing Orb in Card
                        Positioned(
                          top: -40,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 180,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                        ),

                        // Card Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Tag Pill Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isKiss ? Icons.favorite_rounded : Icons.volunteer_activism_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isKiss ? 'VIRTUAL KISS' : 'WARM HUG',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Main Header Title
                              Text(
                                widget.isLocalSender
                                    ? (isKiss ? 'Kiss Delivered!' : 'Warm Hug Delivered!')
                                    : (isKiss
                                        ? '${widget.nudge.senderName} sent you a Kiss'
                                        : '${widget.nudge.senderName} sent you a Warm Hug'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Subtitle
                              Text(
                                widget.isLocalSender
                                    ? 'Sent straight to your love'
                                    : 'A sweet reminder that you are loved',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Center Artwork: Photo or Heartbeat Emblem
                              if (hasPhoto) ...[
                                Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _buildPhotoWidget(widget.nudge.photoUrl!),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ] else ...[
                                // Animated Pulsating Romantic Emblem
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 115,
                                    height: 115,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          primaryColor.withValues(alpha: 0.4),
                                          primaryColor.withValues(alpha: 0.12),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 82,
                                        height: 82,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [primaryColor, secondaryColor],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accentGlow.withValues(alpha: 0.6),
                                              blurRadius: 22,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: isKiss
                                              ? const Icon(
                                                  Icons.favorite_rounded,
                                                  size: 42,
                                                  color: Colors.white,
                                                )
                                              : const Icon(
                                                  Icons.volunteer_activism_rounded,
                                                  size: 40,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Attached Sweet Message Love Note
                              if (hasMessage) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.35),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.format_quote_rounded,
                                            size: 14,
                                            color: secondaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Sweet Note',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: secondaryColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.nudge.message!.trim(),
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Close / Dismiss Hint Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app_rounded,
                                      size: 12,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Tap anywhere to close',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

/// Particle model for animated romantic floating cascade
class _LoveParticle {
  double x;
  double y;
  final double speed;
  final double size;
  final double wobbleSpeed;
  final double wobbleAmount;
  final double opacity;
  final IconData icon;
  final Color color;

  _LoveParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.wobbleSpeed,
    required this.wobbleAmount,
    required this.opacity,
    required this.icon,
    required this.color,
  });
}

/// Custom painter to render animated floating romantic icon particles smoothly
class _LoveParticlePainter extends CustomPainter {
  final List<_LoveParticle> particles;
  final double progress;

  _LoveParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Calculate current vertical position with wrap-around
      final currentY = (p.y - (progress * p.speed * 4)) % 1.0;
      final actualY = (currentY < 0 ? 1.0 + currentY : currentY) * size.height;

      // Calculate horizontal wobble using sine wave
      final wobble = math.sin((progress * 2 * math.pi * p.wobbleSpeed) + (p.x * 10)) *
          (p.wobbleAmount * size.width);
      final actualX = (p.x * size.width) + wobble;

      // Fade in near bottom, fade out near top
      double fade = 1.0;
      if (actualY < size.height * 0.18) {
        fade = (actualY / (size.height * 0.18)).clamp(0.0, 1.0);
      } else if (actualY > size.height * 0.85) {
        fade = ((size.height - actualY) / (size.height * 0.15)).clamp(0.0, 1.0);
      }

      final textSpan = TextSpan(
        text: String.fromCharCode(p.icon.codePoint),
        style: TextStyle(
          fontSize: p.size,
          fontFamily: p.icon.fontFamily,
          package: p.icon.fontPackage,
          color: p.color.withValues(alpha: (p.opacity * fade).clamp(0.0, 1.0)),
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(actualX - (textPainter.width / 2), actualY - (textPainter.height / 2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoveParticlePainter oldDelegate) => true;
}

