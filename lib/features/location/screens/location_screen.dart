import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../services/offline_location_service.dart';
import '../widgets/location_share_toggle.dart';
import '../widgets/offline_status_indicator.dart';

/// Main location sharing screen showing both user and partner locations.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final MapController _mapController = MapController();
  bool _showingPartner = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocations();
    });
  }

  Future<void> _refreshLocations() async {
    final provider = context.read<LocationProvider>();
    await provider.captureLocation();
    await provider.refreshPartnerLocation();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final couple = coupleProvider.couple;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location'),
        actions: [
          const OfflineStatusIndicator(),
          const SizedBox(width: AppDimensions.spacingSm),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push(RouteNames.locationHistory),
            tooltip: 'Location history',
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          const OfflineBanner(),
          // Map
          Expanded(
            child: _buildMap(context, locationProvider),
          ),
          // Bottom controls
          _buildBottomSheet(context, locationProvider, couple?.coupleName),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, LocationProvider provider) {
    final myLocation = provider.currentLocation;
    final partnerLocation = provider.partnerLocation;
    final isOnline = provider.isOnline;

    // Default center (if no locations available)
    LatLng center = const LatLng(0, 0);
    double zoom = 2;

    // Determine map center
    if (_showingPartner && partnerLocation != null) {
      center = LatLng(partnerLocation.latitude, partnerLocation.longitude);
      zoom = 15;
    } else if (myLocation != null) {
      center = LatLng(myLocation.latitude, myLocation.longitude);
      zoom = 15;
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.jayiennelink.app',
            ),
            MarkerLayer(
              markers: [
                // My location marker
                if (myLocation != null)
                  Marker(
                    point: LatLng(myLocation.latitude, myLocation.longitude),
                    width: 40,
                    height: 40,
                    child: _buildMyMarker(context, provider.isSharingEnabled),
                  ),
                // Partner's location marker
                if (partnerLocation != null)
                  Marker(
                    point: LatLng(
                      partnerLocation.latitude,
                      partnerLocation.longitude,
                    ),
                    width: 50,
                    height: 50,
                    child: _buildPartnerMarker(
                      context,
                      partnerLocation.isRecent() && isOnline,
                    ),
                  ),
              ],
            ),
          ],
        ),
        // Map controls overlay
        Positioned(
          top: AppDimensions.spacingMd,
          right: AppDimensions.spacingMd,
          child: Column(
            children: [
              _buildMapButton(
                icon: Icons.my_location,
                onPressed: () {
                  if (myLocation != null) {
                    setState(() => _showingPartner = false);
                    _mapController.move(
                      LatLng(myLocation.latitude, myLocation.longitude),
                      15,
                    );
                  }
                },
                isActive: !_showingPartner,
                tooltip: 'My location',
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              _buildMapButton(
                icon: Icons.favorite,
                onPressed: () {
                  if (partnerLocation != null) {
                    setState(() => _showingPartner = true);
                    _mapController.move(
                      LatLng(
                        partnerLocation.latitude,
                        partnerLocation.longitude,
                      ),
                      15,
                    );
                  }
                },
                isActive: _showingPartner,
                tooltip: 'Your person',
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              _buildMapButton(
                icon: Icons.refresh,
                onPressed: _refreshLocations,
                isActive: false,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // No location message
        if (myLocation == null && partnerLocation == null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              margin: const EdgeInsets.all(AppDimensions.spacingLg),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ??
                    Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusMedium,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_off_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    'No locations yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    'Enable location sharing to see where you and your person are.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMyMarker(BuildContext context, bool isSharing) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lavender,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildPartnerMarker(BuildContext context, bool isLive) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse animation ring (only when live)
        if (isLive)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softRose.withOpacity(0.2),
            ),
          ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLive ? AppColors.softRose : AppColors.warning,
            border: Border.all(color: Colors.white, width: 2),
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
        ),
      ],
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? AppColors.softRose : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
        elevation: 4,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacingSm),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.deepCharcoal,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(
    BuildContext context,
    LocationProvider provider,
    String? coupleName,
  ) {
    final partnerLocation = provider.partnerLocation;
    final myLocation = provider.currentLocation;
    final isOnline = provider.isOnline;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Partner status section
            if (partnerLocation != null) ...[
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.softRose.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: AppColors.softRose,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Person',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          partnerLocation.isRecent() && isOnline
                              ? 'Online now'
                              : !isOnline
                                  ? '${partnerLocation.timeAgo} (offline mode)'
                                  : partnerLocation.timeAgo,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: partnerLocation.isRecent() && isOnline
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // History button for partner
                  TextButton.icon(
                    onPressed: () => _goToHistoryTab(context, 1), // Partner tab
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.softRose,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  if (!isOnline)
                    const Icon(
                      Icons.cloud_off,
                      color: AppColors.warning,
                      size: 20,
                    ),
                ],
              ),
              const Divider(height: AppDimensions.spacingLg * 2),
            ],
            // My Location section
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lavender.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.lavender,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Location',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        myLocation != null
                            ? (myLocation.isRecent()
                                ? 'Updated just now'
                                : myLocation.timeAgo)
                            : 'Not shared yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: myLocation != null && myLocation.isRecent()
                                  ? AppColors.success
                                  : Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
                // History button for my locations
                TextButton.icon(
                  onPressed: () => _goToHistoryTab(context, 0), // My locations tab
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.lavender,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            // Location sharing toggle
            const LocationShareToggle(),
            const SizedBox(height: AppDimensions.spacingMd),
            // Sync status
            if (provider.pendingSyncCount > 0 && !provider.isOnline)
              Text(
                '${provider.pendingSyncCount} locations saved offline',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  void _goToHistoryTab(BuildContext context, int tabIndex) {
    context.push('${RouteNames.locationHistory}?tab=$tabIndex');
  }
}
