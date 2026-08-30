import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/chat_bubble_theme.dart';
import '../../../models/heartbeat_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/heartbeat_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/heartbeat_canvas_painter.dart';
import '../../../widgets/common/live_time_text.dart';
import '../../../widgets/smart_profile_image.dart';

/// Redesigned Touch Canvas with Signature Romantic Gradient,
/// Real-time Interactive Touch Glows, Heart Particles, and Modern Glassmorphism Dock
class HeartbeatScreen extends StatefulWidget {
  const HeartbeatScreen({super.key});

  @override
  State<HeartbeatScreen> createState() => _HeartbeatScreenState();
}

class _HeartbeatScreenState extends State<HeartbeatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late AnimationController _canvasTickerController;

  HeartbeatProvider? _heartbeatProvider;
  Timer? _localTypingDebounceTimer;
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageFocusNode.addListener(_handleFocusChange);
    _messageController.addListener(_handleTextChange);

    // 60 FPS Ticker for lerp interpolation & trail fading
    _canvasTickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        if (!mounted) return;
        _heartbeatProvider?.tickInterpolation(0.2);
      })..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _heartbeatProvider?.startTouchSession();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _heartbeatProvider = context.read<HeartbeatProvider>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _heartbeatProvider?.stopTouchSession();
    } else if (state == AppLifecycleState.resumed) {
      _heartbeatProvider?.startTouchSession();
    }
  }

  @override
  void deactivate() {
    _localTypingDebounceTimer?.cancel();
    _heartbeatProvider?.stopTouchSession();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localTypingDebounceTimer?.cancel();
    _canvasTickerController.stop();
    _canvasTickerController.dispose();
    _messageFocusNode.removeListener(_handleFocusChange);
    _messageController.removeListener(_handleTextChange);
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    if (!mounted) return;
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _heartbeatProvider?.sendTypingStatus(true);
      _localTypingDebounceTimer?.cancel();
      _localTypingDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _heartbeatProvider?.sendTypingStatus(false);
        }
      });
    } else {
      _localTypingDebounceTimer?.cancel();
      _heartbeatProvider?.sendTypingStatus(false);
    }
  }

  void _handleFocusChange() {
    if (!_messageFocusNode.hasFocus && mounted) {
      _localTypingDebounceTimer?.cancel();
      _heartbeatProvider?.stopTyping();
    }
  }

  Future<void> _handleSendMessage(HeartbeatProvider heartbeatProvider) async {
    if (!heartbeatProvider.canSend || heartbeatProvider.isSending) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _localTypingDebounceTimer?.cancel();
    heartbeatProvider.sendTypingStatus(false);

    final didSend = await heartbeatProvider.sendHeartbeat(
      message: message,
    );

    if (didSend) {
      _messageController.clear();
      _messageFocusNode.unfocus();
    }
  }

  Future<void> _handleSendHeart(HeartbeatProvider heartbeatProvider) async {
    if (!heartbeatProvider.canSend || heartbeatProvider.isSending) return;

    HapticFeedback.mediumImpact();
    final didSend = await heartbeatProvider.sendHeartbeat();
    if (didSend) {
      _messageFocusNode.unfocus();
    }
  }

  Future<void> _handleRefresh(HeartbeatProvider heartbeatProvider) async {
    if (heartbeatProvider.isRefreshing) return;
    HapticFeedback.lightImpact();
    await heartbeatProvider.refreshNow();
  }

  void _showBubbleThemeSheet(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final user = userProvider.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final selectedKey = user.bubbleTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingLg,
              AppDimensions.spacingSm,
              AppDimensions.spacingLg,
              AppDimensions.spacingLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.palette_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Chat Bubble Style',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                ...ChatBubbleThemes.all.map(
                  (theme) => _buildBubbleThemeOption(
                    context,
                    theme: theme,
                    isSelected: theme.key == selectedKey,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await userProvider.updateBubbleTheme(theme.key);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final heartbeatProvider = context.watch<HeartbeatProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();

    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final partner = coupleProvider.partner;
    final heartbeats = heartbeatProvider.heartbeats;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partnerName = couple != null && user != null
        ? couple.getPartnerName(user.uid, livePartnerName: partner?.displayName)
        : (partner?.displayName?.isNotEmpty == true ? partner!.displayName : 'wifeyyy');

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text(
          'Touch Canvas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
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
        actions: [
          IconButton(
            tooltip: 'Chat bubble style',
            icon: const Icon(Icons.palette_outlined, color: Colors.white),
            onPressed: user == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _showBubbleThemeSheet(context, userProvider);
                  },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: heartbeatProvider.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: heartbeatProvider.isRefreshing
                ? null
                : () => _handleRefresh(heartbeatProvider),
          ),
        ],
        elevation: 0,
      ),
      body: user == null || couple == null
          ? Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: _buildNotLinkedState(context, isDark),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Listener(
                  onPointerDown: (event) {
                    if (!mounted) return;
                    heartbeatProvider.sendLocalTouch(event.localPosition, 'down',
                        screenSize: _canvasSize);
                  },
                  onPointerMove: (event) {
                    if (!mounted) return;
                    heartbeatProvider.sendLocalTouch(event.localPosition, 'move',
                        screenSize: _canvasSize);
                  },
                  onPointerUp: (event) {
                    if (!mounted) return;
                    heartbeatProvider.sendLocalTouch(event.localPosition, 'up',
                        screenSize: _canvasSize);
                  },
                  onPointerCancel: (event) {
                    if (!mounted) return;
                    heartbeatProvider.sendLocalTouch(event.localPosition, 'up',
                        screenSize: _canvasSize);
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    children: [
                      // 1. Realtime Touch Canvas Painter Overlay
                      Positioned.fill(
                        child: CustomPaint(
                          painter: HeartbeatCanvasPainter(
                            localTouch: heartbeatProvider.localCurrentTouch,
                            partnerTouch: heartbeatProvider.partnerCurrentTouch,
                            isLocalTouching: heartbeatProvider.isLocalTouching,
                            isPartnerTouching: heartbeatProvider.isPartnerTouching,
                            localTrail: heartbeatProvider.localTouchTrail,
                            partnerTrail: heartbeatProvider.partnerTouchTrail,
                            particles: heartbeatProvider.collisionParticles,
                            isColliding: heartbeatProvider.isColliding,
                            collisionPoint: heartbeatProvider.collisionPoint,
                            collisionRippleRadius:
                                heartbeatProvider.collisionRippleRadius,
                          ),
                        ),
                      ),

                      // 2. Main Scrollable Message Feed & Floating Radar Bar
                      Column(
                        children: [
                          // Floating Presence & Touch Radar Banner
                          _buildTouchRadarBanner(
                            context,
                            heartbeatProvider: heartbeatProvider,
                            partnerName: partnerName,
                            isDark: isDark,
                          ),

                          // Heartbeats and Messages List
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppDimensions.spacingMd,
                                4,
                                AppDimensions.spacingMd,
                                0,
                              ),
                              child: Column(
                                children: [
                                  if (heartbeatProvider.error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppDimensions.spacingSm,
                                      ),
                                      child: Text(
                                        heartbeatProvider.error!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.error,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  Expanded(
                                    child: heartbeats.isEmpty
                                        ? _buildEmptyState(
                                            context, partnerName, isDark)
                                        : ListView.separated(
                                            reverse: true,
                                            padding: const EdgeInsets.only(
                                              bottom: AppDimensions.spacingSm,
                                            ),
                                            itemCount: heartbeats.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 8),
                                            itemBuilder: (context, index) {
                                              final current = heartbeats[index];
                                              final older = (index + 1 <
                                                      heartbeats.length)
                                                  ? heartbeats[index + 1]
                                                  : null;
                                              final currentDate =
                                                  current.createdAt ??
                                                      current.sentAt;
                                              final olderDate = older != null
                                                  ? (older.createdAt ??
                                                      older.sentAt)
                                                  : null;
                                              final showHeader = _isDifferentDay(
                                                  currentDate, olderDate);

                                              final tile = _buildHeartbeatTile(
                                                context,
                                                heartbeat: current,
                                                heartbeatProvider:
                                                    heartbeatProvider,
                                                userId: user.id,
                                                userPhotoUrl: user.photoUrl,
                                                partnerPhotoUrl:
                                                    partner?.photoUrl,
                                                userBubbleTheme:
                                                    user.bubbleTheme,
                                                partnerBubbleTheme:
                                                    partner?.bubbleTheme,
                                                isDark: isDark,
                                              );

                                              if (showHeader) {
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.stretch,
                                                  children: [
                                                    _buildDateHeaderChip(
                                                      context,
                                                      _formatDateHeader(
                                                          currentDate),
                                                    ),
                                                    tile,
                                                  ],
                                                );
                                              }

                                              return tile;
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Partner Typing Row
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: heartbeatProvider.isPartnerTyping
                                ? Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppDimensions.spacingMd,
                                      0,
                                      AppDimensions.spacingMd,
                                      AppDimensions.spacingSm,
                                    ),
                                    child: _buildTypingRow(
                                      context,
                                      partnerPhotoUrl: partner?.photoUrl,
                                      isDark: isDark,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Modern Floating Send Bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppDimensions.spacingMd,
                              AppDimensions.spacingXs,
                              AppDimensions.spacingMd,
                              AppDimensions.spacingMd,
                            ),
                            child: _buildSendDock(
                              context,
                              heartbeatProvider: heartbeatProvider,
                              messageController: _messageController,
                              messageFocusNode: _messageFocusNode,
                              onSendMessage: () =>
                                  _handleSendMessage(heartbeatProvider),
                              onSendHeart: () =>
                                  _handleSendHeart(heartbeatProvider),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Floating Real-time Touch Presence & Collision Banner
  Widget _buildTouchRadarBanner(
    BuildContext context, {
    required HeartbeatProvider heartbeatProvider,
    required String partnerName,
    required bool isDark,
  }) {
    String statusText;
    IconData statusIcon;
    List<Color> gradientColors;

    if (heartbeatProvider.isColliding) {
      statusText = 'Hearts touching and colliding!';
      statusIcon = Icons.favorite_rounded;
      gradientColors = const [Color(0xFFFF1744), Color(0xFFFF4081)];
    } else if (heartbeatProvider.isPartnerTouching) {
      statusText = '$partnerName is touching screen';
      statusIcon = Icons.fingerprint_rounded;
      gradientColors = const [Color(0xFFFF758C), Color(0xFFA18CD1)];
    } else if (heartbeatProvider.isLocalTouching) {
      statusText = 'Feeling for $partnerName...';
      statusIcon = Icons.touch_app_rounded;
      gradientColors = const [Color(0xFFA18CD1), Color(0xFF7E57C2)];
    } else {
      statusText = 'Touch and hold anywhere to feel each other';
      statusIcon = Icons.auto_awesome_rounded;
      gradientColors = [
        const Color(0xFFFF758C).withValues(alpha: isDark ? 0.35 : 0.2),
        const Color(0xFFA18CD1).withValues(alpha: isDark ? 0.35 : 0.2),
      ];
    }

    final isLiveEvent = heartbeatProvider.isColliding ||
        heartbeatProvider.isPartnerTouching ||
        heartbeatProvider.isLocalTouching;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: isLiveEvent
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isLiveEvent
            ? null
            : (isDark
                ? const Color(0xFF1E162B).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLiveEvent
              ? Colors.white.withValues(alpha: 0.4)
              : const Color(0xFFFF758C).withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: isLiveEvent ? 0.35 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: isLiveEvent
                ? Colors.white
                : const Color(0xFFFF758C),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              statusText,
              style: TextStyle(
                color: isLiveEvent
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.deepCharcoal),
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Floating Send Dock Card
  Widget _buildSendDock(
    BuildContext context, {
    required HeartbeatProvider heartbeatProvider,
    required TextEditingController messageController,
    required FocusNode messageFocusNode,
    required VoidCallback onSendMessage,
    required VoidCallback onSendHeart,
    required bool isDark,
  }) {
    final canSend = heartbeatProvider.canSend && !heartbeatProvider.isSending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E162B)
            : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFF758C).withValues(alpha: 0.25)
              : const Color(0xFFFF758C).withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: messageController,
        builder: (context, value, _) {
          final hasMessage = value.text.trim().isNotEmpty;
          final canSendMessage = canSend && hasMessage;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 6),
              // Message Text Input directly inside dock
              Expanded(
                child: TextField(
                  controller: messageController,
                  focusNode: messageFocusNode,
                  enabled: canSend,
                  minLines: 1,
                  maxLines: 3,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    fontSize: 14.5,
                  ),
                  cursorColor: const Color(0xFFFF758C),
                  onChanged: heartbeatProvider.handleTypingChanged,
                  onSubmitted: (_) => onSendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type sweet message...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      fontSize: 13.5,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send Heart Pulse Button (Quick Heartbeat)
              _buildGradientActionButton(
                icon: Icons.favorite_rounded,
                tooltip: 'Send heartbeat',
                gradientColors: const [Color(0xFFFF4081), Color(0xFFD81B60)],
                onPressed: canSend ? onSendHeart : null,
              ),

              if (hasMessage) ...[
                const SizedBox(width: 6),
                // Send Message Button
                _buildGradientActionButton(
                  icon: Icons.send_rounded,
                  tooltip: 'Send message',
                  gradientColors: const [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  onPressed: canSendMessage ? onSendMessage : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildGradientActionButton({
    required IconData icon,
    required String tooltip,
    required List<Color> gradientColors,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isEnabled ? null : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.grey.shade500,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildNotLinkedState(BuildContext context, bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E162B) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFFF758C).withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              color: Color(0xFFFF758C),
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              'Link with your love to use Touch Canvas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Once linked, you can touch the screen together in real-time and send heartbeats.',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, String partnerName, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF758C).withValues(alpha: 0.2),
                  const Color(0xFFA18CD1).withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              size: 44,
              color: Color(0xFFFF758C),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Touch Anywhere on Screen',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hold your finger down to send live pulses to $partnerName',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeartbeatTile(
    BuildContext context, {
    required HeartbeatModel heartbeat,
    required HeartbeatProvider heartbeatProvider,
    required String? userId,
    required String? userPhotoUrl,
    required String? partnerPhotoUrl,
    required String? userBubbleTheme,
    required String? partnerBubbleTheme,
    required bool isDark,
  }) {
    final isMine = heartbeat.senderId == userId;
    final message = heartbeat.message?.trim();
    final hasMessage = message != null && message.isNotEmpty;
    final heartbeatId = heartbeat.id;
    final themeKey = isMine ? userBubbleTheme : partnerBubbleTheme;
    final bubbleTheme = ChatBubbleThemes.resolve(themeKey);
    final brightness = Theme.of(context).brightness;
    final bubbleColor = bubbleTheme.bubbleColor(brightness);
    final bubbleTextColor = bubbleTheme.textColor(brightness);
    final heartColor = bubbleTheme.accentColor;
    final hasReaction =
        heartbeatId != null && heartbeatProvider.hasReaction(heartbeatId);
    final reactionCount =
        heartbeatId != null ? heartbeatProvider.reactionCount(heartbeatId) : 0;
    final hasSeen = heartbeatId != null &&
        isMine &&
        heartbeatProvider.isSeenByPartner(heartbeatId);

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    const reactionColor = Color(0xFFFF758C);
    final seenTextStyle = TextStyle(
      color: isDark ? Colors.white54 : Colors.grey.shade600,
      fontWeight: FontWeight.w600,
      fontSize: 10,
    );

    Widget bubbleContent = hasMessage
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: bubbleRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: bubbleTextColor,
                fontSize: 13.5,
              ),
            ),
          )
        : Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  heartColor.withValues(alpha: 0.25),
                  heartColor.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: heartColor, width: 1.5),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: heartColor,
              size: 20,
            ),
          );

    if (heartbeatId != null) {
      bubbleContent = GestureDetector(
        onDoubleTap: () {
          HapticFeedback.lightImpact();
          heartbeatProvider.toggleReaction(heartbeatId);
        },
        child: bubbleContent,
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              _buildAvatar(
                photoUrl: partnerPhotoUrl,
                accentColor: const Color(0xFFFF758C),
                fallbackIcon: Icons.favorite_rounded,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  bubbleContent,
                  if (hasReaction)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: isMine
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: reactionColor,
                          ),
                          if (reactionCount > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              reactionCount.toString(),
                              style: const TextStyle(
                                color: reactionColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isMine
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      LiveTimeText(
                        textBuilder: () => heartbeat.formattedTime,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                      if (hasSeen) ...[
                        const SizedBox(width: 6),
                        Text('Seen', style: seenTextStyle),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 8),
              _buildAvatar(
                photoUrl: userPhotoUrl,
                accentColor: const Color(0xFFA18CD1),
                fallbackIcon: Icons.person_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required String? photoUrl,
    required Color accentColor,
    required IconData fallbackIcon,
  }) {
    const double size = 32;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accentColor, width: 2),
      ),
      child: ClipOval(
        child: SmartProfileImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          placeholder: _buildAvatarPlaceholder(size, accentColor, fallbackIcon),
          errorWidget: _buildAvatarPlaceholder(size, accentColor, fallbackIcon),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(
    double size,
    Color accentColor,
    IconData icon,
  ) {
    return Container(
      width: size,
      height: size,
      color: accentColor.withValues(alpha: 0.15),
      child: Icon(
        icon,
        size: 16,
        color: accentColor,
      ),
    );
  }

  Widget _buildTypingRow(
    BuildContext context, {
    required String? partnerPhotoUrl,
    required bool isDark,
  }) {
    final bubbleColor = isDark
        ? const Color(0xFFFF758C).withValues(alpha: 0.2)
        : const Color(0xFFFF758C).withValues(alpha: 0.12);
    final dotColor = isDark ? Colors.white70 : AppColors.deepCharcoal;
    const bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(16),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(
            photoUrl: partnerPhotoUrl,
            accentColor: const Color(0xFFFF758C),
            fallbackIcon: Icons.favorite_rounded,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: bubbleRadius,
            ),
            child: _TypingDots(color: dotColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleThemeOption(
    BuildContext context, {
    required ChatBubbleThemeStyle theme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final bubbleColor = theme.bubbleColor(brightness);
    final textColor = theme.textColor(brightness);
    final borderColor = isSelected
        ? theme.accentColor
        : (brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade300);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  theme.label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.year == date.year) {
      return DateFormat('EEEE, MMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  bool _isDifferentDay(DateTime? d1, DateTime? d2) {
    if (d1 == null || d2 == null) return true;
    return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
  }

  Widget _buildDateHeaderChip(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFFF758C).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF758C).withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
            letterSpacing: 0.3,
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : const Color(0xFFC2185B),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) => _buildDot(index)),
    );
  }

  Widget _buildDot(int index) {
    final animation = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          0.2 * index,
          0.2 * index + 0.6,
          curve: Curves.easeInOut,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, animation.value),
          child: child,
        );
      },
      child: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
