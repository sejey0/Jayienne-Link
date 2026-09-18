import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/router/route_names.dart';
import '../../../models/anniversary_request_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/debug_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/update_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/love_nudge_overlay_listener.dart';
import '../../../widgets/common/romantic_loading_indicator.dart';
import '../widgets/couple_hero_card.dart';
import '../widgets/daily_quote_card.dart';
import '../widgets/open_features_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.instance.checkForUpdates(context);
      }
    });

    // Refresh every 30 seconds so relative "last online" times remain fresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _getDynamicGreeting(UserModel? user, CoupleProvider coupleProvider) {
    final hour = DateTime.now().hour;

    String timeGreeting;
    if (hour >= 5 && hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour >= 12 && hour < 18) {
      timeGreeting = 'Good afternoon';
    } else {
      timeGreeting = 'Good evening';
    }

    final partner = coupleProvider.partner;
    final couple = coupleProvider.couple;

    final myName = (user != null && user.displayName.isNotEmpty)
        ? user.displayName
        : 'You';
    final partnerName = (partner != null && partner.displayName.isNotEmpty)
        ? partner.displayName
        : (couple != null && user != null
            ? couple.getPartnerName(user.uid, livePartnerName: partner?.displayName)
            : '');

    if ((coupleProvider.isLinked || partner != null) && partnerName.isNotEmpty) {
      return '$timeGreeting, $myName & $partnerName';
    } else {
      return '$timeGreeting, $myName';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final debugProvider = context.watch<DebugProvider?>();

    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final partner = coupleProvider.partner;
    final incomingAnniversary = coupleProvider.incomingAnniversaryRequests;

    if (user == null && userProvider.isLoading) {
      return const RomanticLoadingScreen(
        message: 'Opening your love space...',
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLinked = (coupleProvider.isLinked || couple != null) && partner != null;
    final greetingText = _getDynamicGreeting(user, coupleProvider);

    // Partner presence & last online status
    final partnerLoc = locationProvider.partnerLocation;
    final isAppOnline = locationProvider.isOnline;
    final isPartnerOnline = debugProvider?.simulatedPartnerOnlineStatus ??
        (locationProvider.isPartnerOnline() ||
            (partner != null &&
                isAppOnline &&
                partnerLoc != null &&
                partnerLoc.isRecent(threshold: const Duration(minutes: 3))));
    final partnerLastSeen = locationProvider.partnerLastSeen ?? partner?.updatedAt;
    final partnerName = (partner != null && partner.displayName.isNotEmpty)
        ? partner.displayName
        : (couple != null && user != null
            ? couple.getPartnerName(user.uid, livePartnerName: partner?.displayName)
            : 'Partner');

    final partnerStatusSubtitle = CoupleHeroCard.formatPartnerStatusText(
      isPartnerOnline: isPartnerOnline,
      partnerLastSeen: partnerLastSeen,
      partnerName: partnerName,
      short: false,
    );

    return LoveNudgeOverlayListener(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: isLinked ? 64.0 : null,
          title: isLinked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: AppColors.softRose,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            greetingText,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7.5,
                          height: 7.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPartnerOnline
                                ? const Color(0xFF00E676)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.3)),
                            boxShadow: isPartnerOnline
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E676)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            partnerStatusSubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isPartnerOnline
                                      ? (isDark
                                          ? const Color(0xFF69F0AE)
                                          : const Color(0xFF00897B))
                                      : (isDark
                                          ? Colors.white60
                                          : Colors.black54),
                                  fontWeight: isPartnerOnline
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 11.5,
                                  letterSpacing: 0.1,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: AppColors.softRose,
                        size: AppDimensions.iconSizeSmall,
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Text(
                        greetingText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push(RouteNames.settings);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: AppDimensions.spacingMd,
          ),
          child: Column(
            children: [
              // Unified Masterpiece Couple Hero Card (Love Counter + Avatars + Names + Vitals)
              const CoupleHeroCard(),
              const SizedBox(height: 6),

              // Link with partner card (shown when skipped)
              if (user != null && user.hasSkippedCoupleLink)
                _buildLinkPartnerCard(context, user),

              // Incoming Anniversary Request Card
              if (couple != null && incomingAnniversary.isNotEmpty)
                _buildAnniversaryRequestCard(
                  context,
                  incomingAnniversary.first,
                ),

              // Sweet Daily Romantic Notes Card
              const DailyQuoteCard(),
              const SizedBox(height: 4),

              // Features Launcher Button Card
              const OpenFeaturesCard(),
              const SizedBox(height: 28),
            ],
          ),
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
                'Link with your love',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.softRose,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Connect with your love to unlock all features',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(RouteNames.coupleLink);
                },
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
    final partner = coupleProvider.partner;
    final partnerName = (partner?.displayName.isNotEmpty == true)
        ? partner!.displayName
        : 'Your love';

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
              '$partnerName requested ${_formatAnniversary(request.proposedDate)}',
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
                      HapticFeedback.lightImpact();
                      final success = await coupleProvider
                          .acceptAnniversaryRequest(request);
                      if (!context.mounted) return;
                      if (success) {
                        SnackbarHelper.showSuccess(
                          context,
                          'Anniversary updated',
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
                      HapticFeedback.lightImpact();
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
