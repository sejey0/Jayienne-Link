import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../models/anniversary_request_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_card.dart';
import '../../anniversary/widgets/anniversary_card_widget.dart';
import '../../secret_media/screens/hidden_vault_screen.dart';
import '../widgets/couple_profile_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final incomingAnniversary = coupleProvider.incomingAnniversaryRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
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
            // Embedded Glassmorphism Anniversary & Live Love Counter Card
            const AnniversaryCardWidget(),
            const SizedBox(height: AppDimensions.spacingMd),
            // Link with partner card (shown when skipped)
            if (user != null && user.hasSkippedCoupleLink)
              _buildLinkPartnerCard(context, user),
            if (couple != null && incomingAnniversary.isNotEmpty)
              _buildAnniversaryRequestCard(
                context,
                incomingAnniversary.first,
              ),
            // Couple header (shown when linked)
            if (couple != null && user != null && user.hasRealPartner)
              const CoupleProfileCard(),
            const SizedBox(height: AppDimensions.spacingXl),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Column(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      'Access all features from here',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'Tap the button below, then choose a feature.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAllFeaturesModal(context),
                        icon: const Icon(Icons.dashboard_customize_outlined),
                        label: const Text('Open Features'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkPartnerCard(BuildContext context, UserModel user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingLg),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            children: [
              const Icon(
                Icons.favorite_border,
                size: 48,
                color: AppColors.softRose,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Link with your partner',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.softRose,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Connect with your partner to unlock all features',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                onPressed: () => context.push(RouteNames.coupleLink),
                icon: const Icon(Icons.link),
                label: const Text('Link Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAllFeaturesModal(BuildContext context) {
    final items = _featureItems;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isDismissible: true,
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingLg,
                    vertical: AppDimensions.spacingSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded,
                          color: AppColors.softRose),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Text(
                        'All Features',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.title),
                        subtitle: Text(item.subtitle),
                        onTap: () {
                          // Keep modal open - don't close it
                          if (item.route == RouteNames.secretMediaHiddenVault) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HiddenVaultScreen(),
                              ),
                            );
                            return;
                          }
                          context.push(item.route);
                        },
                      );
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

  String _formatAnniversary(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildAnniversaryRequestCard(
    BuildContext context,
    AnniversaryRequestModel request,
  ) {
    final coupleProvider = context.read<CoupleProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingLg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Anniversary request',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Your partner requested ${_formatAnniversary(request.proposedDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Accept',
                    variant: AppButtonVariant.secondary,
                    onPressed: () async {
                      final success = await coupleProvider
                          .acceptAnniversaryRequest(request);
                      if (!context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Anniversary updated'),
                            ),
                          );
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: AppButton(
                    label: 'Decline',
                    variant: AppButtonVariant.text,
                    onPressed: () async {
                      await coupleProvider
                          .declineAnniversaryRequest(request.id);
                      if (!context.mounted) return;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_FeatureDrawerItem> get _featureItems => const [
        _FeatureDrawerItem(
          title: 'Location',
          subtitle: 'See live location updates',
          icon: Icons.location_on_outlined,
          route: RouteNames.location,
        ),
        _FeatureDrawerItem(
          title: 'Location History',
          subtitle: 'View movement timeline',
          icon: Icons.history,
          route: RouteNames.locationHistory,
        ),
        _FeatureDrawerItem(
          title: 'Heartbeat & Messages',
          subtitle: 'Open your couple chat',
          icon: Icons.favorite_border,
          route: RouteNames.heartbeat,
        ),
        _FeatureDrawerItem(
          title: 'Mood',
          subtitle: 'Share your current feeling',
          icon: Icons.emoji_emotions_outlined,
          route: RouteNames.mood,
        ),
        _FeatureDrawerItem(
          title: 'Photo Messages',
          subtitle: 'Send and view photos',
          icon: Icons.photo_library_outlined,
          route: RouteNames.photos,
        ),
        _FeatureDrawerItem(
          title: 'Relationship Timeline',
          subtitle: 'Milestones, memories & couple analytics',
          icon: Icons.timeline_rounded,
          route: RouteNames.relationshipTimeline,
        ),
        _FeatureDrawerItem(
          title: 'Hidden Vault',
          subtitle: 'Private vault with image and video sections',
          icon: Icons.image_not_supported_outlined,
          route: RouteNames.secretMediaHiddenVault,
        ),
      ];
}

class _FeatureDrawerItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _FeatureDrawerItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}
