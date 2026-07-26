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
import '../widgets/couple_profile_card.dart';
import '../widgets/open_features_card.dart';

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
            const OpenFeaturesCard(),
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

}
