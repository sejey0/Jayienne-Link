import 'dart:math' as math;
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
  bool _isCardHidden = false;
  bool _isBothSelected = false;

  /// Generates a smooth, graceful geodesic curved arc between two points
  List<LatLng> _generateGeodesicArc(LatLng start, LatLng end, {int segments = 24}) {
    final latDiff = end.latitude - start.latitude;
    final lngDiff = end.longitude - start.longitude;
    final distance = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);

    // Subtle curvature amplitude proportional to distance
    final archFactor = (distance * 0.08).clamp(0.0001, 0.018);

    // Normal vector perpendicular to the line connecting start and end
    final normalLat = -lngDiff;
    final normalLng = latDiff;
    final normalLen = math.sqrt(normalLat * normalLat + normalLng * normalLng);

    final unitNormalLat = normalLen > 0 ? (normalLat / normalLen) * archFactor : 0.0;
    final unitNormalLng = normalLen > 0 ? (normalLng / normalLen) * archFactor : 0.0;

    final points = <LatLng>[];
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final baseLat = start.latitude + latDiff * t;
      final baseLng = start.longitude + lngDiff * t;
      // Parabolic offset peaks smoothly at the midpoint (t = 0.5)
      final offset = 4.0 * t * (1.0 - t);
      points.add(LatLng(
        baseLat + unitNormalLat * offset,
        baseLng + unitNormalLng * offset,
      ));
    }
    return points;
  }

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
      final provider = context.read<LocationProvider>();
      if (!provider.isSharingEnabled) {
        provider.stopForegroundRecording();
      }
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
    setState(() {
      _isMeSelected = false;
      _isPartnerSelected = false;
      _isBothSelected = true;
    });
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
    setState(() {
      _isMeSelected = true;
      _isPartnerSelected = false;
      _isBothSelected = false;
    });
    final pos = provider.myLatLng;
    if (pos != null) {
      _mapController.move(pos, 15.5);
    }
  }

  void _centerPartner(LocationProvider provider) {
    setState(() {
      _isMeSelected = false;
      _isPartnerSelected = true;
      _isBothSelected = false;
    });
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
                if (!isHistoryMode)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: OfflineStatusIndicator(),
                    ),
                  ),
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
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && (_isMeSelected || _isPartnerSelected || _isBothSelected)) {
                  setState(() {
                    _isMeSelected = false;
                    _isPartnerSelected = false;
                    _isBothSelected = false;
                  });
                }
              },
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

              // Aura Radar Ripple Circles (Live Mode)
              if (!isHistoryMode && (myPos != null || partnerPos != null))
                CircleLayer(
                  circles: [
                    if (myPos != null) ...[
                      CircleMarker(
                        point: myPos,
                        radius: 36,
                        color: AppColors.softRose.withValues(alpha: 0.16),
                        borderColor: AppColors.softRose.withValues(alpha: 0.38),
                        borderStrokeWidth: 1.5,
                      ),
                      CircleMarker(
                        point: myPos,
                        radius: 14,
                        color: AppColors.softRose.withValues(alpha: 0.35),
                      ),
                    ],
                    if (partnerPos != null) ...[
                      CircleMarker(
                        point: partnerPos,
                        radius: 36,
                        color: AppColors.lavender.withValues(alpha: 0.16),
                        borderColor: AppColors.lavender.withValues(alpha: 0.38),
                        borderStrokeWidth: 1.5,
                      ),
                      CircleMarker(
                        point: partnerPos,
                        radius: 14,
                        color: AppColors.lavender.withValues(alpha: 0.35),
                      ),
                    ],
                  ],
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
              else if (!isHistoryMode && myPos != null && partnerPos != null) ...[
                () {
                  final arcPoints = _generateGeodesicArc(myPos, partnerPos);
                  return PolylineLayer(
                    polylines: [
                      // Layer 1: Outer Soft Glow Romantic Aura
                      Polyline(
                        points: arcPoints,
                        strokeWidth: 8.5,
                        color: AppColors.softRose.withValues(alpha: 0.28),
                      ),
                      // Layer 2: Main Vivid Neon Romantic Core with crisp border
                      Polyline(
                        points: arcPoints,
                        strokeWidth: 3.8,
                        color: AppColors.softRose,
                        borderColor: Colors.white.withValues(alpha: 0.95),
                        borderStrokeWidth: 1.2,
                      ),
                    ],
                  );
                }(),
              ],

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
                    // Live Mode: Midpoint Interactive Romance & Distance Badge
                    if (myPos != null && partnerPos != null) ...[
                      () {
                        final arc = _generateGeodesicArc(myPos, partnerPos);
                        final midIndex = arc.length ~/ 2;
                        final mid = arc[midIndex];
                        final compactDistance = locationProvider.distanceInMeters <= 0.0
                            ? '--'
                            : locationProvider.distanceInMeters < 1000
                                ? '${locationProvider.distanceInMeters.round()}m'
                                : '${(locationProvider.distanceInMeters / 1000).toStringAsFixed(1)}km';

                        // Calculate tangent angle along the geodesic line
                        final p1 = arc[math.max(0, midIndex - 1)];
                        final p2 = arc[math.min(arc.length - 1, midIndex + 1)];
                        final latRad = mid.latitude * math.pi / 180.0;
                        final dy = -(p2.latitude - p1.latitude);
                        final dx = (p2.longitude - p1.longitude) * math.cos(latRad);
                        final lineAngle = math.atan2(dy, dx);
                        final heartRotation = lineAngle + (math.pi / 2);

                        return Marker(
                          point: mid,
                          width: 74,
                          height: 74,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _fitBoth(locationProvider);
                            },
                            child: Transform.rotate(
                              angle: heartRotation,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glowing Aura matching the line
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.softRose.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Aligned Crisp White Border Heart
                                  const Icon(
                                    Icons.favorite,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                                  // Inner SoftRose Heart (matching polyline color)
                                  const Icon(
                                    Icons.favorite,
                                    color: AppColors.softRose,
                                    size: 54,
                                  ),
                                  // Distance Text Aligned to Heart Orientation & Matched to Heart
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4, left: 6, right: 6),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        compactDistance,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                          shadows: [
                                            Shadow(
                                              color: Color(0xFF7A1D32),
                                              blurRadius: 3,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }(),
                    ],

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
                // Satellite / Standard Map View Toggle Button
                _buildFloatingControlButton(
                  icon: isSatelliteView ? Icons.satellite_alt_rounded : Icons.map_rounded,
                  tooltip: isSatelliteView ? 'Satellite Map (Tap for Standard)' : 'Standard Map (Tap for Satellite)',
                  color: isSatelliteView ? AppColors.softRose : Colors.white,
                  iconColor: isSatelliteView ? Colors.white : const Color(0xFF1E142B),
                  isSelected: true,
                  selectedBorderColor: isSatelliteView ? AppColors.softRose : const Color(0xFF7C4DFF),
                  onPressed: () {
                    HapticFeedback.lightImpact();
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
                  iconColor: isFullscreen ? Colors.white : const Color(0xFF1E142B),
                  isSelected: isFullscreen,
                  selectedBorderColor: AppColors.softRose,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isFullscreen = !isFullscreen;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Fit Both Button (People Icon)
                _buildFloatingControlButton(
                  icon: Icons.people_alt_rounded,
                  tooltip: 'Fit Both in View',
                  color: _isBothSelected ? AppColors.softRose : Colors.white,
                  iconColor: _isBothSelected ? Colors.white : AppColors.softRose,
                  isSelected: _isBothSelected,
                  selectedBorderColor: AppColors.softRose,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _fitBoth(locationProvider);
                  },
                ),
                const SizedBox(height: 10),

                // Center Partner Button (Mini Profile Avatar)
                if (partnerUser != null || locationProvider.hasPartner) ...[
                  _buildAvatarFloatingButton(
                    photoUrl: partnerUser?.photoUrl,
                    tooltip: 'Center ${partnerUser?.displayName ?? "Partner"}',
                    borderColor: AppColors.lavender,
                    fallbackIcon: Icons.favorite_rounded,
                    isSelected: _isPartnerSelected,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _centerPartner(locationProvider);
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Center Me Button (Mini Profile Avatar or Location Pin)
                _buildAvatarFloatingButton(
                  photoUrl: currentUser?.photoUrl,
                  tooltip: 'Center Me',
                  borderColor: AppColors.softRose,
                  fallbackIcon: Icons.my_location_rounded,
                  isSelected: _isMeSelected,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _centerMe(locationProvider);
                  },
                ),
                const SizedBox(height: 10),

                // Refresh Button (Bottom White Button with Spin)
                _buildFloatingControlButton(
                  icon: Icons.refresh_rounded,
                  isLoading: isRefreshing,
                  tooltip: 'Refresh Location',
                  color: Colors.white,
                  iconColor: const Color(0xFF1E142B),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _refreshLocations();
                  },
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
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isCardHidden
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
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
                                color: AppColors.softRose.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.softRose,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locationProvider.formattedDistance,
                                    style: const TextStyle(
                                      color: Color(0xFF1E142B),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (partnerLoc != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        LiveTimeText(
                                          textBuilder: () => 'Updated ${partnerLoc.timeAgo}',
                                          style: TextStyle(
                                            color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(
                                        color: isOnline ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Fit Camera Icon Shortcut
                            IconButton(
                              icon: const Icon(Icons.fullscreen_rounded, color: AppColors.softRose, size: 22),
                              onPressed: () => _fitBoth(locationProvider),
                              tooltip: 'Fit Both in View',
                            ),

                            // Hide Card Button
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1E142B),
                                size: 24,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() => _isCardHidden = true);
                              },
                              tooltip: 'Hide Card',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Location Sharing Toggle Bar
                        const LocationShareToggle(),
                      ],
                    ),
                  ),
                  secondChild: Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isCardHidden = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: AppColors.softRose,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              locationProvider.formattedDistance,
                              style: const TextStyle(
                                color: Color(0xFF1E142B),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Color(0xFF1E142B),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
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
    bool isSelected = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? borderColor : Colors.white,
                width: isSelected ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? borderColor.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.22),
                  blurRadius: isSelected ? 10 : 6,
                  spreadRadius: isSelected ? 2 : 0,
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
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(fallbackIcon, color: borderColor, size: 22),
                        ),
                      )
                    : Center(
                        child: Icon(fallbackIcon, color: borderColor, size: 22),
                      ),
              ),
            ),
          ),
          // Selected Active Indicator Dot
          if (isSelected)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: borderColor,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.7),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 9,
                ),
              ),
            ),
        ],
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
    bool isSelected = false,
    Color? selectedBorderColor,
  }) {
    final activeBorder = selectedBorderColor ?? AppColors.softRose;
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: activeBorder, width: 2.5)
                  : Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? activeBorder.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.18),
                  blurRadius: isSelected ? 10 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: color,
              shape: const CircleBorder(),
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
          ),
          // Selected Active Indicator Dot
          if (isSelected)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeBorder,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: activeBorder.withValues(alpha: 0.7),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
