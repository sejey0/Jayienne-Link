import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/heartbeat_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/heartbeat_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/heart_animation.dart';
import '../../../widgets/common/live_time_text.dart';
import '../../../widgets/smart_profile_image.dart';

class HeartbeatScreen extends StatelessWidget {
  const HeartbeatScreen({super.key});

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
        title: const Text('Heartbeat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          children: [
            if (user == null || partner == null)
              _buildNotLinkedState(context)
            else
              _buildSendCard(
                context,
                heartbeatProvider: heartbeatProvider,
                partnerName: partner.displayName,
                lastHeartbeat: heartbeats.isNotEmpty ? heartbeats.first : null,
              ),
            if (heartbeatProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppDimensions.spacingSm,
                ),
                child: Text(
                  heartbeatProvider.error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Text(
                  'Recent Heartbeats',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Expanded(
              child: heartbeats.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      itemCount: heartbeats.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.spacingSm),
                      itemBuilder: (context, index) {
                        return _buildHeartbeatTile(
                          context,
                          heartbeat: heartbeats[index],
                          userId: user?.id,
                          userPhotoUrl: user?.photoUrl,
                          partnerPhotoUrl: partner?.photoUrl,
                          partnerName: partner?.displayName,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendCard(
    BuildContext context, {
    required HeartbeatProvider heartbeatProvider,
    required String partnerName,
    HeartbeatModel? lastHeartbeat,
  }) {
    final canSend = heartbeatProvider.canSend && !heartbeatProvider.isSending;
    final buttonColor =
        canSend ? AppColors.softRose : AppColors.softRose.withOpacity(0.5);

    return AppCard(
      child: Column(
        children: [
          Text(
            'Send a heartbeat to $partnerName',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Let your person know you are thinking of them.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          InkWell(
            onTap: canSend ? heartbeatProvider.sendHeartbeat : null,
            borderRadius: BorderRadius.circular(100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: buttonColor,
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: heartbeatProvider.isSending
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const HeartAnimation(
                        size: 64,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
          if (lastHeartbeat != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            LiveTimeText(
              textBuilder: () =>
                  'Last heartbeat ${lastHeartbeat.timeAgo} (${lastHeartbeat.formattedTime})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
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
            'No heartbeats yet',
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
    required String? partnerName,
  }) {
    final isMine = heartbeat.senderId == userId;
    final label = isMine ? 'You' : (partnerName ?? 'Your Person');
    final backgroundColor =
        isMine ? AppColors.lavenderLight : AppColors.softRoseLight;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine) ...[
              _buildAvatar(
                photoUrl: partnerPhotoUrl,
                accentColor: AppColors.softRose,
                fallbackIcon: Icons.favorite,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
            ],
            Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  '$label sent a heartbeat',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepCharcoal,
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
