import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/offline_location_service.dart';
import '../../../widgets/common/live_time_text.dart';
import '../widgets/location_history_sheet.dart';
import '../widgets/location_share_toggle.dart';
import '../widgets/offline_status_indicator.dart';
import '../widgets/partner_avatar_marker.dart';

/// Senior GIS Live Location & Mapping Screen built with flutter_map, latlong2, and geolocator.
/// Features:
/// - Real-time partner location lerp interpolation with direction arrow heading
/// - Geodesic distance calculation ("450 m away" / "12.4 km away")
/// - Battery-smart device location stream with 10m filter
/// - Bounding box camera positioning (Fit Both)
/// - Location History & Route Playback with PolylineLayer & Timeline scrubbing
/// - Custom partner avatar marker with battery status badge & activity status
class LocationMapScreen extends StatefulWidget {
  const LocationMapScreen({super.key});

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  final MapController _mapController = MapController();

  bool _isPartnerSelected = false;
  bool _isMeSelected = false;

  String? _lastHistoryOwnerId;
  DateTime? _lastHistoryDate;
  int _lastHistoryLength = 0;
  int _lastPlaybackIndex = -1;
  bool _isRefreshing = false;
  bool _isSatelliteView = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<LocationProvider>();

      // Auto-resume location tracking if sharing is enabled and permissions allow
      if (provider.isSharingEnabled &&
          (provider.permissionStatus == LocationPermissionStatus.whileInUse ||
              provider.permissionStatus == LocationPermissionStatus.always)) {
        await provider.startTracking();
      }

