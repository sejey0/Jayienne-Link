import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import '../models/location_model.dart';
import 'offline_storage_service.dart';

/// Service for capturing GPS locations offline-first.
/// Works completely without internet - saves to SQLite immediately.
class OfflineLocationService {
  static OfflineLocationService? _instance;
  final OfflineStorageService _storage = OfflineStorageService.instance;

  // Location stream subscription
  StreamSubscription<Position>? _positionSubscription;

  // Stream controller for broadcasting locations
  final _locationController = StreamController<LocationModel>.broadcast();

  // Last known position for quick access
  Position? _lastPosition;

  // Throttling to prevent excessive updates
  DateTime? _lastCaptureTime;
  static const Duration _minCaptureInterval = Duration(seconds: 30);

  // Movement detection threshold (meters)
  static const double _movementThreshold = 10.0;

  OfflineLocationService._();

  static OfflineLocationService get instance {
    _instance ??= OfflineLocationService._();
    return _instance!;
  }

  /// Stream of location updates
  Stream<LocationModel> get locationStream => _locationController.stream;

  /// Last captured position
  Position? get lastPosition => _lastPosition;

  // =====================
  // PERMISSION HANDLING
  // =====================

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Request background location permission (for background tracking)
  Future<bool> requestBackgroundPermission() async {
    // First ensure we have foreground permission
    final foreground = await requestPermission();
    if (foreground == LocationPermission.denied ||
        foreground == LocationPermission.deniedForever) {
      return false;
    }

    // Request background permission using permission_handler
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Check if we have all required permissions
  Future<LocationPermissionStatus> getPermissionStatus() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    final permission = await checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.always:
        return LocationPermissionStatus.always;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission denied forever)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  // =====================
  // LOCATION CAPTURE
  // =====================

