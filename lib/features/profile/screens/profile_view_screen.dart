import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../providers/couple_links_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../links/widgets/add_edit_link_sheet.dart';
import '../../links/widgets/platform_brand_icon.dart';

import '../../../widgets/common/romantic_loading_indicator.dart';

class ProfileViewScreen extends StatelessWidget {
  const ProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final user = userProvider.user;

    if (user == null) {
      return const RomanticLoadingScreen(
        message: 'Loading your profile...',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppStrings.profile,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.softRose, AppColors.lavender],
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
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push(RouteNames.editProfile);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.spacingLg),
            CircleAvatar(
              radius: AppDimensions.avatarSizeLarge / 2,
              backgroundColor: AppColors.peach.withValues(alpha: 0.3),
              backgroundImage: _getProfileImageProvider(user.photoUrl),
              child: user.photoUrl == null
                  ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.person_rounded,
                          size: 48, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            // Border Framed Couple Names Card (Name 1 & Name 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
                border: Border.all(
                  color: AppColors.softRose.withValues(alpha: 0.6),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.softRose.withValues(alpha: 0.12),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'COUPLE PROFILE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.softRose,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Name 1 Border Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.softRose.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.softRose,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.titleMedium?.color ??
                                    (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : AppColors.deepCharcoal),
                              ),
                        ),
                      ),
                      if (coupleProvider.couple != null) ...[
                        const Icon(
                          Icons.favorite,
                          color: AppColors.softRose,
                          size: 20,
                        ),
                        // Name 2 Border Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.lavender.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.lavender,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            coupleProvider.couple!.getPartnerName(
                              user.uid,
                              livePartnerName: coupleProvider.partner?.displayName,
                            ),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.titleMedium?.color ??
                                      (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : AppColors.deepCharcoal),
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (coupleProvider.couple != null) ...[
                    const SizedBox(height: AppDimensions.spacingSm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${coupleProvider.couple!.daysTogether} ${AppStrings.daysTogether}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              user.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            if (user.birthday != null) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cake_outlined,
                      size: 16, color: AppColors.softRose),
                  const SizedBox(width: 4),
                  Text(
                    '${user.birthday!.month}/${user.birthday!.day}/${user.birthday!.year}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLg),

            // Social Profiles & Links Section
            _buildSocialLinksSection(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linksProvider = context.watch<CoupleLinksProvider>();
    final allLinks = linksProvider.links;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
        border: Border.all(
          color: AppColors.lavender.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.softRose, AppColors.lavender],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SOCIALS & WEBSITES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppColors.lavender,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(RouteNames.coupleLinks);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.softRose,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allLinks.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'No social profiles added yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      AddEditLinkSheet.show(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Add Link / Account', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.softRose,
                      side: const BorderSide(color: AppColors.softRose),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allLinks.map((link) {
                final platform = link.socialPlatform;
                return InkWell(
                  onTap: () => UrlLauncherHelper.launchLink(context, link.url),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? platform.primaryColor.withValues(alpha: 0.15)
                          : platform.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: platform.primaryColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlatformBrandIcon(
                          platform: platform,
                          size: 22,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          link.displayTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 12,
                          color: platform.primaryColor,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Get appropriate ImageProvider for profile photos (supports both network URLs and Base64)
  ImageProvider? _getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null) return null;

    // Check if it's a Base64 data URL
    if (photoUrl.startsWith('data:image/')) {
      try {
        // Extract Base64 data from data URL
        final base64String = photoUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        // If Base64 decoding fails, return null to show fallback
        return null;
      }
    } else {
      // Regular network URL, use CachedNetworkImageProvider
      return CachedNetworkImageProvider(photoUrl);
    }
  }
}
