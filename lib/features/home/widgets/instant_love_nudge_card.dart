import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_love_nudge_service.dart';
import '../../../widgets/common/love_nudge_logo_widget.dart';
import '../../../widgets/common/love_nudge_overlay_listener.dart';

/// Senior Instant Love Nudge Card with Realtime Live Pop-up & Floating Particle Overlay
class InstantLoveNudgeCard extends StatefulWidget {
  const InstantLoveNudgeCard({super.key});

  @override
  State<InstantLoveNudgeCard> createState() => _InstantLoveNudgeCardState();
}

class _InstantLoveNudgeCardState extends State<InstantLoveNudgeCard> {
  bool _isKissPressed = false;
  bool _isHugPressed = false;
  String? _kissPhotoUrl;
  String? _hugPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _kissPhotoUrl = prefs.getString('love_nudge_custom_kiss_photo');
      _hugPhotoUrl = prefs.getString('love_nudge_custom_hug_photo');
    });
  }

  void _triggerNudge({required bool isKiss, required String partnerName}) {
    HapticFeedback.mediumImpact();

    final coupleProvider = context.read<CoupleProvider>();
    final userProvider = context.read<UserProvider>();
    final couple = coupleProvider.couple;
    final user = userProvider.user;
    final photoUrl = isKiss ? _kissPhotoUrl : _hugPhotoUrl;

    final payload = LoveNudgePayload(
      senderId: user?.uid ?? '',
      senderName: user?.displayName.isNotEmpty == true ? user!.displayName : 'You',
      nudgeType: isKiss ? 'kiss' : 'hug',
      photoUrl: photoUrl,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Send Realtime Broadcast to Partner
    if (couple != null && couple.id != null && user != null) {
      SupabaseLoveNudgeService().sendLoveNudge(
        coupleId: couple.id!,
        senderId: user.uid,
        senderName: user.displayName.isNotEmpty ? user.displayName : 'Your Love',
        nudgeType: isKiss ? 'kiss' : 'hug',
        photoUrl: photoUrl,
      );
    }

    // Spawn Realtime Live Screen Overlay locally on sender's device as well
    LoveNudgeOverlayListener.showLocalNudgeEffect(context, payload);

    final actionText = isKiss ? 'Virtual Kiss' : 'Virtual Hug';

    SnackbarHelper.showCustom(
      context: context,
      title: '$actionText Sent!',
      message: 'Successfully sent a $actionText to $partnerName',
      icon: isKiss ? Icons.favorite_rounded : Icons.volunteer_activism_rounded,
      gradientColors: isKiss
          ? const [Color(0xFFFF4081), Color(0xFFD81B60)]
          : const [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleProvider = context.watch<CoupleProvider>();
    final partner = coupleProvider.partner;
    final couple = coupleProvider.couple;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    final partnerName = (partner != null && partner.displayName.isNotEmpty)
        ? partner.displayName
        : (couple != null && user != null
            ? couple.getPartnerName(user.uid, livePartnerName: partner?.displayName)
            : 'wifeyyy');

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
            const Row(
              children: [
                LoveNudgeLogoWidget(size: 42),
                SizedBox(width: 12),
                Expanded(
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
                            Icon(Icons.favorite_rounded, size: 18, color: Colors.white),
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
                            Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 18),
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
