import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/heart_animation.dart';
import '../../location/widgets/partner_location_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final user = userProvider.user;
    final couple = coupleProvider.couple;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(RouteNames.profile),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RouteNames.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          children: [
            // Couple header
            if (couple != null && user != null)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAvatar(context, user.photoUrl),
                          const SizedBox(width: AppDimensions.spacingMd),
                          const HeartAnimation(size: 32),
                          const SizedBox(width: AppDimensions.spacingMd),
                          _buildAvatar(context, null),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      Text(
                        couple.coupleName ??
                            '${user.displayName} & ${couple.getPartnerName(user.uid)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.softRose,
                            ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        '${couple.daysTogether} ${AppStrings.daysTogether}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppDimensions.spacingXl),
            // Quick actions grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppDimensions.spacingMd,
              mainAxisSpacing: AppDimensions.spacingMd,
              children: [
                // Location - Now working!
                PartnerLocationCardCompact(
                  onTap: () => context.push(RouteNames.location),
                ),
                _buildFeatureCard(context, Icons.favorite_outline, 'Heartbeat'),
                _buildFeatureCard(
                    context, Icons.emoji_emotions_outlined, 'Mood'),
                _buildFeatureCard(
                    context, Icons.photo_library_outlined, 'Photos'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? photoUrl) {
    return CircleAvatar(
      radius: AppDimensions.avatarSizeMedium / 2,
      backgroundColor: AppColors.peach.withOpacity(0.3),
      backgroundImage:
          photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
      child: photoUrl == null
          ? const Icon(Icons.person, size: 32, color: AppColors.softRose)
          : null,
    );
  }

  Widget _buildFeatureCard(BuildContext context, IconData icon, String label) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: AppColors.lavender),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppDimensions.spacingXs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                AppStrings.comingSoon,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
