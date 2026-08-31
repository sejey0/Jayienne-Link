import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../models/social_link_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/smart_profile_image.dart';
import 'platform_brand_icon.dart';

class LinkAddedSuccessModal extends StatefulWidget {
  final SocialLinkModel link;
  final bool isEditing;

  const LinkAddedSuccessModal({
    super.key,
    required this.link,
    this.isEditing = false,
  });

  static Future<void> show(
    BuildContext context,
    SocialLinkModel link, {
    bool isEditing = false,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LinkAddedSuccessModal(
        link: link,
        isEditing: isEditing,
      ),
    );
  }

  @override
  State<LinkAddedSuccessModal> createState() => _LinkAddedSuccessModalState();
}

class _LinkAddedSuccessModalState extends State<LinkAddedSuccessModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final currentUser = userProvider.user;
    final partner = coupleProvider.partner;
    final partnerName = partner?.displayName.isNotEmpty == true
        ? partner!.displayName
        : 'your partner';

    final authorName = widget.link.userDisplayName ?? currentUser?.displayName ?? 'You';
    final authorPhotoUrl = widget.link.userPhotoUrl ?? currentUser?.photoUrl;
    final platform = widget.link.socialPlatform;

    final bgColor = isDark ? const Color(0xFF1A1225) : AppColors.warmWhite;
    final cardColor = isDark ? const Color(0xFF221932) : Colors.white;
    final subtleColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.softRose.withValues(alpha: 0.06);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: AppColors.softRose.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, -12),
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag Handle ──────────────────────────────────────────
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.softRose, AppColors.lavender],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Animated Success Emblem ───────────────────────────────
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.softRose.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Inner gradient circle
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.softRose, AppColors.lavender],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.softRose.withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isEditing ? Icons.check_circle_rounded : Icons.favorite_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  widget.isEditing ? 'Link Updated!' : 'Link Shared!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isEditing ? Icons.check_circle_outline_rounded : Icons.favorite_rounded,
                      size: 13,
                      color: AppColors.softRose,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isEditing
                          ? 'Changes saved to your couple profile'
                          : '$partnerName can now visit this anytime',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ── Creator Card ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: subtleColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.softRose.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.softRose, AppColors.lavender],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.softRose.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: SmartProfileImage(
                            imageUrl: authorPhotoUrl,
                            width: 44,
                            height: 44,
                            placeholder: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.softRose, AppColors.lavender],
                                ),
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 22),
                            ),
                            errorWidget: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.softRose, AppColors.lavender],
                                ),
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    authorName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: isDark ? Colors.white : AppColors.deepCharcoal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.softRose, AppColors.lavender],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.isEditing ? 'Updated' : 'Added',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.isEditing
                                  ? 'Updated ${platform.displayName} on your couple profile'
                                  : 'Added ${platform.displayName} to your couple profile',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white54 : Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Link Preview Card ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: platform.primaryColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: platform.primaryColor.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      PlatformBrandIcon(
                        platform: platform,
                        customUrl: widget.link.url,
                        size: 50,
                        borderRadius: 14,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.link.displayTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.link.displayHandle,
                              style: TextStyle(
                                fontSize: 13,
                                color: platform.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.link.url,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white30 : Colors.grey.shade400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Arrow indicator
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: platform.primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 16,
                          color: platform.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── Action Buttons ────────────────────────────────────────
                Row(
                  children: [
                    // Copy URL
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          UrlLauncherHelper.copyToClipboard(
                            context,
                            widget.link.url,
                            label: widget.link.displayTitle,
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text(
                          'Copy Link',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.deepCharcoal,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Open Link
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: platform.gradientColors.length >= 2
                                ? platform.gradientColors
                                : [AppColors.softRose, AppColors.lavender],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: platform.primaryColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            UrlLauncherHelper.launchLink(context, widget.link.url);
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 15, color: Colors.white),
                          label: const Text(
                            'Open',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Done Button ───────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.softRose, AppColors.lavender],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.softRose.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Done',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
