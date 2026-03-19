import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/location_model.dart';
import 'offline_storage_service.dart';

/// Service for syncing locations between local SQLite and Firestore.
/// Monitors connectivity and auto-syncs when internet is available.
class LocationSyncService {
  static LocationSyncService? _instance;
  final OfflineStorageService _storage = OfflineStorageService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  // Connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;

  // Sync state stream
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _connectivityController = StreamController<bool>.broadcast();

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const int _batchSize = 50; // Max locations per batch upload

  // Partner location listener
  StreamSubscription<QuerySnapshot>? _partnerLocationSubscription;

  // Stored credentials for auto-sync
  String? _userId;
  String? _coupleId;

  LocationSyncService._();

  static LocationSyncService get instance {
    _instance ??= LocationSyncService._();
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

  // =====================
  // INITIALIZATION
  // =====================

  /// Initialize the sync service and start monitoring connectivity
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasInternetConnection(result);
    _connectivityController.add(_isOnline);

    // Start monitoring connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) {
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

    debugPrint('LocationSyncService initialized. Online: $_isOnline');
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
    return result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;
  }

  // =====================
  // SYNC OPERATIONS
  // =====================

  /// Sync all unsynced locations to Firestore
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

      debugPrint('Syncing ${unsynced.length} locations...');

      int totalSynced = 0;
      final localToFirestoreIds = <int, String>{};

      // Process in batches for efficiency
      for (var i = 0; i < unsynced.length; i += _batchSize) {
        final batch = unsynced.skip(i).take(_batchSize).toList();
        final result = await _uploadBatchWithRetry(batch, coupleId);

        if (result != null) {
          localToFirestoreIds.addAll(result);
          totalSynced += result.length;
        }
      }

      // Mark all synced locations
      if (localToFirestoreIds.isNotEmpty) {
        await _storage.markBatchAsSynced(localToFirestoreIds);
      }

      _syncStatusController.add(SyncStatus.synced);
      return SyncResult(
        success: true,
        message: 'Synced $totalSynced locations',
        syncedCount: totalSynced,
      );
    } catch (e) {
      debugPrint('Sync error: $e');
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

    return null; // All retries failed
  }

  /// Upload a batch of locations to Firestore
  Future<Map<int, String>> _uploadBatch(
    List<LocationModel> batch,
    String coupleId,
  ) async {
    final result = <int, String>{};
    final firestoreBatch = _firestore.batch();

    for (final location in batch) {
      final docRef = _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('locations')
          .doc();

      firestoreBatch.set(docRef, {
        ...location.toFirestore(),
        'couple_id': coupleId,
      });

      if (location.id != null) {
        result[location.id!] = docRef.id;
      }
    }

    await firestoreBatch.commit();
    return result;
  }

  // =====================
  // PARTNER LOCATIONS
  // =====================

  /// Start listening for partner's location updates
  void startListeningToPartner(
    String coupleId,
    String partnerId,
    void Function(LocationModel) onNewLocation,
  ) {
    _partnerLocationSubscription?.cancel();

    _partnerLocationSubscription = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('locations')
        .where('owner_id', isEqualTo: partnerId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final location = LocationModel.fromFirestore(snapshot.docs.first);
          onNewLocation(location);

          // Also store locally for offline access
          _storage.storePartnerLocations([location]);
        }
      },
      onError: (error) {
        debugPrint('Partner location listener error: $error');
      },
    );
  }

  /// Stop listening for partner's locations
  void stopListeningToPartner() {
    _partnerLocationSubscription?.cancel();
    _partnerLocationSubscription = null;
  }

  /// Fetch partner's recent locations from Firestore
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
      Query query = _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('locations')
          .where('owner_id', isEqualTo: partnerId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (since != null) {
        query =
            query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      final locations =
          snapshot.docs.map((doc) => LocationModel.fromFirestore(doc)).toList();

      // Cache locally for offline access
      await _storage.storePartnerLocations(locations);

      return locations;
    } catch (e) {
      debugPrint('Error fetching partner locations: $e');
      // Fall back to cached locations
      return await _storage.getLocationHistory(partnerId, limit: limit);
    }
  }

  /// Get partner's last known location (from cache or Firestore)
  Future<LocationModel?> getPartnerLastLocation(
    String coupleId,
    String partnerId,
  ) async {
    // Try local cache first
    final cached = await _storage.getPartnerLastLocation(partnerId);

    if (!_isOnline) {
      return cached;
    }

    // Fetch latest from Firestore
    try {
      final snapshot = await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('locations')
          .where('owner_id', isEqualTo: partnerId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return cached;
      }

      final latest = LocationModel.fromFirestore(snapshot.docs.first);

      // Update cache
      await _storage.storePartnerLocations([latest]);

      // Return the more recent one
      if (cached != null && cached.timestamp.isAfter(latest.timestamp)) {
        return cached;
      }
      return latest;
    } catch (e) {
      debugPrint('Error fetching partner last location: $e');
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
    debugPrint('Cleaned up $deleted old locations');
  }

  /// Delete all user location data (privacy feature)
  Future<void> deleteAllUserData(String userId, String coupleId) async {
    // Delete from local storage
    await _storage.deleteAllUserLocations(userId);

    // Delete from Firestore if online
    if (_isOnline) {
      try {
        final batch = _firestore.batch();
        final snapshot = await _firestore
            .collection('couples')
            .doc(coupleId)
            .collection('locations')
            .where('owner_id', isEqualTo: userId)
            .get();

        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      } catch (e) {
        debugPrint('Error deleting Firestore locations: $e');
      }
    }
  }

  // =====================
  // DISPOSAL
  // =====================

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _partnerLocationSubscription?.cancel();
    _syncStatusController.close();
    _connectivityController.close();
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
  String toString() => 'SyncResult(success: $success, synced: $syncedCount)';
}
