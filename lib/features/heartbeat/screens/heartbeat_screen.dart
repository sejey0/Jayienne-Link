import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/heartbeat_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/heartbeat_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/live_time_text.dart';
import '../../../widgets/smart_profile_image.dart';

class HeartbeatScreen extends StatefulWidget {
  const HeartbeatScreen({super.key});

  @override
  State<HeartbeatScreen> createState() => _HeartbeatScreenState();
}

class _HeartbeatScreenState extends State<HeartbeatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final heartbeatProvider = context.watch<HeartbeatProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();

    final user = userProvider.user;
    final partner = coupleProvider.partner;
    final heartbeats = heartbeatProvider.heartbeats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heartbeat & Messages'),
      ),
      body: user == null || partner == null
          ? Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: _buildNotLinkedState(context),
            )
          : Column(
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
                                      userId: user.id,
                                      userPhotoUrl: user.photoUrl,
                                      partnerPhotoUrl: partner.photoUrl,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
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
                    icon: Icons.send_rounded,
                    backgroundColor: canSendMessage
                        ? AppColors.lavender
                        : Colors.grey.shade300,
                    iconColor:
                        canSendMessage ? Colors.white : Colors.grey.shade600,
                    onPressed: canSendMessage ? onSendMessage : null,
                    tooltip: 'Send message',
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  _buildActionButton(
                    icon: Icons.favorite,
                    backgroundColor:
                        canSend ? AppColors.softRose : Colors.grey.shade300,
                    iconColor: canSend ? Colors.white : Colors.grey.shade600,
                    onPressed: canSend ? onSendHeart : null,
                    tooltip: 'Send heartbeat',
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
    required String? userId,
    required String? userPhotoUrl,
    required String? partnerPhotoUrl,
  }) {
    final isMine = heartbeat.senderId == userId;
    final backgroundColor =
        isMine ? AppColors.lavenderLight : AppColors.softRoseLight;
    final message = heartbeat.message?.trim();
    final hasMessage = message != null && message.isNotEmpty;
    final heartColor = isMine ? AppColors.lavender : AppColors.softRose;
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
                  if (hasMessage)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                        vertical: AppDimensions.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: bubbleRadius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepCharcoal,
                            ),
                      ),
                    )
                  else
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: heartColor.withOpacity(0.18),
                        border: Border.all(color: heartColor, width: 1.2),
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: heartColor,
                        size: 18,
                      ),
                    ),
                  const SizedBox(height: 2),
                  LiveTimeText(
                    textBuilder: () => heartbeat.timeAgo,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
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
      color: accentColor.withOpacity(0.15),
      child: Icon(
        icon,
        size: 18,
        color: accentColor,
      ),
    );
  }
}
