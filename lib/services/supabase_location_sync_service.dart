import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location_model.dart';
import 'offline_storage_service.dart';

/// Supabase-based location sync service for syncing locations between local SQLite and PostgreSQL
/// Monitors connectivity and auto-syncs when internet is available
class SupabaseLocationSyncService {
  static SupabaseLocationSyncService? _instance;
  final OfflineStorageService _storage = OfflineStorageService.instance;
  final Connectivity _connectivity = Connectivity();
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _locationsTable = 'locations';

  // Connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;

  // Sync state streams
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _connectivityController = StreamController<bool>.broadcast();

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const int _batchSize = 50; // Max locations per batch upload

  // Partner location realtime subscription
  RealtimeChannel? _partnerLocationChannel;
  StreamController<LocationModel>? _partnerLocationController;

  // Stored credentials for auto-sync
  String? _userId;
  String? _coupleId;

  // Data saver mode for slow connections
  bool _dataSaverEnabled = false;

  SupabaseLocationSyncService._();

  static SupabaseLocationSyncService get instance {
    _instance ??= SupabaseLocationSyncService._();
    return _instance!;
  }

  /// Stream of sync status changes
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Current syncing status
  bool get isSyncing => _isSyncing;

  /// Data saver mode status
  bool get dataSaverEnabled => _dataSaverEnabled;

  /// Enable/disable data saver mode
  void setDataSaverEnabled(bool enabled) {
    _dataSaverEnabled = enabled;
    debugPrint('Data saver mode: $enabled');
  }

  // =====================
  // INITIALIZATION
  // =====================

  /// Initialize the sync service and start monitoring connectivity
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    debugPrint('=== SUPABASE LOCATION SYNC DEBUG ===');
    debugPrint('Initial connectivity result: $result');
    _isOnline = _hasInternetConnection(result);
    debugPrint('Initial isOnline: $_isOnline');
    _connectivityController.add(_isOnline);

    // Start monitoring connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        debugPrint('Connectivity changed event: $result');
        final wasOnline = _isOnline;
        _isOnline = _hasInternetConnection(result);
        _connectivityController.add(_isOnline);

        debugPrint('Connectivity changed: $_isOnline (was: $wasOnline)');

