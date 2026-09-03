import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../models/location_model.dart';
import '../../../models/mapbox_place_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/mapbox_service.dart';
import '../../../services/offline_location_service.dart';
import '../../../widgets/common/live_time_text.dart';
import '../widgets/location_history_sheet.dart';
import '../widgets/mapbox_search_bar.dart';
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

class _LocationMapScreenState extends State<LocationMapScreen>
    with SingleTickerProviderStateMixin {
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
  bool _isBothSelected = false;
  bool _isSearching = false;
  bool _isSideMenuCollapsed = false;
  MapboxPlace? _searchedPlace;

  // Driving Car Animation State
  late AnimationController _driveAnimationController;
  LatLng? _interpolatedCarPos;
  double _interpolatedCarHeading = 0.0;
  LatLng? _driveStartPos;
  LatLng? _driveEndPos;
  double _driveStartHeading = 0.0;
  double _driveTargetHeading = 0.0;

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

  double _calculateBearing(LatLng from, LatLng to) {
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      return _interpolatedCarHeading;
    }
    final bearing = Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    return (bearing + 360) % 360;
  }

  void _syncDrivingAnimation(LocationProvider provider, List<LatLng> historyPoints) {
    if (!provider.isHistoryMode || historyPoints.isEmpty) {
      if (_driveAnimationController.isAnimating) {
        _driveAnimationController.stop();
      }
      _interpolatedCarPos = null;
      return;
    }

    final currentIndex = provider.playbackIndex.clamp(0, historyPoints.length - 1);
    final isPlaying = provider.isPlayingRoute;

    if (!isPlaying) {
      if (_driveAnimationController.isAnimating) {
        _driveAnimationController.stop();
      }
      _interpolatedCarPos = historyPoints[currentIndex];
      _lastPlaybackIndex = currentIndex;

      if (currentIndex < historyPoints.length - 1) {
        _interpolatedCarHeading = _calculateBearing(
          historyPoints[currentIndex],
          historyPoints[currentIndex + 1],
        );
      }
      return;
    }

    // If playing and index stepped forward to a new destination
    if (_lastPlaybackIndex != currentIndex) {
      final prevIndex = _lastPlaybackIndex >= 0
          ? _lastPlaybackIndex
          : (currentIndex > 0 ? currentIndex - 1 : 0);
      _lastPlaybackIndex = currentIndex;

      final startPos = _interpolatedCarPos ?? historyPoints[prevIndex.clamp(0, historyPoints.length - 1)];
      final endPos = historyPoints[currentIndex];

      _driveStartPos = startPos;
      _driveEndPos = endPos;
      _driveStartHeading = _interpolatedCarHeading;
      _driveTargetHeading = _calculateBearing(startPos, endPos);

      final speed = provider.playbackSpeed > 0 ? provider.playbackSpeed : 1.0;
      final durationMs = (1000 / speed).round().clamp(150, 3000);

      _driveAnimationController.duration = Duration(milliseconds: durationMs);
      _driveAnimationController.forward(from: 0.0);
    }
  }

  @override
  void initState() {
    super.initState();

    _driveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
        if (!mounted) return;
        final t = _driveAnimationController.value;
        if (_driveStartPos != null && _driveEndPos != null) {
          final lat = _driveStartPos!.latitude +
              (_driveEndPos!.latitude - _driveStartPos!.latitude) * t;
          final lng = _driveStartPos!.longitude +
              (_driveEndPos!.longitude - _driveStartPos!.longitude) * t;
          _interpolatedCarPos = LatLng(lat, lng);

          final diff = ((_driveTargetHeading - _driveStartHeading + 540) % 360) - 180;
          _interpolatedCarHeading = ((_driveStartHeading + diff * t) + 360) % 360;

          // Camera smooth follow during driving playback
          _mapController.move(
            _interpolatedCarPos!,
            _mapController.camera.zoom.clamp(14.0, 17.5),
          );
          setState(() {});
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<LocationProvider>();

      // Auto-start location tracking & live sync without needing to tap anything
      if (provider.permissionStatus.canTrack) {
        await provider.startTracking();
      } else {
        await provider.requestPermission();
        if (provider.permissionStatus.canTrack) {
          await provider.startTracking();
        }
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
    _driveAnimationController.dispose();
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

  void _fitRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15.5);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 240),
        maxZoom: 16.5,
        minZoom: 12.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = context.watch<LocationProvider>();

    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.user ?? locationProvider.currentUser;

    final myPos = locationProvider.myLatLng;
    final partnerPos = locationProvider.interpolatedPartnerLatLng;
    final partnerUser = locationProvider.partnerUser;
    final partnerLoc = locationProvider.partnerLocation;

    final isHistoryMode = locationProvider.isHistoryMode;
    final historyPoints = locationProvider.historyPolylinePoints;

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
        : (partnerUser?.displayName.isNotEmpty == true ? partnerUser!.displayName : 'Partner');
    final activeAccent = isMyRoute ? AppColors.lavender : AppColors.softRose;

    // Traveled path (up to current car position) vs Remaining path
    final playbackIdx = locationProvider.playbackIndex;
    if (isHistoryMode && historyPoints.isNotEmpty) {
      _syncDrivingAnimation(locationProvider, historyPoints);
    }

    final activeCarPos = _interpolatedCarPos ??
        (playbackIdx < historyPoints.length ? historyPoints[playbackIdx] : null);

    final List<LatLng> traveledPoints;
    final List<LatLng> remainingPoints;
    if (isHistoryMode && historyPoints.isNotEmpty) {
      if (activeCarPos != null && playbackIdx < historyPoints.length) {
        traveledPoints = [
          ...historyPoints.take(playbackIdx),
          activeCarPos,
        ];
        remainingPoints = [
          activeCarPos,
          ...historyPoints.skip(playbackIdx),
        ];
      } else {
        traveledPoints = historyPoints.take(playbackIdx + 1).toList();
        remainingPoints = historyPoints.skip(playbackIdx).toList();
      }
    } else {
      traveledPoints = <LatLng>[];
      remainingPoints = <LatLng>[];
    }

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
          _fitRoute(historyPoints);
        });
      }
    } else if (!isHistoryMode) {
      _lastHistoryOwnerId = null;
      _lastHistoryDate = null;
      _lastHistoryLength = 0;
      _lastPlaybackIndex = -1;
    }

    final initialCenter = activeCarPos ?? partnerPos ?? myPos ?? const LatLng(0, 0);

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
              minZoom: 3.0,
              maxZoom: 20.0,
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
              // Base Map Layer (Mapbox Satellite Streets Hybrid / Mapbox Streets / Fallbacks)
              TileLayer(
                urlTemplate: isSatelliteView
                    ? MapboxService().getSatelliteTileUrl()
                    : MapboxService().getStreetsTileUrl(),
                userAgentPackageName: 'com.jayiennelink.app',
                maxNativeZoom: 18,
                maxZoom: 22,
                keepBuffer: 3,
                panBuffer: 1,
              ),

              // Overlay Layer for Hybrid Satellite View (Boundaries & Places fallback if Mapbox token is not configured)
              if (isSatelliteView && !MapboxService().hasToken)
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.jayiennelink.app',
                  maxNativeZoom: 18,
                  maxZoom: 22,
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

              // Polyline Layer for History Mode (Traveled Path & Upcoming Path)
              if (isHistoryMode && historyPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // 1. Upcoming Route Ahead (Dashed / Dotted Gap Line)
                    if (remainingPoints.length > 1)
                      Polyline(
                        points: remainingPoints,
                        strokeWidth: 3.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : const Color(0xFF6B5F7F),
                        isDotted: true,
                      ),
                    // 2. Traveled Route Outer Soft Glow Aura
                    if (traveledPoints.length > 1)
                      Polyline(
                        points: traveledPoints,
                        strokeWidth: 7.5,
                        color: activeAccent.withValues(alpha: 0.32),
                      ),
                    // 3. Traveled Route Crisp Core Line
                    if (traveledPoints.length > 1)
                      Polyline(
                        points: traveledPoints,
                        strokeWidth: 4.2,
                        color: activeAccent,
                        borderColor: Colors.white.withValues(alpha: 0.95),
                        borderStrokeWidth: 1.0,
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
                    // Start Point Marker (Green 🟢)
                    if (historyPoints.isNotEmpty)
                      Marker(
                        point: historyPoints.first,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00E676),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                        ),
                      ),

                    // End Point Marker (Destination Flag 🏁)
                    if (historyPoints.length > 1)
                      Marker(
                        point: historyPoints.last,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMyRoute ? AppColors.lavender : AppColors.softRose,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 13),
                        ),
                      ),

                    // Active Moving Driving Vehicle Marker (Fit to road line)
                    if (activeCarPos != null)
                      Marker(
                        point: activeCarPos,
                        width: 44,
                        height: 48,
                        child: _buildDrivingCarMarker(
                          photoUrl: activeAvatarUrl,
                          name: activeName,
                          accentColor: activeAccent,
                          heading: _interpolatedCarHeading,
                          isPlaying: locationProvider.isPlayingRoute,
                          isDark: isDark,
                        ),
                      ),
                  ] else ...[
                    // Live Mode: Midpoint Interactive Romance & Distance Badge
                    if (myPos != null && partnerPos != null) ...[
                      () {
                        final arc = _generateGeodesicArc(myPos, partnerPos);
                        final midIndex = arc.length ~/ 2;
                        final mid = arc[midIndex];
                        final dist = locationProvider.distanceInMeters;
                        final compactDistance = (dist == null || dist <= 0.0)
                            ? '--'
                            : dist < 1000
                                ? '${dist.round()}m'
                                : '${(dist / 1000).toStringAsFixed(1)}km';

                        return Marker(
                          point: mid,
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _fitBoth(locationProvider);
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing Aura matching the line
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.softRose.withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                // Outer White Border Heart for depth
                                const Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: 62,
                                ),
                                // Inner SoftRose Heart (always upright & beautiful)
                                const Icon(
                                  Icons.favorite,
                                  color: AppColors.softRose,
                                  size: 54,
                                ),
                                // Distance Text Centered Upright Inside Heart
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, left: 6, right: 6),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      compactDistance,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
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
                          isCharging: locationProvider.isMyCharging,
                          isOnline: true,
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
                          partnerName: partnerUser?.displayName.isNotEmpty == true
                              ? partnerUser!.displayName
                              : 'Partner',
                          batteryLevel: locationProvider.isPartnerOnline()
                              ? locationProvider.partnerBatteryLevel
                              : null,
                          isCharging: locationProvider.isPartnerCharging,
                          isOnline: locationProvider.isPartnerOnline(),
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

                    // Mapbox Search Result Pin Marker with Distance
                    if (_searchedPlace != null) () {
                      final metersFromMe = myPos != null
                          ? Geolocator.distanceBetween(
                              myPos.latitude,
                              myPos.longitude,
                              _searchedPlace!.coordinates.latitude,
                              _searchedPlace!.coordinates.longitude,
                            )
                          : null;
                      final distanceText = metersFromMe != null
                          ? (metersFromMe < 1000
                              ? '${metersFromMe.toStringAsFixed(0)} m away'
                              : '${(metersFromMe / 1000.0).toStringAsFixed(1)} km away')
                          : null;

                      return Marker(
                        point: _searchedPlace!.coordinates,
                        width: 240,
                        height: 95,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xF51E142B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.softRose.withValues(alpha: 0.8),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _searchedPlace!.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => _clearSearchedPlaceAndCenterMe(locationProvider, myPos),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (distanceText != null) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.softRose.withValues(alpha: 0.28),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        distanceText,
                                        style: const TextStyle(
                                          color: AppColors.softRose,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.softRose,
                              size: 28,
                            ),
                          ],
                        ),
                      );
                    }(),
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

          // Mapbox Autocomplete Search Bar (Top Floating Overlay in Live Mode - Hidden in Fullscreen)
          if (!isHistoryMode && !isFullscreen)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: MapboxSearchBar(
                userPosition: myPos,
                onSearchingChanged: (isSearching) {
                  if (_isSearching != isSearching) {
                    setState(() => _isSearching = isSearching);
                  }
                },
                onPlaceSelected: (place) {
                  setState(() {
                    _searchedPlace = place;
                    _isSearching = false;
                  });
                  _mapController.move(place.coordinates, 16.5);
                },
                onClear: () {
                  setState(() => _isSearching = false);
                  _clearSearchedPlaceAndCenterMe(locationProvider, myPos);
                },
                onCancel: () {
                  setState(() => _isSearching = false);
                  _clearSearchedPlaceAndCenterMe(locationProvider, myPos);
                },
              ),
            ),

          // 2. Floating Action Controls (Satellite, Fullscreen, Fit Both, Center Partner, Center Me, Refresh)
          // Collapsible side controls: Anchored from top with responsive constraints so it NEVER gets cut off by the header!
          Positioned(
            top: isFullscreen
                ? (MediaQuery.of(context).padding.top + 14)
                : (isHistoryMode ? 14 : 70),
            right: 14,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topRight,
              child: isHistoryMode
                  ? // In Route History: Clean side button with Route History icon + Active Check Selected mark
                  _buildFloatingControlButton(
                      icon: Icons.route_rounded,
                      tooltip: 'Route History Active (Tap to Exit)',
                      color: isDark ? const Color(0xFF231A33) : Colors.white,
                      iconColor: AppColors.softRose,
                      isSelected: true,
                      selectedBorderColor: AppColors.softRose,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        locationProvider.toggleHistoryMode(false);
                      },
                    )
                  : (_isSideMenuCollapsed || _isSearching)
                      ? _buildFloatingControlButton(
                          icon: _isSearching
                              ? Icons.tune_rounded
                              : Icons.keyboard_arrow_left_rounded,
                          tooltip: 'Expand Map Controls',
                          color: isDark ? const Color(0xFF241A35) : Colors.white,
                          iconColor: AppColors.softRose,
                          isSelected: true,
                          selectedBorderColor: AppColors.softRose,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isSideMenuCollapsed = false;
                              if (_isSearching) {
                                _isSearching = false;
                              }
                            });
                          },
                        )
                      : Container(
                          constraints: BoxConstraints(
                            maxHeight: isFullscreen
                                ? (MediaQuery.of(context).size.height - 120)
                                : (MediaQuery.of(context).size.height - 180),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Collapse Button (Chevron) on top of the stack
                                _buildFloatingControlButton(
                                  icon: Icons.keyboard_arrow_right_rounded,
                                  tooltip: 'Collapse Controls',
                                  color: isDark ? const Color(0xFF2A1F3D) : const Color(0xFFF5EEF9),
                                  iconColor: isDark ? Colors.white70 : AppColors.deepCharcoal,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _isSideMenuCollapsed = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Satellite / Standard Map View Toggle Button
                                _buildFloatingControlButton(
                                  icon: isSatelliteView ? Icons.satellite_alt_rounded : Icons.map_rounded,
                                  tooltip: isSatelliteView ? 'Satellite Map (Tap for Standard)' : 'Standard Map (Tap for Satellite)',
                                  color: isSatelliteView ? AppColors.softRose : (isDark ? const Color(0xFF231A33) : Colors.white),
                                  iconColor: isSatelliteView ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E142B)),
                                  isSelected: true,
                                  selectedBorderColor: isSatelliteView ? AppColors.softRose : const Color(0xFF7C4DFF),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _isSatelliteView = !isSatelliteView;
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Fullscreen Map Toggle Button (Only in Live Mode or when not already fullscreen)
                                if (!isFullscreen) ...[
                                  _buildFloatingControlButton(
                                    icon: Icons.fullscreen_rounded,
                                    tooltip: 'Fullscreen Map',
                                    color: isDark ? const Color(0xFF231A33) : Colors.white,
                                    iconColor: isDark ? Colors.white : const Color(0xFF1E142B),
                                    isSelected: false,
                                    selectedBorderColor: AppColors.softRose,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _isFullscreen = true;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // Route History Playback Toggle Button
                                _buildFloatingControlButton(
                                  icon: Icons.route_rounded,
                                  tooltip: 'Route History Playback',
                                  color: isDark ? const Color(0xFF231A33) : Colors.white,
                                  iconColor: isDark ? Colors.white : const Color(0xFF1E142B),
                                  isSelected: false,
                                  selectedBorderColor: AppColors.softRose,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    locationProvider.toggleHistoryMode(true, ownerId: myId);
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Location History List Button
                                _buildFloatingControlButton(
                                  icon: Icons.history_rounded,
                                  tooltip: 'Trip History Log',
                                  color: isDark ? const Color(0xFF231A33) : Colors.white,
                                  iconColor: isDark ? Colors.white : const Color(0xFF1E142B),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    context.push(RouteNames.locationHistory);
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Fit Both Button (People Icon)
                                _buildFloatingControlButton(
                                  icon: Icons.people_alt_rounded,
                                  tooltip: 'Fit Both in View',
                                  color: _isBothSelected ? AppColors.softRose : (isDark ? const Color(0xFF231A33) : Colors.white),
                                  iconColor: _isBothSelected ? Colors.white : AppColors.softRose,
                                  isSelected: _isBothSelected,
                                  selectedBorderColor: AppColors.softRose,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _fitBoth(locationProvider);
                                  },
                                ),
                                const SizedBox(height: 8),

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
                                  const SizedBox(height: 8),
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
                                const SizedBox(height: 8),

                                // Refresh Button (Bottom White Button with Spin)
                                _buildFloatingControlButton(
                                  icon: Icons.refresh_rounded,
                                  isLoading: isRefreshing,
                                  tooltip: 'Refresh Location',
                                  color: isDark ? const Color(0xFF231A33) : Colors.white,
                                  iconColor: isDark ? Colors.white : const Color(0xFF1E142B),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _refreshLocations();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ),

          // 3. Bottom Panel: Location History Sheet (in History Mode) OR Live Info Card (in Live Mode)
          if (isHistoryMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LocationHistorySheet(
                isFullscreen: isFullscreen,
                onToggleFullscreen: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isFullscreen = !isFullscreen);
                },
                onFitRoute: () {
                  _fitRoute(historyPoints);
                },
                onClose: () {
                  locationProvider.toggleHistoryMode(false);
                },
              ),
            )
          else if (!isFullscreen)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: 14,
              right: 14,
              bottom: _isSearching
                  ? -220
                  : (MediaQuery.of(context).padding.bottom + 14),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isSearching ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isSearching,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchedPlace != null)
                        _buildSearchedPlaceBottomCard(context, locationProvider, myPos, partnerPos, partnerUser),
                      _buildRomanticLiveBottomCard(context, locationProvider, partnerLoc, partnerUser),
                    ],
                  ),
                ),
              ),
            )
          else if (isFullscreen && _searchedPlace != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: 14,
              right: 14,
              bottom: _isSearching
                  ? -220
                  : (MediaQuery.of(context).padding.bottom + 16),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isSearching ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isSearching,
                  child: _buildSearchedPlaceBottomCard(context, locationProvider, myPos, partnerPos, partnerUser),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _clearSearchedPlaceAndCenterMe(LocationProvider locationProvider, LatLng? myPos) {
    HapticFeedback.lightImpact();
    setState(() => _searchedPlace = null);
    if (myPos != null) {
      _centerMe(locationProvider);
    }
  }

  /// Floating Searched Place Info Card showing place name and distance in km from You and Partner
  Widget _buildSearchedPlaceBottomCard(
    BuildContext context,
    LocationProvider locationProvider,
    LatLng? myPos,
    LatLng? partnerPos,
    dynamic partnerUser,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partnerName = partnerUser?.displayName.isNotEmpty == true
        ? partnerUser!.displayName
        : 'Partner';

    final metersFromMe = myPos != null && _searchedPlace != null
        ? Geolocator.distanceBetween(
            myPos.latitude,
            myPos.longitude,
            _searchedPlace!.coordinates.latitude,
            _searchedPlace!.coordinates.longitude,
          )
        : null;

    final metersFromPartner = partnerPos != null && _searchedPlace != null
        ? Geolocator.distanceBetween(
            partnerPos.latitude,
            partnerPos.longitude,
            _searchedPlace!.coordinates.latitude,
            _searchedPlace!.coordinates.longitude,
          )
        : null;

    final myDistStr = metersFromMe != null
        ? (metersFromMe < 1000
            ? '${metersFromMe.toStringAsFixed(0)} m from you'
            : '${(metersFromMe / 1000.0).toStringAsFixed(1)} km from you')
        : null;

    final partnerDistStr = metersFromPartner != null
        ? (metersFromPartner < 1000
            ? '${metersFromPartner.toStringAsFixed(0)} m from $partnerName'
            : '${(metersFromPartner / 1000.0).toStringAsFixed(1)} km from $partnerName')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231A33) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1.0,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.softRose.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.place_rounded,
              color: AppColors.softRose,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _searchedPlace!.text,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (myDistStr != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.softRose.withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          myDistStr,
                          style: TextStyle(
                            color: isDark ? AppColors.softRose : const Color(0xFFD81B60),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (partnerDistStr != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.lavender.withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          partnerDistStr,
                          style: TextStyle(
                            color: isDark ? AppColors.lavender : const Color(0xFF6B63B5),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _clearSearchedPlaceAndCenterMe(locationProvider, myPos),
          ),
        ],
      ),
    );
  }

  Widget _buildRomanticLiveBottomCard(
    BuildContext context,
    LocationProvider locationProvider,
    LocationModel? partnerLoc,
    dynamic partnerUser,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = locationProvider.isPartnerOnline();
    final partnerName = partnerUser?.displayName.isNotEmpty == true
        ? partnerUser!.displayName
        : 'Partner';
    final partnerBattery = isOnline ? (locationProvider.partnerBatteryLevel ?? partnerLoc?.batteryLevel) : null;
    final isPartnerCharging = locationProvider.isPartnerCharging;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _centerPartner(locationProvider);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xF21F172E),
                    const Color(0xF7281B3D),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.96),
                    const Color(0xFFFBF7FD),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.softRose.withValues(alpha: 0.28)
                : AppColors.softRose.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.softRose.withValues(alpha: isDark ? 0.16 : 0.12),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Compact Glowing Heart Pin Icon
            Container(
              padding: const EdgeInsets.all(7.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.softRose, Color(0xFFE57388)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.softRose.withValues(alpha: 0.40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 10),

            // Distance & Status Content (Compressed)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        locationProvider.formattedDistance,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      // Fresh Live Battery Badge (Only rendered when strictly ONLINE)
                      if (isOnline && partnerBattery != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.2),
                          decoration: BoxDecoration(
                            color: isPartnerCharging
                                ? const Color(0xFF00E676).withValues(alpha: isDark ? 0.18 : 0.14)
                                : Colors.amberAccent.withValues(alpha: isDark ? 0.18 : 0.14),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: isPartnerCharging
                                  ? const Color(0xFF00E676).withValues(alpha: 0.5)
                                  : Colors.amberAccent.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPartnerCharging
                                    ? Icons.battery_charging_full_rounded
                                    : (partnerBattery <= 20
                                        ? Icons.battery_alert_rounded
                                        : (partnerBattery <= 60
                                            ? Icons.battery_4_bar_rounded
                                            : Icons.battery_full_rounded)),
                                color: isPartnerCharging
                                    ? (isDark ? const Color(0xFF00E676) : const Color(0xFF2E7D32))
                                    : (isDark ? Colors.amberAccent : Colors.orange.shade800),
                                size: 10.5,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$partnerBattery%${isPartnerCharging ? " ⚡" : ""}',
                                style: TextStyle(
                                  color: isPartnerCharging
                                      ? (isDark ? const Color(0xFF00E676) : const Color(0xFF2E7D32))
                                      : (isDark ? Colors.amberAccent : Colors.orange.shade800),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1.5),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? const Color(0xFF00E676) : Colors.grey.shade400,
                          boxShadow: [
                            if (isOnline)
                              BoxShadow(
                                color: const Color(0xFF00E676).withValues(alpha: 0.6),
                                blurRadius: 3,
                                spreadRadius: 0.5,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (partnerLoc != null)
                        LiveTimeText(
                          textBuilder: () {
                            if (isOnline) {
                              return '$partnerName • Live (${partnerLoc.timeAgo})';
                            }
                            return '$partnerName • Offline';
                          },
                          style: TextStyle(
                            color: isOnline
                                ? (isDark ? const Color(0xFF00E676) : const Color(0xFF2E7D32))
                                : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey.shade600),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        )
                      else
                        Text(
                          isOnline ? '$partnerName • Live' : '$partnerName • Offline',
                          style: TextStyle(
                            color: isOnline
                                ? (isDark ? const Color(0xFF00E676) : const Color(0xFF2E7D32))
                                : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey.shade600),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick Center Partner Button
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.softRose.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.my_location_rounded,
                size: 15,
                color: isDark ? AppColors.softRose : AppColors.deepCharcoal,
              ),
            ),
          ],
        ),
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
          // Selected Active Status Check Badge
          if (isSelected)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 16,
                height: 16,
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
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrivingCarMarker({
    required String? photoUrl,
    required String name,
    required Color accentColor,
    required double heading,
    required bool isPlaying,
    required bool isDark,
  }) {
    final headingRad = heading * (math.pi / 180.0);

    return Center(
      child: Transform.rotate(
        angle: headingRad,
        child: SizedBox(
          width: 44,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Glowing animated aura ring behind the vehicle puck (when driving)
              if (isPlaying)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.65),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                ),

              // 2. Sleek Directional Pointer Nose / Car Arrow (pointing forward)
              Positioned(
                top: 0,
                child: CustomPaint(
                  size: const Size(12, 9),
                  painter: _VehicleNosePainter(color: accentColor),
                ),
              ),

              // 3. Compact Profile Disc (fits road line directly, 30px)
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1B1426) : Colors.white,
                  border: Border.all(
                    color: accentColor,
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildFallbackPuckAvatar(name, accentColor),
                          errorWidget: (_, __, ___) => _buildFallbackPuckAvatar(name, accentColor),
                        )
                      : _buildFallbackPuckAvatar(name, accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPuckAvatar(String name, Color accentColor) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '♥';
    return Container(
      color: accentColor.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: accentColor,
        ),
      ),
    );
  }
}

class _VehicleNosePainter extends CustomPainter {
  final Color color;
  const _VehicleNosePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width / 2, 0) // Peak tip
      ..lineTo(size.width, size.height) // Bottom right
      ..lineTo(size.width / 2, size.height * 0.65) // Inner notch
      ..lineTo(0, size.height) // Bottom left
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _VehicleNosePainter oldDelegate) =>
      oldDelegate.color != color;
}
