import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/chat_bubble_theme.dart';
import '../../../models/heartbeat_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/heartbeat_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/heartbeat_canvas_painter.dart';
import '../../../widgets/common/live_time_text.dart';
import '../../../widgets/smart_profile_image.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageFocusNode.addListener(_handleFocusChange);

    // 60 FPS Ticker for lerp interpolation & trail fading
    _canvasTickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        context.read<HeartbeatProvider>().tickInterpolation(0.2);
      })..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HeartbeatProvider>().startTouchSession();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      context.read<HeartbeatProvider>().stopTouchSession();
    } else if (state == AppLifecycleState.resumed) {
      context.read<HeartbeatProvider>().startTouchSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<HeartbeatProvider>().stopTouchSession();
    _canvasTickerController.dispose();
    _messageFocusNode.removeListener(_handleFocusChange);
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_messageFocusNode.hasFocus) {
      context.read<HeartbeatProvider>().stopTyping();
    }
  }

  Future<void> _handleSendMessage(HeartbeatProvider heartbeatProvider) async {
    if (!heartbeatProvider.canSend || heartbeatProvider.isSending) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

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

    final didSend = await heartbeatProvider.sendHeartbeat();
    if (didSend) {
      _messageFocusNode.unfocus();
    }
  }

  Future<void> _handleRefresh(HeartbeatProvider heartbeatProvider) async {
    if (heartbeatProvider.isRefreshing) return;
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
                Text(
                  'Chat bubble style',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                ...ChatBubbleThemes.all.map(
                  (theme) => _buildBubbleThemeOption(
                    context,
                    theme: theme,
                    isSelected: theme.key == selectedKey,
                    onTap: () async {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heartbeat & Messages'),
        actions: [
          IconButton(
            tooltip: 'Chat bubble style',
            icon: const Icon(Icons.palette_outlined),
            onPressed: user == null
                ? null
                : () => _showBubbleThemeSheet(context, userProvider),
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
                : const Icon(Icons.refresh),
            onPressed: heartbeatProvider.isRefreshing
                ? null
                : () => _handleRefresh(heartbeatProvider),
          ),
        ],
      ),
      body: user == null || couple == null
          ? Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: _buildNotLinkedState(context),
            )
          : Listener(
              onPointerDown: (event) {
                heartbeatProvider.sendLocalTouch(event.localPosition, 'down');
              },
              onPointerMove: (event) {
                heartbeatProvider.sendLocalTouch(event.localPosition, 'move');
              },
              onPointerUp: (event) {
                heartbeatProvider.sendLocalTouch(event.localPosition, 'up');
              },
              onPointerCancel: (event) {
                heartbeatProvider.sendLocalTouch(event.localPosition, 'up');
              },
              behavior: HitTestBehavior.translucent,
              child: Stack(
                children: [
                  // Realtime Touch Canvas Overlay
                  Positioned.fill(
                    child: CustomPaint(
                      painter: HeartbeatCanvasPainter(
                        localTouch: heartbeatProvider.localCurrentTouch,
                        partnerTouch: heartbeatProvider.partnerCurrentTouch,
                        isLocalTouching: heartbeatProvider.isLocalTouching,
                        isPartnerTouching: heartbeatProvider.isPartnerTouching,
                        localTrail: heartbeatProvider.localTouchTrail,
                        partnerTrail: heartbeatProvider.partnerTouchTrail,
                        isColliding: heartbeatProvider.isColliding,
                        collisionPoint: heartbeatProvider.collisionPoint,
                        collisionRippleRadius: heartbeatProvider.collisionRippleRadius,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.spacingLg,
                            AppDimensions.spacingLg,
                            AppDimensions.spacingLg,
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
                                    ? _buildEmptyState(context)
                                    : ListView.separated(
                                        reverse: true,
                                        padding: const EdgeInsets.only(
                                          bottom: AppDimensions.spacingSm,
                                        ),
                                        itemCount: heartbeats.length,
                                        separatorBuilder: (_, __) => const SizedBox(
                                            height: AppDimensions.spacingSm),
                                        itemBuilder: (context, index) {
                                          return _buildHeartbeatTile(
                                            context,
                                            heartbeat: heartbeats[index],
                                            heartbeatProvider: heartbeatProvider,
                                            userId: user.id,
                                            userPhotoUrl: user.photoUrl,
                                            partnerPhotoUrl: partner?.photoUrl,
                                            userBubbleTheme: user.bubbleTheme,
                                            partnerBubbleTheme: partner?.bubbleTheme,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: heartbeatProvider.isPartnerTyping
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppDimensions.spacingLg,
                                  0,
                                  AppDimensions.spacingLg,
                                  AppDimensions.spacingSm,
                                ),
                                child: _buildTypingRow(
                                  context,
                                  partnerPhotoUrl: partner?.photoUrl,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.spacingLg,
                          AppDimensions.spacingSm,
                          AppDimensions.spacingLg,
                          AppDimensions.spacingLg,
                        ),
                        child: _buildSendCard(
                          context,
                          heartbeatProvider: heartbeatProvider,
                          messageController: _messageController,
                          messageFocusNode: _messageFocusNode,
                          onSendMessage: () => _handleSendMessage(heartbeatProvider),
                          onSendHeart: () => _handleSendHeart(heartbeatProvider),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSendCard(
    BuildContext context, {
    required HeartbeatProvider heartbeatProvider,
    required TextEditingController messageController,
    required FocusNode messageFocusNode,
    required VoidCallback onSendMessage,
    required VoidCallback onSendHeart,
  }) {
    final canSend = heartbeatProvider.canSend && !heartbeatProvider.isSending;

    return AppCard(
      child: Column(
        children: [
          Text(
            'Heartbeat & Messages',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: messageController,
            builder: (context, value, _) {
              final hasMessage = value.text.trim().isNotEmpty;
              final canSendMessage = canSend && hasMessage;

              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      focusNode: messageFocusNode,
                      enabled: canSend,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.deepCharcoal,
                          ),
                      cursorColor: AppColors.softRose,
                      onChanged: heartbeatProvider.handleTypingChanged,
                      onSubmitted: (text) => onSendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingMd,
                          vertical: AppDimensions.spacingSm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.borderRadiusMedium,
                          ),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.borderRadiusMedium,
                          ),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.borderRadiusMedium,
                          ),
                          borderSide:
                              const BorderSide(color: AppColors.softRose),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  _buildActionButton(
                    icon: Icons.favorite,
                    backgroundColor:
                        canSend ? AppColors.softRose : Colors.grey.shade300,
                    iconColor: canSend ? Colors.white : Colors.grey.shade600,
                    onPressed: canSend ? onSendHeart : null,
                    tooltip: 'Send heartbeat',
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  _buildActionButton(
                    icon: Icons.send_rounded,
                    backgroundColor: canSendMessage
                        ? AppColors.lavender
                        : Colors.grey.shade300,
                    iconColor:
                        canSendMessage ? Colors.white : Colors.grey.shade600,
                    onPressed: canSendMessage ? onSendMessage : null,
                    tooltip: 'Send message',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotLinkedState(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.favorite_border,
            color: AppColors.softRose,
            size: 48,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Link with your partner to use Heartbeat',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Once linked, you can send heartbeats instantly.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.favorite_outline,
            size: 48,
            color: AppColors.lavender,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey,
                ),
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
      topLeft: const Radius.circular(AppDimensions.borderRadiusMedium),
      topRight: const Radius.circular(AppDimensions.borderRadiusMedium),
      bottomLeft: Radius.circular(
        isMine ? AppDimensions.borderRadiusMedium : 6,
      ),
      bottomRight: Radius.circular(
        isMine ? 6 : AppDimensions.borderRadiusMedium,
      ),
    );
    const reactionColor = AppColors.lavender;
    final reactionTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: reactionColor,
          fontWeight: FontWeight.w600,
        );
    final seenTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        );

    Widget bubbleContent = hasMessage
        ? Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: bubbleRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: bubbleTextColor,
                  ),
            ),
          )
        : Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: heartColor.withValues(alpha: 0.18),
              border: Border.all(color: heartColor, width: 1.2),
            ),
            child: Icon(
              Icons.favorite,
              color: heartColor,
              size: 18,
            ),
          );

    if (heartbeatId != null) {
      bubbleContent = GestureDetector(
        onDoubleTap: () => heartbeatProvider.toggleReaction(heartbeatId),
        child: bubbleContent,
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              _buildAvatar(
                photoUrl: partnerPhotoUrl,
                accentColor: AppColors.softRose,
                fallbackIcon: Icons.favorite,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
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
                            Icons.favorite,
                            size: 14,
                            color: reactionColor,
                          ),
                          if (reactionCount > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              reactionCount.toString(),
                              style: reactionTextStyle,
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey.shade700,
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
              const SizedBox(width: AppDimensions.spacingSm),
              _buildAvatar(
                photoUrl: userPhotoUrl,
                accentColor: AppColors.lavender,
                fallbackIcon: Icons.person,
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
        size: 18,
        color: accentColor,
      ),
    );
  }

  Widget _buildTypingRow(
    BuildContext context, {
    required String? partnerPhotoUrl,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor =
        isDark ? AppColors.softRose.withValues(alpha: 0.25) : AppColors.softRoseLight;
    final dotColor = isDark ? AppColors.darkText : AppColors.deepCharcoal;
    const bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(AppDimensions.borderRadiusMedium),
      topRight: Radius.circular(AppDimensions.borderRadiusMedium),
      bottomLeft: Radius.circular(6),
      bottomRight: Radius.circular(AppDimensions.borderRadiusMedium),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(
            photoUrl: partnerPhotoUrl,
            accentColor: AppColors.softRose,
            fallbackIcon: Icons.favorite,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm,
            ),
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
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppDimensions.borderRadiusMedium),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusMedium),
                ),
                child: Text(
                  theme.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.accentColor,
                ),
            ],
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