  /// Web-safe position fetch with timeout and fallback
  Future<Position?> _fetchPositionWithFallback({
    LocationAccuracy? accuracy,
    Duration timeLimit = const Duration(seconds: 15),
  }) async {
    final effectiveAccuracy =
        accuracy ?? (kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high);
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: effectiveAccuracy,
        timeLimit: timeLimit,
      );
    } catch (e) {
      debugPrint('getCurrentPosition failed/timed out: $e');

      // Only attempt getLastKnownPosition on non-Web platforms
      if (!kIsWeb) {
        try {
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) return lastPos;
        } catch (lastPosErr) {
          debugPrint('getLastKnownPosition error: $lastPosErr');
        }
      }

      return null;
    }
  }

  /// Safely get current battery level percentage
  Future<int?> getBatteryLevel() async {
    if (kIsWeb) return null;
    try {
      final battery = Battery();
      return await battery.batteryLevel;
    } catch (e) {
      debugPrint('Error getting battery level: $e');
      return null;
    }
  }

  /// Get current location once (works offline - uses GPS directly)
  Future<LocationModel?> getCurrentLocation(String ownerId) async {
    try {
      // Check permissions first
      final status = await getPermissionStatus();
      if (status == LocationPermissionStatus.denied ||
          status == LocationPermissionStatus.deniedForever ||
          status == LocationPermissionStatus.serviceDisabled) {
        debugPrint('Location permission not granted: $status');
        return await _storage.getLastKnownLocation(ownerId);
      }

      // Get position from GPS (works offline) with fallback to last known position
      final position = await _fetchPositionWithFallback(
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (position == null) {
        debugPrint('Unable to get live position. Returning cached/last known location...');
        return await _storage.getLastKnownLocation(ownerId);
      }

      _lastPosition = position;

      final batteryLevel = await getBatteryLevel();

      // Create location model
      final location = LocationModel(
        coupleId: '',
        ownerId: ownerId,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
        batteryLevel: batteryLevel,
        timestamp: DateTime.now(),
        source: LocationSource.local,
      );

      // Always save to SQLite first (offline-first, no-op on Web)
      final id = await _storage.insertLocation(location);
      final savedLocation = location.copyWith(localId: id);

      // Broadcast to listeners
      _locationController.add(savedLocation);

      return savedLocation;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return await _storage.getLastKnownLocation(ownerId);
    }
  }

  /// Capture location with smart throttling (avoids duplicates when stationary)
  Future<LocationModel?> captureLocationSmart(String ownerId) async {
    // Check if we should skip this capture (throttling)
    if (_lastCaptureTime != null) {
      final elapsed = DateTime.now().difference(_lastCaptureTime!);
      if (elapsed < _minCaptureInterval) {
        debugPrint('Skipping capture - too soon (${elapsed.inSeconds}s)');
        return null;
      }
    }

    // Check if we've moved enough since last capture
    if (_lastPosition != null) {
      try {
        final currentPos = await _fetchPositionWithFallback(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );

        if (currentPos != null) {
          final distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            currentPos.latitude,
            currentPos.longitude,
          );

          if (distance < _movementThreshold) {
            debugPrint(
                'Skipping capture - no significant movement (${distance.toStringAsFixed(1)}m)');
            return null;
          }
        }
      } catch (e) {
        // Continue with capture if movement check fails
        debugPrint('Movement check failed, continuing with capture: $e');
      }
    }

    _lastCaptureTime = DateTime.now();
    return getCurrentLocation(ownerId);
  }

  // =====================
  // CONTINUOUS TRACKING
  // =====================

  /// Start continuous location tracking
  Future<bool> startTracking(
    String ownerId, {
    int distanceFilter = 50, // meters
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    // Check permissions
    final status = await getPermissionStatus();
    if (status == LocationPermissionStatus.denied ||
        status == LocationPermissionStatus.deniedForever ||
        status == LocationPermissionStatus.serviceDisabled) {
      return false;
    }

    // Stop any existing tracking
    await stopTracking();

    // Start position stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 10),
      ),
    ).listen(
      (position) async {
        _lastPosition = position;

        final batteryLevel = await getBatteryLevel();

        // Create and save location
        final location = LocationModel(
          coupleId: '',
          ownerId: ownerId,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          heading: position.heading,
          accuracy: position.accuracy,
          batteryLevel: batteryLevel,
          timestamp: DateTime.now(),
          source: LocationSource.local,
        );

        final id = await _storage.insertLocation(location);
        final savedLocation = location.copyWith(localId: id);

        // Broadcast to listeners
        _locationController.add(savedLocation);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );

    return true;
  }

  /// Stop continuous tracking
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Check if currently tracking
  bool get isTracking => _positionSubscription != null;

  // =====================
  // BACKGROUND LOCATION
  // =====================

  /// Capture location for background task
  /// This is called by the background service
  Future<LocationModel?> captureBackgroundLocation(String ownerId) async {
    try {
      final position = await _fetchPositionWithFallback(
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (position == null) {
        debugPrint('Background capture: No position available');
        return await _storage.getLastKnownLocation(ownerId);
      }

      final batteryLevel = await getBatteryLevel();

      final location = LocationModel(
        coupleId: '',
        ownerId: ownerId,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
        batteryLevel: batteryLevel,
        timestamp: DateTime.now(),
        source: LocationSource.background,
      );

      // Save to SQLite
      final id = await _storage.insertLocation(location);
      return location.copyWith(localId: id);
    } catch (e) {
      debugPrint('Background location capture failed: $e');
      return null;
    }
  }

  // =====================
  // UTILITY METHODS
  // =====================

  /// Calculate distance between two locations
  double calculateDistance(LocationModel from, LocationModel to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Get last stored location from database
  Future<LocationModel?> getLastStoredLocation(String ownerId) async {
    return await _storage.getLastKnownLocation(ownerId);
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}

/// Location permission status
enum LocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
  serviceDisabled,
}

/// Extension for permission status helpers
extension LocationPermissionStatusExtension on LocationPermissionStatus {
  bool get canTrack =>
      this == LocationPermissionStatus.whileInUse ||
      this == LocationPermissionStatus.always;

  bool get canTrackInBackground => this == LocationPermissionStatus.always;

  String get message {
    switch (this) {
      case LocationPermissionStatus.denied:
        return 'Location permission is required to share your location with your person.';
      case LocationPermissionStatus.deniedForever:
        return 'Location permission was denied permanently. Please enable it in Settings.';
      case LocationPermissionStatus.whileInUse:
        return 'Location sharing is enabled while using the app.';
      case LocationPermissionStatus.always:
        return 'Location sharing is enabled, including in the background.';
      case LocationPermissionStatus.serviceDisabled:
        return 'Please enable Location Services on your device.';
    }
  }
}
