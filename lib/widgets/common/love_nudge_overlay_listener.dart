import 'dart:async';
import 'dart:convert';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _cardController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();

    // 1. Photo Card Animation
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    );

    _cardController.forward();

    // Auto-dismiss after 4.2 seconds
    Future.delayed(const Duration(milliseconds: 4200), () {
      _dismissOverlay();
    });
  }

  void _dismissOverlay() {
    if (!mounted || _isDismissed) return;
    _isDismissed = true;
    _cardController.reverse().then((_) {
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _cardController.dispose();
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
      // Use timestamp as cache key so each new nudge overlay always loads fresh
      cacheKey: '${photoUrl}_${widget.nudge.timestamp}',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.white12,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF758C),
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
    final primaryColor = isKiss ? const Color(0xFFFF4081) : const Color(0xFFAB47BC);
    final secondaryColor = isKiss ? const Color(0xFFFF758C) : const Color(0xFFA18CD1);

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Semi-transparent backdrop that dismisses on tap
          GestureDetector(
            onTap: _dismissOverlay,
            child: Container(
              color: Colors.black.withValues(alpha: hasPhoto ? 0.45 : 0.15),
            ),
          ),

          // 2. Realtime Center Photo Pop-Up Card
          AnimatedBuilder(
            animation: _cardController,
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
                margin: const EdgeInsets.symmetric(horizontal: 28),
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E142B).withValues(alpha: 0.95),
                      const Color(0xFF140D20).withValues(alpha: 0.98),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.6),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Animated Icon & Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, secondaryColor],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: isKiss
                              ? const Icon(Icons.favorite_rounded, size: 20, color: Colors.white)
                              : const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.isLocalSender
                                ? 'Sent ${isKiss ? "Virtual Kiss" : "Warm Hug"}'
                                : '${widget.nudge.senderName} sent you a ${isKiss ? "Virtual Kiss" : "Warm Hug"}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Custom Photo Preview or Romantic Emblem
                    if (hasPhoto) ...[
                      Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _buildPhotoWidget(widget.nudge.photoUrl!),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: isKiss
                            ? const Icon(
                                Icons.favorite_rounded,
                                size: 64,
                                color: Color(0xFFFF4081),
                              )
                            : const Icon(
                                Icons.volunteer_activism_rounded,
                                size: 64,
                                color: Color(0xFFAB47BC),
                              ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Sweet Love Note / Message if available
                    if (widget.nudge.message != null && widget.nudge.message!.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          '"${widget.nudge.message!.trim()}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Tap to dismiss hint
                    Text(
                      'Tap anywhere to dismiss',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

