import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';

/// Senior Redesigned Couple Profile Card with Beating Heart Animation & Haptic Touch Feedback
class CoupleProfileCard extends StatefulWidget {
  const CoupleProfileCard({super.key});

  @override
  State<CoupleProfileCard> createState() => _CoupleProfileCardState();
}

class _CoupleProfileCardState extends State<CoupleProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Heartbeat double-pulse loop animation controller
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final partner = coupleProvider.partner;
    final outgoingAnniversary = coupleProvider.outgoingAnniversaryRequests;
    final pendingAnniversary =
        outgoingAnniversary.isNotEmpty ? outgoingAnniversary.first : null;

    if (couple == null || user == null || !user.hasRealPartner) {
      return const SizedBox.shrink();
    }

    final myName = user.displayName.isNotEmpty ? user.displayName : 'You';
    final partnerName = couple.getPartnerName(user.uid, livePartnerName: partner?.displayName);
    final isPartnerConnected = partner != null;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.softRose.withValues(alpha: 0.16),
            AppColors.lavender.withValues(alpha: 0.28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.softRose.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.softRose.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dual Avatars Row with Centered Beating Heart Animation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User Avatar (Left)
                _buildAvatarWithStatus(
                  context,
                  photoUrl: user.photoUrl,
                  isOnline: true,
                ),

                const SizedBox(width: 20),

                // Pulsing Beating Heart Animation with Haptic Feedback on Tap
                GestureDetector(
                  onTap: () => HapticFeedback.lightImpact(),
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.softRose.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.softRose.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.softRose,
                        size: 28,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Partner Avatar (Right) with Online Status Badge
                _buildAvatarWithStatus(
                  context,
                  photoUrl: partner?.photoUrl,
                  isOnline: isPartnerConnected,
                  showStatus: true,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Modern Bold Names Display: Name 1 & Name 2 (e.g. CJay & Aienne)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$myName & $partnerName',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.softRose,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 0.5,
                    ),
              ),
            ),

            // Pending Anniversary Notice Banner if present
            if (pendingAnniversary != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Anniversary request pending for ${DateFormat('MMMM d, yyyy').format(pendingAnniversary.proposedDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWithStatus(
    BuildContext context, {
    required String? photoUrl,
    required bool isOnline,
    bool showStatus = false,
  }) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.peach.withValues(alpha: 0.3),
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? const Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: AppColors.softRose,
                  )
                : null,
          ),
        ),

        // Green/Gray Online Status Indicator Badge
        if (showStatus)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
