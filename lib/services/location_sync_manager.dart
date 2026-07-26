import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'location_database.dart';

/// Result object for location batch sync operations.
class LocationSyncResult {
  final bool success;
  final int syncedCount;
  final int failedCount;
  final String? errorMessage;

  LocationSyncResult({
    required this.success,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
  });

  factory LocationSyncResult.empty() => LocationSyncResult(success: true, syncedCount: 0);
  factory LocationSyncResult.offline() => LocationSyncResult(success: false, errorMessage: 'No network connection available.');
}

/// Thread-safe, Mutex-locked Location Sync Manager for Flutter & Supabase.
/// Prevents concurrent sync execution across Background Service, Foreground Listeners, and UI triggers.
class LocationSyncManager {
  static LocationSyncManager? _instance;

  final LocationDatabase _db = LocationDatabase.instance;
  final Connectivity _connectivity = Connectivity();
  
  /// Mutex lock to enforce strict single-execution pipeline
  final Lock _syncLock = Lock();

  /// Connectivity subscription for foreground auto-sync
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isInitialized = false;

  LocationSyncManager._internal();

  /// Singleton Instance Accessor
  static LocationSyncManager get instance {
    _instance ??= LocationSyncManager._internal();
    return _instance!;
  }

  /// Initialize foreground connectivity listener to auto-sync when network returns
  void initializeForegroundListener() {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('[LocationSyncManager] Initializing connectivity auto-sync listener...');
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) async {
      final hasConnection = _checkConnectivityResult(result);
      if (hasConnection) {
        debugPrint('[LocationSyncManager] Internet restored - triggering background queue sync...');
        await syncPendingLocations();
      }
    });
  }

  /// Helper to check if internet connectivity is available
  bool _checkConnectivityResult(ConnectivityResult result) {
    return result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet;
  }

  /// Direct method to check if currently online
  Future<bool> isNetworkAvailable() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _checkConnectivityResult(result);
    } catch (e) {
      debugPrint('[LocationSyncManager] Connectivity check failed: $e');
      return false;
    }
  }

  /// Core Sync Method: Processes pending SQLite locations in batches and uploads to Supabase.
  /// Wrapped in Mutex `_syncLock.synchronized()` to block parallel race conditions.
  Future<LocationSyncResult> syncPendingLocations({
    int batchSize = 50,
    int maxRetries = 5,
    SupabaseClient? customClient,
  }) async {
    // Acquire Mutex Lock around sync execution
    return await _syncLock.synchronized(() async {
      debugPrint('[LocationSyncManager] Entered Mutex sync execution pipeline.');

      // 1. Verify Connectivity
      final online = await isNetworkAvailable();
      if (!online) {
        debugPrint('[LocationSyncManager] Aborting sync: Device is offline.');
        return LocationSyncResult.offline();
      }

      // 2. Resolve Supabase Client
      final client = customClient ?? (Supabase.instance.client);
      
      int totalSynced = 0;
      int totalFailed = 0;
      bool hasMoreBatches = true;

      try {
        while (hasMoreBatches) {
          // 3. Read pending batch from SQLite
          final pendingBatch = await _db.fetchPendingBatch(
            limit: batchSize,
            maxRetries: maxRetries,
          );

          if (pendingBatch.isEmpty) {
            debugPrint('[LocationSyncManager] Sync completed: No pending items in queue.');
            hasMoreBatches = false;
            break;
          }

          final batchIds = pendingBatch.map((e) => e.id!).toList();
          final payloads = pendingBatch.map((e) => e.toSupabasePayload()).toList();

          debugPrint('[LocationSyncManager] Syncing batch of ${pendingBatch.length} locations to Supabase...');

          try {
            // 4. Upsert batch into Supabase locations table
            await client.from('locations').upsert(
                  payloads,
                  onConflict: 'owner_id,created_at',
                );

            // 5. Atomic Clean-up: Delete successfully acknowledged batch items from SQLite
            await _db.deleteBatch(batchIds);
            totalSynced += pendingBatch.length;
            debugPrint('[LocationSyncManager] Batch of ${pendingBatch.length} locations uploaded & purged locally.');

            if (pendingBatch.length < batchSize) {
              hasMoreBatches = false;
            }
          } catch (batchError) {
            debugPrint('[LocationSyncManager] Batch upload error: $batchError');
            
            // 6. Poison Pill Protection: Increment retry count on failure
            await _db.incrementRetryCount(batchIds);
            totalFailed += batchIds.length;

            hasMoreBatches = false;
            return LocationSyncResult(
              success: false,
              syncedCount: totalSynced,
              failedCount: totalFailed,
              errorMessage: batchError.toString(),
            );
          }
        }

        return LocationSyncResult(
          success: true,
          syncedCount: totalSynced,
          failedCount: totalFailed,
        );
      } catch (e) {
        debugPrint('[LocationSyncManager] Fatal error during location sync: $e');
        return LocationSyncResult(
          success: false,
          syncedCount: totalSynced,
          failedCount: totalFailed,
          errorMessage: e.toString(),
        );
      }
    });
  }

  /// Record a location update to SQLite (handling null speed/battery_level) and attempt sync.
  Future<void> recordAndSync({
    required String userId,
    required String coupleId,
    required double latitude,
    required double longitude,
    double? speed,
    double accuracy = 0.0,
    double? batteryLevel,
    DateTime? timestamp,
  }) async {
    final record = PendingLocation(
      userId: userId,
      coupleId: coupleId,
      latitude: latitude,
      longitude: longitude,
      speed: speed, // Safely handles null
      accuracy: accuracy,
      batteryLevel: batteryLevel, // Safely handles null
      createdAt: (timestamp ?? DateTime.now()).toIso8601String(),
    );

    // 1. Enqueue locally in SQLite first (Offline-First)
    await _db.enqueueLocation(record);

    // 2. Trigger sync asynchronously (Mutex handles concurrency)
    unawaited(syncPendingLocations());
  }

  /// Alias for recordAndSync to maintain API backwards compatibility
  Future<void> captureAndEnqueueLocation({
    required String userId,
    required String coupleId,
    required double latitude,
    required double longitude,
    double? speed,
    double accuracy = 0.0,
    double? batteryLevel,
    DateTime? timestamp,
  }) async {
    await recordAndSync(
      userId: userId,
      coupleId: coupleId,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      accuracy: accuracy,
      batteryLevel: batteryLevel,
      timestamp: timestamp,
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _isInitialized = false;
  }
}
