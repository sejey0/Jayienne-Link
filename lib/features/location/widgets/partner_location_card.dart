import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/common/app_card.dart';

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
              provider.hasPartner
                  ? 'Waiting for your person\'s location'
                  : 'Link with your person to see their location',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!provider.isOnline) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
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
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(location.latitude, location.longitude),
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.jayiennelink.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(location.latitude, location.longitude),
                  width: 40,
                  height: 40,
                  child: _buildMarker(isLive),
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
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarker(bool isLive) {
    final marker = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLive ? AppColors.softRose : AppColors.warning,
        boxShadow: [
          BoxShadow(
            color: (isLive ? AppColors.softRose : AppColors.warning)
                .withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.favorite,
        color: Colors.white,
        size: 24,
      ),
    );

    if (isLive) {
      return marker
          .animate(onPlay: (controller) => controller.repeat())
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.1, 1.1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          )
          .then()
          .scale(
            begin: const Offset(1.1, 1.1),
            end: const Offset(0.9, 0.9),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          );
    }

    return marker;
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
            decoration: BoxDecoration(
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
          isOnline ? 'Last seen' : 'Offline',
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
    final timeAgo = location.timeAgo;
    String text;

    if (location.isRecent() && isOnline) {
      text = 'Updated just now';
    } else if (!isOnline) {
      text = '$timeAgo (offline mode)';
    } else {
      text = timeAgo;
    }

    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 12,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
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
    final isOnline = provider.isOnline;

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
                    ? (location.isRecent() && isOnline
                        ? AppColors.softRose
                        : AppColors.warning)
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
              if (location != null)
                Text(
                  location.isRecent() && isOnline ? 'Live' : location.timeAgo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: location.isRecent() && isOnline
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  'Not available',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
