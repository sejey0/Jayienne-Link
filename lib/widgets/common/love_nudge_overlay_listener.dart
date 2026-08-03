import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../services/supabase_love_nudge_service.dart';
import 'love_nudge_logo_widget.dart';

/// Global/Screen Wrapper that listens for real-time Love Nudges from the partner
/// and triggers screen particle bursts & floating banners when received.
class LoveNudgeOverlayListener extends StatefulWidget {
  final Widget child;

  const LoveNudgeOverlayListener({
    super.key,
    required this.child,
  });

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

    final isKiss = nudge.nudgeType == 'kiss';
    final actionText = isKiss ? 'Virtual Kiss' : 'Virtual Hug';

    // 1. Show Screen Floating Particle Burst Overlay
    _showParticleOverlay(isKiss: isKiss);

    // 2. Show Floating Top Banner SnackBar / Pop-up Notification
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const LoveNudgeLogoWidget(size: 32, animate: false),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incoming Love Nudge! 💖',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        '${nudge.senderName} sent you a $actionText ${isKiss ? "💋" : "🫂"}!',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: isKiss ? AppColors.softRose : const Color(0xFF8E24AA),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
    }
  }

  void _showParticleOverlay({required bool isKiss}) {
    if (!mounted) return;
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _LoveNudgeParticleBurstWidget(
        isKiss: isKiss,
        onFinished: () {
          overlayEntry.remove();
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

/// Particle Burst Animation Widget that floats floating hearts across partner's screen
class _LoveNudgeParticleBurstWidget extends StatefulWidget {
  final bool isKiss;
  final VoidCallback onFinished;

  const _LoveNudgeParticleBurstWidget({
    required this.isKiss,
    required this.onFinished,
  });

  @override
  State<_LoveNudgeParticleBurstWidget> createState() =>
      __LoveNudgeParticleBurstWidgetState();
}

class __LoveNudgeParticleBurstWidgetState
    extends State<_LoveNudgeParticleBurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ParticleItem> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward().then((_) => widget.onFinished());

    final random = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < 28; i++) {
      _particles.add(_ParticleItem(
        x: ((random * (i + 1)) % 100) / 100.0,
        speed: 0.6 + (((random * (i + 3)) % 100) / 100.0) * 0.8,
        size: 18.0 + ((random * (i + 5)) % 22),
        isIcon: i % 2 == 0,
      ));
    }
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
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Stack(
              children: _particles.map((p) {
                final topPos = screenSize.height * (1.0 - (progress * p.speed));
                final leftPos = screenSize.width * p.x;

                return Positioned(
                  left: leftPos,
                  top: topPos,
                  child: p.isIcon && widget.isKiss
                      ? KissLipsIcon(size: p.size, showGlow: true)
                      : Icon(
                          Icons.favorite_rounded,
                          size: p.size,
                          color: widget.isKiss
                              ? AppColors.softRose
                              : const Color(0xFFAB47BC),
                        ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _ParticleItem {
  final double x;
  final double speed;
  final double size;
  final bool isIcon;

  _ParticleItem({
    required this.x,
    required this.speed,
    required this.size,
    required this.isIcon,
  });
}
