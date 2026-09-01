import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/mapbox_service.dart';
import 'partner_avatar_marker.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/live_time_text.dart';

/// Card showing partner's location with map preview.
/// Displays live/offline status with appropriate styling.
class PartnerLocationCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showMap;

  const PartnerLocationCard({
    super.key,
    this.onTap,
    this.showMap = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final location = provider.partnerLocation;
    final isOnline = provider.isOnline;

    if (location == null) {
      return _buildNoLocationCard(context, provider);
    }

    final isLive = location.isRecent() && isOnline;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map preview
            if (showMap)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.borderRadiusMedium),
                ),
                child: SizedBox(
                  height: 150,
                  child: _buildMapPreview(context, location, isLive),
                ),
              ),
            // Location info
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatusIndicator(context, isLive, isOnline),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Expanded(
                        child: _buildLocationText(
                            context, location, isLive, isOnline),
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  _buildTimestamp(context, location, isOnline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoLocationCard(BuildContext context, LocationProvider provider) {
    final isOnline = provider.isOnline;
    final message = !isOnline
        ? 'Offline only'
        : provider.hasPartner
            ? 'Waiting for your love\'s location'
            : 'Link with your love to see their location';

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!isOnline) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Offline mode',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview(
    BuildContext context,
    LocationModel location,
    bool isLive,
  ) {
    final locationProvider = context.watch<LocationProvider>();
    final userProvider = context.watch<UserProvider>();
    final myPos = locationProvider.myLatLng;
    final partnerPos = LatLng(location.latitude, location.longitude);
    final currentUser = userProvider.user;
    final partnerUser = locationProvider.partnerUser;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: partnerPos,
            initialZoom: myPos != null ? 13.5 : 15.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: MapboxService().getStreetsTileUrl(),
              userAgentPackageName: 'com.jayiennelink.app',
            ),
            // Connecting line between the two couple locations
            if (myPos != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [myPos, partnerPos],
                    strokeWidth: 3.5,
                    color: AppColors.softRose,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Midpoint Connection Heart Badge
                if (myPos != null)
                  Marker(
                    point: LatLng(
                      (myPos.latitude + partnerPos.latitude) / 2,
                      (myPos.longitude + partnerPos.longitude) / 2,
                    ),
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppColors.softRose, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.softRose.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: AppColors.softRose,
                        size: 14,
                      ),
                    ),
                  ),
                // My Location Profile Marker
                if (myPos != null)
                  Marker(
                    point: myPos,
                    width: 50,
                    height: 60,
                    child: PartnerAvatarMarker(
                      photoUrl: currentUser?.photoUrl,
                      partnerName: currentUser?.displayName.isNotEmpty == true
                          ? currentUser!.displayName
                          : 'You',
                      batteryLevel: locationProvider.batteryLevel,
                      batteryState: locationProvider.batteryState,
                      isCharging: locationProvider.isMyCharging,
                      isOnline: true,
                      heading: locationProvider.currentLocation?.heading,
                      speed: locationProvider.currentLocation?.speed,
                      accentColor: AppColors.softRose,
                    ),
                  ),
                // Partner Location Profile Marker
                Marker(
                  point: partnerPos,
                  width: 50,
                  height: 60,
                  child: PartnerAvatarMarker(
                    photoUrl: partnerUser?.photoUrl,
                    partnerName: partnerUser?.displayName.isNotEmpty == true
                        ? partnerUser!.displayName
                        : 'Partner',
                    batteryLevel: locationProvider.isPartnerOnline()
                        ? locationProvider.partnerBatteryLevel
                        : null,
                    isCharging: locationProvider.isPartnerCharging,
                    isOnline: locationProvider.isPartnerOnline(),
                    heading: location.heading,
                    speed: location.speed,
                    accentColor: AppColors.lavender,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Gradient overlay at bottom for better text contrast
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    bool isLive,
    bool isOnline,
  ) {
    if (isLive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: const Duration(milliseconds: 500))
              .then()
              .fadeOut(duration: const Duration(milliseconds: 500)),
          const SizedBox(width: 4),
          Text(
            'Live now',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOnline ? Icons.location_on : Icons.cloud_off,
          size: 14,
          color: AppColors.warning,
        ),
        const SizedBox(width: 4),
        Text(
          isOnline ? 'Last online' : 'Offline',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildLocationText(
    BuildContext context,
    LocationModel location,
    bool isLive,
    bool isOnline,
  ) {
    return Text(
      'Your person\'s location',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildTimestamp(
    BuildContext context,
    LocationModel location,
    bool isOnline,
  ) {
    final provider = context.watch<LocationProvider>();
    final isLive = provider.isPartnerOnline();
    return Row(
      children: [
        Icon(
          isLive ? Icons.access_time_rounded : Icons.wifi_off_rounded,
          size: 12,
          color: isLive ? const Color(0xFF2E7D32) : Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        LiveTimeText(
          textBuilder: () {
            if (isLive) {
              return 'Live • ${location.timeAgo}';
            }
            return 'Offline';
          },
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isLive ? const Color(0xFF2E7D32) : Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Compact card for home screen grid
class PartnerLocationCardCompact extends StatelessWidget {
  final VoidCallback? onTap;

  const PartnerLocationCardCompact({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final location = provider.partnerLocation;
    final isLive = provider.isPartnerOnline();

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingSm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 28,
                color: location != null
                    ? (isLive ? AppColors.softRose : AppColors.warning)
                    : AppColors.lavender,
              ),
              const SizedBox(height: 4),
              Text(
                'Location',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              if (location != null && isLive)
                LiveTimeText(
                  textBuilder: () => 'Live • ${location.timeAgo}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  'Offline',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
