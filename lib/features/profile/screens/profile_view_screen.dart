import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/couple_provider.dart';

class ProfileViewScreen extends StatelessWidget {
  const ProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final user = userProvider.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(RouteNames.editProfile),
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
              backgroundColor: AppColors.peach.withOpacity(0.3),
              backgroundImage: _getProfileImageProvider(user.photoUrl),
              child: user.photoUrl == null
                  ? const Icon(Icons.person,
                      size: 48, color: AppColors.softRose)
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
          ],
        ),
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
