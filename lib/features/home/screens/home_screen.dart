import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../models/anniversary_request_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_button.dart';
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
    final incomingAnniversary = coupleProvider.incomingAnniversaryRequests;
    final outgoingAnniversary = coupleProvider.outgoingAnniversaryRequests;
    final pendingAnniversary =
        outgoingAnniversary.isNotEmpty ? outgoingAnniversary.first : null;

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
                          _buildAvatar(
                              context, coupleProvider.partner?.photoUrl),
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
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        couple.anniversary != null
                            ? 'anniversary: ${_formatAnniversary(couple.anniversary!)}'
                            : 'anniversary: not set',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      if (couple.anniversary != null) ...[
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          _buildAnniversaryStatus(couple.daysTogether),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppDimensions.spacingSm),
                      if (pendingAnniversary != null)
                        Text(
                          'Anniversary request pending for ${_formatAnniversary(pendingAnniversary.proposedDate)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                          textAlign: TextAlign.center,
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
                _buildHeartbeatCard(context),
                _buildMoodCard(context),
                _buildPhotosCard(context),
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
      backgroundImage: _getProfileImageProvider(photoUrl),
      child: photoUrl == null
          ? const Icon(Icons.person, size: 32, color: AppColors.softRose)
          : null,
    );
  }

  /// Get appropriate ImageProvider for profile photos (supports both network URLs and Base64)
  ImageProvider? _getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;

    debugPrint(
        'Loading image from: ${photoUrl.substring(0, photoUrl.length > 50 ? 50 : photoUrl.length)}...');

    // Check if it's a Base64 data URL
    if (photoUrl.startsWith('data:image/')) {
      try {
        // Extract Base64 data from data URL
        final base64String = photoUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        debugPrint('✅ Loaded Base64 image (${bytes.length} bytes)');
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('❌ Base64 decode failed: $e');
        return null;
      }
    } else {
      // Regular network URL, use CachedNetworkImageProvider
      debugPrint('✅ Loading network image');
      return CachedNetworkImageProvider(photoUrl);
    }
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

  Widget _buildHeartbeatCard(BuildContext context) {
    return AppCard(
      onTap: () => context.push(RouteNames.heartbeat),
      padding: const EdgeInsets.all(AppDimensions.spacingSm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, size: 32, color: AppColors.softRose),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Heartbeat\n&\nMessages',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  height: 1.05,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Open chat',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(BuildContext context) {
    return AppCard(
      onTap: () => context.push(RouteNames.photos),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined,
              size: 36, color: AppColors.lavender),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Photo Messages',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Share photos',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCard(BuildContext context) {
    return AppCard(
      onTap: () => context.push(RouteNames.mood),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_emotions_outlined,
              size: 36, color: AppColors.lavender),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Mood',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Share feelings',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _buildAnniversaryStatus(int daysTogether) {
    if (daysTogether <= 0) {
      return 'Just started!';
    }

    if (daysTogether % 365 == 0) {
      final years = daysTogether ~/ 365;
      return '${_formatOrdinal(years)} year anniversary';
    }

    final years = daysTogether ~/ 365;
    final remainingDays = daysTogether % 365;
    final months = (remainingDays / 30).floor();

    if (years == 0) {
      final monthCount = months == 0 ? 1 : months;
      return '${_formatCount(monthCount, 'month')} and counting';
    }

    final monthCount = months == 0 ? 1 : months;
    return '${_formatCount(years, 'year')} and ${_formatCount(monthCount, 'month')} and counting';
  }

  String _formatOrdinal(int value) {
    final absValue = value.abs();
    final mod100 = absValue % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return '${value}th';
    }
    switch (absValue % 10) {
      case 1:
        return '${value}st';
      case 2:
        return '${value}nd';
      case 3:
        return '${value}rd';
      default:
        return '${value}th';
    }
  }

  String _formatCount(int value, String unit) {
    final label = value == 1 ? unit : '${unit}s';
    return '$value $label';
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