        // Auto-sync when coming online
        if (_isOnline && !wasOnline) {
          debugPrint('Coming online - triggering auto-sync');
          _triggerAutoSync();
        }
      },
    );

    debugPrint('SupabaseLocationSyncService initialized. Online: $_isOnline');
  }

  /// Trigger auto-sync when coming online
  Future<void> _triggerAutoSync() async {
    if (_userId == null || _coupleId == null) {
      debugPrint('Auto-sync skipped: No user credentials stored');
      return;
    }

    final unsyncedCount = await _storage.getUnsyncedCount(_userId!);
    if (unsyncedCount > 0) {
      debugPrint('Auto-syncing $unsyncedCount pending locations...');
      await syncLocations(_userId!, _coupleId!);
    }
  }

  /// Store credentials for auto-sync
  void setCredentials(String userId, String coupleId) {
    _userId = userId;
    _coupleId = coupleId;
  }

  /// Check if connectivity result indicates internet access
  bool _hasInternetConnection(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }

  // =====================
  // SYNC OPERATIONS
  // =====================

  /// Sync all unsynced locations to Supabase
  Future<SyncResult> syncLocations(String userId, String coupleId) async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncedCount: 0,
      );
    }

    if (!_isOnline) {
      _syncStatusController.add(SyncStatus.offline);
      return SyncResult(
        success: false,
        message: 'No internet connection',
        syncedCount: 0,
      );
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      // Get unsynced locations
      final unsynced = await _storage.getUnsyncedLocations(userId);
      if (unsynced.isEmpty) {
        _syncStatusController.add(SyncStatus.synced);
        return SyncResult(
          success: true,
          message: 'Already synced',
          syncedCount: 0,
        );
      }

      debugPrint('Syncing ${unsynced.length} locations to Supabase...');

      int totalSynced = 0;
      final localToSupabaseIds = <int, String>{};

      // Process in batches for efficiency
      for (var i = 0; i < unsynced.length; i += _batchSize) {
        final batch = unsynced.skip(i).take(_batchSize).toList();
        final result = await _uploadBatchWithRetry(batch, coupleId);

        if (result != null) {
          localToSupabaseIds.addAll(result);
          totalSynced += result.length;
        }
      }

      // Mark all synced locations in local storage
      if (localToSupabaseIds.isNotEmpty) {
        await _storage.markBatchAsSynced(localToSupabaseIds);
      }

      _syncStatusController.add(SyncStatus.synced);
      debugPrint('✅ Synced $totalSynced locations successfully');
      return SyncResult(
        success: true,
        message: 'Synced $totalSynced locations',
        syncedCount: totalSynced,
      );
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      _syncStatusController.add(SyncStatus.error);
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload a batch of locations with retry logic
  Future<Map<int, String>?> _uploadBatchWithRetry(
    List<LocationModel> batch,
    String coupleId,
  ) async {
    int retries = 0;

    while (retries < _maxRetries) {
      try {
        return await _uploadBatch(batch, coupleId);
      } catch (e) {
        retries++;
        debugPrint('Upload batch failed (attempt $retries): $e');

        if (retries < _maxRetries) {
          // Exponential backoff
          final delay = _retryDelay * (1 << (retries - 1));
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('❌ All retry attempts failed for batch');
    return null; // All retries failed
  }

  /// Upload a batch of locations to Supabase
  Future<Map<int, String>> _uploadBatch(
    List<LocationModel> batch,
    String coupleId,
  ) async {
    final result = <int, String>{};

    // Prepare batch data for insertion
    final batchData = batch.map((location) {
      final data = location.toInsertJson(dataSaver: _dataSaverEnabled);
      data['couple_id'] = coupleId;
      return data;
    }).toList();

    // Insert batch using Supabase
    final response =
        await _supabase.from(_locationsTable).insert(batchData).select('id');

    // Map local IDs to Supabase IDs
    for (int i = 0; i < batch.length && i < response.length; i++) {
      if (batch[i].localId != null) {
        result[batch[i].localId!] = response[i]['id'] as String;
      }
    }

    return result;
  }

  // =====================
  // PARTNER LOCATIONS
  // =====================

  /// Start listening for partner's location updates using Supabase Realtime
  Stream<LocationModel> startListeningToPartner(
    String coupleId,
    String partnerId,
  ) {
    // Cancel existing subscription
    stopListeningToPartner();

    // Create new stream controller
    _partnerLocationController = StreamController<LocationModel>.broadcast();

    // Subscribe to Realtime updates
    _partnerLocationChannel = _supabase
        .channel('partner-locations-$partnerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _locationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'owner_id',
            value: partnerId,
          ),
          callback: (payload) {
            try {
              final locationData = payload.newRecord;
              if (locationData['couple_id'] == coupleId) {
                final location = LocationModel.fromJson(locationData);
                _partnerLocationController?.add(location);

                // Cache locally for offline access
                _storage.storePartnerLocations([location]);
              }
            } catch (e) {
              debugPrint('Error processing partner location update: $e');
            }
          },
        )
        .subscribe();

    debugPrint('✅ Started listening to partner locations via Realtime');
    return _partnerLocationController!.stream;
  }

  /// Stop listening for partner's locations
  void stopListeningToPartner() {
    _partnerLocationChannel?.unsubscribe();
    _partnerLocationController?.close();
    _partnerLocationChannel = null;
    _partnerLocationController = null;
    debugPrint('Stopped listening to partner locations');
  }

  /// Fetch partner's recent locations from Supabase
  Future<List<LocationModel>> fetchPartnerLocations(
    String coupleId,
    String partnerId, {
    int limit = 100,
    DateTime? since,
  }) async {
    if (!_isOnline) {
      // Return cached locations if offline
      return await _storage.getLocationHistory(partnerId, limit: limit);
    }

    try {
      final dynamic query = _supabase
          .from(_locationsTable)
          .select()
          .eq('couple_id', coupleId)
          .eq('owner_id', partnerId)
          .order('timestamp', ascending: false);

      if (since != null) {
        query.gte('timestamp', since.toIso8601String());
      }

      final response = await query.limit(limit);
      final locations = (response as List)
          .map((data) => LocationModel.fromJson(data as Map<String, dynamic>))
          .toList();

      // Cache locally for offline access
      await _storage.storePartnerLocations(locations);

      debugPrint(
          '✅ Fetched ${locations.length} partner locations from Supabase');
      return locations;
    } catch (e) {
      debugPrint('❌ Error fetching partner locations: $e');
      // Fall back to cached locations
      return await _storage.getLocationHistory(partnerId, limit: limit);
    }
  }

  /// Get partner's last known location (from cache or Supabase)
  Future<LocationModel?> getPartnerLastLocation(
    String coupleId,
    String partnerId,
  ) async {
    // Try local cache first
    final cached = await _storage.getPartnerLastLocation(partnerId);

    if (!_isOnline) {
      return cached;
    }

    // Fetch latest from Supabase
    try {
      final response = await _supabase
          .from(_locationsTable)
          .select()
          .eq('couple_id', coupleId)
          .eq('owner_id', partnerId)
          .order('timestamp', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return cached;
      }

      final latest =
          LocationModel.fromJson(response.first);

      // Update cache
      await _storage.storePartnerLocations([latest]);

      // Return the more recent one
      if (cached != null && cached.timestamp.isAfter(latest.timestamp)) {
        return cached;
      }
      return latest;
    } catch (e) {
      debugPrint('❌ Error fetching partner last location: $e');
      return cached;
    }
  }

  // =====================
  // SYNC STATUS
  // =====================

  /// Get current sync status
  Future<SyncStatus> getSyncStatus(String userId) async {
    if (!_isOnline) return SyncStatus.offline;
    if (_isSyncing) return SyncStatus.syncing;

    final unsyncedCount = await _storage.getUnsyncedCount(userId);
    return unsyncedCount > 0 ? SyncStatus.pending : SyncStatus.synced;
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount(String userId) async {
    return await _storage.getUnsyncedCount(userId);
  }

  // =====================
  // CLEANUP
  // =====================

  /// Clean up old synced locations (retention policy)
  Future<void> cleanupOldLocations({int retentionDays = 7}) async {
    final deleted = await _storage.cleanupOldLocations(
      retentionDays: retentionDays,
    );
    debugPrint('Cleaned up $deleted old locations from local storage');

    // Also cleanup in Supabase if online
    if (_isOnline && _userId != null) {
      try {
        final cutoffDate =
            DateTime.now().subtract(Duration(days: retentionDays));
        await _supabase
            .from(_locationsTable)
            .delete()
            .eq('owner_id', _userId!)
            .lt('timestamp', cutoffDate.toIso8601String());

        debugPrint('✅ Cleaned up old locations from Supabase');
      } catch (e) {
        debugPrint('❌ Error cleaning up Supabase locations: $e');
      }
    }
  }

  /// Delete all user location data (privacy feature)
  Future<void> deleteAllUserData(String userId, String coupleId) async {
    // Delete from local storage
    await _storage.deleteAllUserLocations(userId);
    debugPrint('Deleted user locations from local storage');

    // Delete from Supabase if online
    if (_isOnline) {
      try {
        await _supabase
            .from(_locationsTable)
            .delete()
            .eq('couple_id', coupleId)
            .eq('owner_id', userId);

        debugPrint('✅ Deleted all user locations from Supabase');
      } catch (e) {
        debugPrint('❌ Error deleting Supabase locations: $e');
      }
    }
  }

  /// Get location statistics
  Future<Map<String, dynamic>> getLocationStats(
      String userId, String coupleId) async {
    try {
      final stats = <String, dynamic>{};

      // Local stats
      final localCount = await _storage.getLocationCount(userId);
      final unsyncedCount = await _storage.getUnsyncedCount(userId);
      stats['local_count'] = localCount;
      stats['unsynced_count'] = unsyncedCount;

      // Supabase stats (if online)
      if (_isOnline) {
        final response = await _supabase
            .from(_locationsTable)
            .select('*')
            .eq('couple_id', coupleId)
            .eq('owner_id', userId)
            .count(CountOption.exact);

        stats['supabase_count'] = response.count ?? 0;
      }

      return stats;
    } catch (e) {
      debugPrint('Error getting location stats: $e');
      return {'error': e.toString()};
    }
  }

  // =====================
  // DISPOSAL
  // =====================

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    stopListeningToPartner();
    _syncStatusController.close();
    _connectivityController.close();
    debugPrint('SupabaseLocationSyncService disposed');
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    this.failedCount = 0,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, synced: $syncedCount, failed: $failedCount)';
}
