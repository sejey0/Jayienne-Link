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
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.headlineMedium,
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
            if (coupleProvider.couple != null) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              const Divider(),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Linked with ${coupleProvider.couple!.getPartnerName(user.uid)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.softRose,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                '${coupleProvider.couple!.daysTogether} ${AppStrings.daysTogether}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
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
