import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/location_model.dart';
import 'offline_storage_service.dart';

/// Background task names
const String backgroundLocationTask = 'bgLocationTask';
const String periodicLocationTask = 'periodicLocationTask';

/// Service for capturing GPS location in background even when app is closed.
/// Uses Workmanager for periodic background execution and
/// GPS-only location (no cellular data required for positioning).
class BackgroundLocationService {
  static BackgroundLocationService? _instance;
  static const String _userIdKey = 'bg_location_user_id';
  static const String _coupleIdKey = 'bg_location_couple_id';
  static const String _enabledKey = 'bg_location_enabled';
  static const String _intervalKey = 'bg_location_interval';

  BackgroundLocationService._();

  static BackgroundLocationService get instance {
    _instance ??= BackgroundLocationService._();
    return _instance!;
  }

  /// Initialize Workmanager for background tasks
  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    debugPrint('BackgroundLocationService initialized');
  }

  /// Start periodic background location capture
  /// [intervalMinutes] - How often to capture location (default: 15 minutes)
  Future<void> startPeriodicTracking({
    required String userId,
    required String coupleId,
    int intervalMinutes = 15,
  }) async {
    // Save user info for background task access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_coupleIdKey, coupleId);
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_intervalKey, intervalMinutes);

    // Cancel any existing task first
    await Workmanager().cancelByUniqueName(periodicLocationTask);

    // Register periodic task
    await Workmanager().registerPeriodicTask(
      periodicLocationTask,
      backgroundLocationTask,
      frequency: Duration(minutes: intervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.not_required, // Works offline - GPS only
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );

    debugPrint(
        'Started periodic location tracking every $intervalMinutes minutes');
  }

  /// Stop periodic background tracking
  Future<void> stopPeriodicTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await Workmanager().cancelByUniqueName(periodicLocationTask);
    debugPrint('Stopped periodic location tracking');
  }

  /// Check if periodic tracking is enabled
  Future<bool> isTrackingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Capture location immediately (one-time background task)
  Future<void> captureLocationNow({
    required String userId,
    required String coupleId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_coupleIdKey, coupleId);

    await Workmanager().registerOneOffTask(
      'oneTimeLocation_${DateTime.now().millisecondsSinceEpoch}',
      backgroundLocationTask,
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }

  /// Get stored user ID for background tasks
  static Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Get stored couple ID for background tasks
  static Future<String?> getStoredCoupleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_coupleIdKey);
  }
}

/// Callback dispatcher for Workmanager - must be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('Background task executing: $taskName');

    try {
      if (taskName == backgroundLocationTask) {
        await _captureBackgroundLocation();
      }
      return true;
    } catch (e) {
      debugPrint('Background task error: $e');
      return false;
    }
  });
}

/// Capture GPS location in background and save to SQLite
/// This runs in an isolate - no UI access, limited services
Future<void> _captureBackgroundLocation() async {
  try {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Background: Location services disabled');
      return;
    }

    // Check permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Background: Location permission denied');
      return;
    }

    // Get user ID from shared preferences
    final userId = await BackgroundLocationService.getStoredUserId();
    if (userId == null) {
      debugPrint('Background: No user ID stored');
      return;
    }

    // Get GPS position (works offline - no cellular data needed)
    // Forces high accuracy GPS-only location
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 30),
      forceAndroidLocationManager:
          false, // Use Google Play Services for better GPS
    );

    debugPrint('Background GPS: ${position.latitude}, ${position.longitude}');

    // Initialize storage and save location
    final storage = OfflineStorageService.instance;
    await storage.ensureInitialized();

    final location = LocationModel(
      coupleId: '',
      ownerId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
      source: LocationSource.background,
    );

    await storage.insertLocation(location);
    debugPrint('Background: Location saved to SQLite');

    // Try to sync if online
    await _trySyncInBackground();
  } catch (e) {
    debugPrint('Background location capture failed: $e');
  }
}

/// Try to sync locations to Firebase if online
Future<void> _trySyncInBackground() async {
  try {
    final connectivity = await Connectivity().checkConnectivity();
    // Any connection type except 'none' means we have network access
    final isOnline = connectivity != ConnectivityResult.none;
    debugPrint('Background connectivity: $connectivity, isOnline: $isOnline');

    if (!isOnline) {
      debugPrint('Background: Offline, skipping sync');
      return;
    }

    final userId = await BackgroundLocationService.getStoredUserId();
    final coupleId = await BackgroundLocationService.getStoredCoupleId();

    if (userId == null || coupleId == null) {
      debugPrint('Background: Missing user/couple ID for sync');
      return;
    }

    // Import and use sync service
    // Note: Full sync is done when app opens - this is a lightweight check
    final storage = OfflineStorageService.instance;
    final unsyncedCount = await storage.getUnsyncedCount(userId);

    if (unsyncedCount > 0) {
      debugPrint('Background: $unsyncedCount locations pending sync');
      // Full sync will happen when app opens or via LocationSyncService
    }
  } catch (e) {
    debugPrint('Background sync check failed: $e');
  }
}