      _refreshLocations();
      provider.startForegroundRecording();
    });
  }

  @override
  void deactivate() {
    if (mounted) {
      context.read<LocationProvider>().stopForegroundRecording();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _refreshLocations() async {
    if (!mounted || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<LocationProvider>();
      await provider.captureLocation();
      if (!mounted) return;
      await provider.refreshPartnerLocation();
      if (!mounted) return;
      await provider.refreshUserData();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _fitBoth(LocationProvider provider) {
    final bounds = provider.coupleBounds;
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(70.0),
        ),
      );
    } else if (provider.myLatLng != null) {
      _mapController.move(provider.myLatLng!, 15.0);
    }
  }

  void _centerMe(LocationProvider provider) {
    final pos = provider.myLatLng;
    if (pos != null) {
      _mapController.move(pos, 15.5);
    }
  }

  void _centerPartner(LocationProvider provider) {
    final pos = provider.partnerLatLng;
    if (pos != null) {
      _mapController.move(pos, 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();

    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.user ?? locationProvider.currentUser;

    final myPos = locationProvider.myLatLng;
    final partnerPos = locationProvider.interpolatedPartnerLatLng;
    final partnerUser = locationProvider.partnerUser;
    final partnerLoc = locationProvider.partnerLocation;
    final isOnline = locationProvider.isOnline;

    final isHistoryMode = locationProvider.isHistoryMode;
    final historyPoints = locationProvider.historyPolylinePoints;
    final playbackPos = locationProvider.playbackLatLng;
    final playbackLoc = locationProvider.currentPlaybackLocation;

    final isSatelliteView = _isSatelliteView == true;
    final isFullscreen = _isFullscreen == true;
    final isPartnerSelected = _isPartnerSelected == true;
    final isMeSelected = _isMeSelected == true;
    final isRefreshing = _isRefreshing == true;

    final myId = currentUser?.id ?? locationProvider.userId;
    final partnerId = partnerUser?.id ?? locationProvider.partnerId;
    final isMyRoute = locationProvider.historyOwnerId == myId;

    final activeAvatarUrl = isMyRoute ? currentUser?.photoUrl : partnerUser?.photoUrl;
    final activeName = isMyRoute
        ? (currentUser?.displayName.isNotEmpty == true ? currentUser!.displayName : 'You')
        : (partnerUser?.displayName ?? 'Partner');
    final activeAccent = isMyRoute ? AppColors.lavender : AppColors.softRose;

    // Auto-center / fit bounds when route or owner changes in History Mode
    if (isHistoryMode && historyPoints.isNotEmpty) {
      if (_lastHistoryOwnerId != locationProvider.historyOwnerId ||
          _lastHistoryDate != locationProvider.selectedHistoryDate ||
          _lastHistoryLength != historyPoints.length) {
        _lastHistoryOwnerId = locationProvider.historyOwnerId;
        _lastHistoryDate = locationProvider.selectedHistoryDate;
        _lastHistoryLength = historyPoints.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (historyPoints.length == 1) {
            _mapController.move(historyPoints.first, 15.5);
          } else if (historyPoints.length > 1) {
            final bounds = LatLngBounds.fromPoints(historyPoints);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(40, 60, 40, 240),
              ),
            );
          }
        });
      }
    } else if (!isHistoryMode) {
      _lastHistoryOwnerId = null;
      _lastHistoryDate = null;
      _lastHistoryLength = 0;
      _lastPlaybackIndex = -1;
    }

    // Follow camera during route playback
    if (isHistoryMode &&
        locationProvider.isPlayingRoute &&
        playbackPos != null &&
        _lastPlaybackIndex != locationProvider.playbackIndex) {
      _lastPlaybackIndex = locationProvider.playbackIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(playbackPos, _mapController.camera.zoom);
      });
    }

    final initialCenter = playbackPos ?? partnerPos ?? myPos ?? const LatLng(0, 0);

    return Scaffold(
      appBar: isFullscreen
          ? null
          : AppBar(
              title: Text(
                isHistoryMode ? 'Route History' : 'Live Location',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.softRose, AppColors.lavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
              actions: [
                if (!isHistoryMode) const OfflineStatusIndicator(),
                const SizedBox(width: AppDimensions.spacingSm),
                // Toggle History Mode Button
                IconButton(
                  icon: Icon(
                    isHistoryMode ? Icons.map_rounded : Icons.route_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    locationProvider.toggleHistoryMode(!isHistoryMode);
                  },
                  tooltip: isHistoryMode ? 'Back to Live Map' : 'Route History Playback',
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push(RouteNames.locationHistory);
                  },
                  tooltip: 'Location history list',
                ),
              ],
              elevation: 0,
            ),
      body: Stack(
        children: [
          // 1. FlutterMap OpenStreetMap / Satellite Canvas
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: partnerPos != null ? 14.5 : 12.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Base Map Layer (OpenStreetMap / Satellite Imagery)
              TileLayer(
                urlTemplate: isSatelliteView
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jayiennelink.app',
                maxZoom: 19,
              ),

              // Overlay Layer for Hybrid Satellite View (Boundaries, Roads & Place Names)
              if (isSatelliteView)
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.jayiennelink.app',
                  maxZoom: 19,
                ),

              // Polyline Layer for History Mode OR Live connection line
              if (isHistoryMode && historyPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: historyPoints,
                      strokeWidth: 4.5,
                      color: Colors.purpleAccent,
                      borderColor: Colors.deepPurple.shade900,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                )
              else if (!isHistoryMode && myPos != null && partnerPos != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [myPos, partnerPos],
                      strokeWidth: 3.5,
                      color: AppColors.softRose,
                    ),
                  ],
                ),

              // Marker Layer
              MarkerLayer(
                markers: [
                  if (isHistoryMode) ...[
                    // Start Point Marker
                    if (historyPoints.isNotEmpty)
                      Marker(
                        point: historyPoints.first,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent.shade700,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                        ),
                      ),

                    // End Point Marker
                    if (historyPoints.length > 1)
                      Marker(
                        point: historyPoints.last,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 14),
                        ),
                      ),

                    // Active Playback Marker
                    if (playbackPos != null)
                      Marker(
                        point: playbackPos,
                        width: 76,
                        height: 86,
                        child: PartnerAvatarMarker(
                          photoUrl: activeAvatarUrl,
                          partnerName: activeName,
                          batteryLevel: playbackLoc?.batteryLevel,
                          batteryState: BatteryState.unknown,
                          heading: playbackLoc?.heading,
                          speed: playbackLoc?.speed,
                          accentColor: activeAccent,
                          isSelected: true,
                          onTap: () {
                            _mapController.move(playbackPos, 16.0);
                          },
                        ),
                      ),
                  ] else ...[
                    // Live Mode: Midpoint Heart Badge
                    if (myPos != null && partnerPos != null)
                      Marker(
                        point: LatLng(
                          (myPos.latitude + partnerPos.latitude) / 2,
                          (myPos.longitude + partnerPos.longitude) / 2,
                        ),
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: AppColors.softRose, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.softRose.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: AppColors.softRose,
                            size: 16,
                          ),
                        ),
                      ),

                    // My Location Profile Marker
                    if (myPos != null)
                      Marker(
                        point: myPos,
                        width: 76,
                        height: 86,
                        child: PartnerAvatarMarker(
                          photoUrl: currentUser?.photoUrl,
                          partnerName: currentUser?.displayName.isNotEmpty == true
                              ? currentUser!.displayName
                              : 'You',
                          batteryLevel: locationProvider.batteryLevel,
                          batteryState: locationProvider.batteryState,
                          heading: locationProvider.currentLocation?.heading,
                          speed: locationProvider.currentLocation?.speed,
                          accentColor: AppColors.softRose,
                          isSelected: isMeSelected,
                          onTap: () {
                            setState(() {
                              _isMeSelected = !isMeSelected;
                              if (_isMeSelected) _isPartnerSelected = false;
                            });
                            _mapController.move(myPos, 16.0);
                          },
                        ),
                      ),

                    // Partner Location Profile Marker
                    if (partnerPos != null)
                      Marker(
                        point: partnerPos,
                        width: 76,
                        height: 86,
                        child: PartnerAvatarMarker(
                          photoUrl: partnerUser?.photoUrl,
                          partnerName: partnerUser?.displayName ?? 'Partner',
                          batteryLevel: partnerLoc?.batteryLevel,
                          batteryState: BatteryState.unknown,
                          heading: partnerLoc?.heading,
                          speed: partnerLoc?.speed,
                          accentColor: AppColors.lavender,
                          isSelected: isPartnerSelected,
                          onTap: () {
                            setState(() {
                              _isPartnerSelected = !isPartnerSelected;
                              if (_isPartnerSelected) _isMeSelected = false;
                            });
                            _mapController.move(partnerPos, 16.0);
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),

          // Floating Fullscreen Exit Button (Top Left when in fullscreen)
          if (isFullscreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: _buildFloatingControlButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Exit Fullscreen',
                color: Colors.white,
                iconColor: AppColors.deepCharcoal,
                onPressed: () {
                  setState(() {
                    _isFullscreen = false;
                  });
                },
              ),
            ),

          // 2. Floating Action Controls (Satellite, Fullscreen, Fit Both, Center Partner, Center Me, Refresh)
          Positioned(
            right: 16,
            bottom: isFullscreen ? 24 : (isHistoryMode ? 280 : 220),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Satellite View Toggle Button
                _buildFloatingControlButton(
                  icon: isSatelliteView ? Icons.map_rounded : Icons.satellite_alt_rounded,
                  tooltip: isSatelliteView ? 'Switch to Standard Map' : 'Switch to Satellite View',
                  color: isSatelliteView ? AppColors.softRose : Colors.white,
                  iconColor: isSatelliteView ? Colors.white : AppColors.deepCharcoal,
                  onPressed: () {
                    setState(() {
                      _isSatelliteView = !isSatelliteView;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Fullscreen Map Toggle Button
                _buildFloatingControlButton(
                  icon: isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  tooltip: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen Map',
                  color: isFullscreen ? AppColors.softRose : Colors.white,
                  iconColor: isFullscreen ? Colors.white : AppColors.deepCharcoal,
                  onPressed: () {
                    setState(() {
                      _isFullscreen = !isFullscreen;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Fit Both Button (Pink Button with people icon)
                _buildFloatingControlButton(
                  icon: Icons.people_alt_rounded,
                  tooltip: 'Fit Both in View',
                  color: AppColors.softRose,
                  iconColor: Colors.white,
                  onPressed: () => _fitBoth(locationProvider),
                ),
                const SizedBox(height: 10),

                // Center Partner Button (Mini Profile Avatar)
                if (partnerUser != null || locationProvider.hasPartner) ...[
                  _buildAvatarFloatingButton(
                    photoUrl: partnerUser?.photoUrl,
                    tooltip: 'Center ${partnerUser?.displayName ?? "Partner"}',
                    borderColor: AppColors.lavender,
                    fallbackIcon: Icons.favorite_rounded,
                    onPressed: () => _centerPartner(locationProvider),
                  ),
                  const SizedBox(height: 10),
                ],

                // Center Me Button (Mini Profile Avatar or Location Pin)
                _buildAvatarFloatingButton(
                  photoUrl: currentUser?.photoUrl,
                  tooltip: 'Center Me',
                  borderColor: AppColors.softRose,
                  fallbackIcon: Icons.my_location_rounded,
                  onPressed: () => _centerMe(locationProvider),
                ),
                const SizedBox(height: 10),

                // Refresh Button (Bottom White Button with Spin)
                _buildFloatingControlButton(
                  icon: Icons.refresh_rounded,
                  isLoading: isRefreshing,
                  tooltip: 'Refresh Location',
                  color: Colors.white,
                  iconColor: AppColors.deepCharcoal,
                  onPressed: _refreshLocations,
                ),
              ],
            ),
          ),

          // 3. Bottom Panel: Location History Sheet (in History Mode) OR Live Info Card (in Live Mode)
          if (!isFullscreen) ...[
            if (isHistoryMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LocationHistorySheet(
                  onClose: () {
                    locationProvider.toggleHistoryMode(false);
                  },
                ),
              )
            else
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Distance & Status Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.softRose.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.softRose,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locationProvider.formattedDistance,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk_rounded,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      locationProvider.partnerActivityStatus,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    if (partnerLoc != null) ...[
                                      Text(
                                        ' · ',
                                        style: TextStyle(color: Colors.grey.shade400),
                                      ),
                                      LiveTimeText(
                                        textBuilder: () => partnerLoc.timeAgo,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isOnline ? AppColors.success : AppColors.warning,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Fit Camera Icon Shortcut
                          IconButton(
                            icon: const Icon(Icons.fullscreen_rounded, color: AppColors.softRose),
                            onPressed: () => _fitBoth(locationProvider),
                            tooltip: 'Fit Both in View',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location Sharing Toggle Bar
                      const LocationShareToggle(),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarFloatingButton({
    required String? photoUrl,
    required String tooltip,
    required Color borderColor,
    required IconData fallbackIcon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(fallbackIcon, color: borderColor, size: 20),
                    ),
                  )
                : Center(
                    child: Icon(fallbackIcon, color: borderColor, size: 20),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControlButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onPressed,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      icon,
                      color: iconColor,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
