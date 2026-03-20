import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../services/offline_location_service.dart';
import '../services/offline_storage_service.dart';
import '../services/supabase_location_sync_service.dart';
import '../services/background_location_service.dart';
import '../services/foreground_notification_service.dart';
import '../services/supabase_user_service.dart';

/// Provider for managing location state across the app.
/// Handles offline-first location sharing with partner.
class LocationProvider extends ChangeNotifier {
  final OfflineLocationService _locationService =
      OfflineLocationService.instance;
  final OfflineStorageService _storageService = OfflineStorageService.instance;
  final SupabaseLocationSyncService _syncService = SupabaseLocationSyncService.instance;
  final BackgroundLocationService _backgroundService =
      BackgroundLocationService.instance;
  final ForegroundNotificationService _notificationService =
      ForegroundNotificationService.instance;
  final SupabaseUserService _userService;

  LocationProvider(this._userService);

  // User info (set by initialize)
  String? _userId;
  String? _coupleId;
  String? _partnerId;
  UserModel? _currentUser;
  UserModel? _partnerUser;

  // Location state
  LocationModel? _currentLocation;
  LocationModel? _partnerLocation;
  List<LocationModel> _locationHistory = [];
  List<LocationModel> _partnerLocationHistory = [];

  // Settings
  LocationSharingSettings _settings = LocationSharingSettings();
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.denied;

  // Status
  bool _isOnline = false;
  SyncStatus _syncStatus = SyncStatus.synced;
  int _pendingSyncCount = 0;
  bool _isLoading = false;
  String? _error;

  // Stream subscriptions
  StreamSubscription? _locationSubscription;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _syncStatusSubscription;
  StreamSubscription<LocationModel>? _partnerLocationSubscription;

  // Getters
  LocationModel? get currentLocation => _currentLocation;
  LocationModel? get partnerLocation => _partnerLocation;
  List<LocationModel> get locationHistory => _locationHistory;
  List<LocationModel> get partnerLocationHistory => _partnerLocationHistory;
  LocationSharingSettings get settings => _settings;
  LocationPermissionStatus get permissionStatus => _permissionStatus;
  bool get isOnline => _isOnline;
  SyncStatus get syncStatus => _syncStatus;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSharingEnabled => _settings.sharingEnabled;
  bool get isBackgroundSharingEnabled => _settings.backgroundSharingEnabled;
  bool get hasPartner => _partnerId != null;
  bool get canShare => _permissionStatus.canTrack && hasPartner;
  UserModel? get currentUser => _currentUser;
  UserModel? get partnerUser => _partnerUser;

  // =====================
  // INITIALIZATION
  // =====================

  /// Initialize the provider with user context
  Future<void> initialize({
    required String userId,
    String? coupleId,
    String? partnerId,
  }) async {
    _userId = userId;
    _coupleId = coupleId;
    _partnerId = partnerId;

    _setLoading(true);

    try {
      // Initialize sync service
      await _syncService.initialize();

      // Initialize background services
      await _backgroundService.initialize();
      await _notificationService.initialize();

      // Store credentials for auto-sync when online
      if (coupleId != null) {
        _syncService.setCredentials(userId, coupleId);
      }

      // Load settings
      _settings = await _storageService.getSettings(userId) ??
          LocationSharingSettings();

      // Check permission status
      _permissionStatus = await _locationService.getPermissionStatus();

      // Load last known locations
      _currentLocation = await _storageService.getLastKnownLocation(userId);

      if (partnerId != null) {
        _partnerLocation =
            await _storageService.getPartnerLastLocation(partnerId);
      }

      // Load user data for profile images
      _currentUser = await _userService.getUser(userId);
      if (partnerId != null) {
        _partnerUser = await _userService.getUser(partnerId);
      }

      // Get pending sync count
      _pendingSyncCount = await _storageService.getUnsyncedCount(userId);
      _syncStatus =
          _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.synced;

      // Subscribe to streams
      _subscribeToStreams();

      // Start partner location listening if coupled
      if (coupleId != null && partnerId != null) {
        _startPartnerLocationListening();
      }

      // Auto-sync if online and has pending
      if (_syncService.isOnline && _pendingSyncCount > 0 && coupleId != null) {
        syncLocations();
      }
    } catch (e) {
      _error = 'Failed to initialize location: $e';
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  void _subscribeToStreams() {
    // Listen to location updates
    _locationSubscription = _locationService.locationStream.listen(
      (location) {
        _currentLocation = location;
        _pendingSyncCount++;
        _syncStatus = SyncStatus.pending;
        notifyListeners();
      },
    );

    // Listen to connectivity changes
    _connectivitySubscription = _syncService.connectivityStream.listen(
      (isOnline) {
        final wasOffline = !_isOnline;
        _isOnline = isOnline;

        if (isOnline && wasOffline && _pendingSyncCount > 0) {
          // Auto-sync when coming online
          syncLocations();
        }

        if (!isOnline) {
          _syncStatus = SyncStatus.offline;
        }

        notifyListeners();
      },
    );

    // Listen to sync status
    _syncStatusSubscription = _syncService.syncStatusStream.listen(
      (status) {
        _syncStatus = status;
        notifyListeners();
      },
    );

    _isOnline = _syncService.isOnline;
  }

  void _startPartnerLocationListening() {
    if (_coupleId == null || _partnerId == null) return;

    _partnerLocationSubscription?.cancel();
    _partnerLocationSubscription =
        _syncService.startListeningToPartner(_coupleId!, _partnerId!).listen(
      (location) {
        _partnerLocation = location;
        notifyListeners();
      },
    );
  }

  // =====================
  // LOCATION CAPTURE
  // =====================

  /// Capture current location (manual trigger)
  Future<bool> captureLocation() async {
    if (_userId == null) return false;
    if (!_permissionStatus.canTrack) {
      _error = _permissionStatus.message;
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final location = await _locationService.getCurrentLocation(_userId!);
      if (location != null) {
        _currentLocation = location;
        _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);
        _syncStatus = SyncStatus.pending;

        // Try to sync if online
        if (_isOnline && _coupleId != null) {
          syncLocations();
        }

        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to capture location: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Start continuous location tracking
  Future<bool> startTracking() async {
    if (_userId == null) return false;
    if (!_permissionStatus.canTrack) return false;

    final success = await _locationService.startTracking(_userId!);
    if (success) {
      await _updateSettings(_settings.copyWith(sharingEnabled: true));

      // Show foreground notification
      await _notificationService.showTrackingNotification();

      // Start background periodic tracking if coupled
      if (_coupleId != null) {
        await _backgroundService.startPeriodicTracking(
          userId: _userId!,
          coupleId: _coupleId!,
          intervalMinutes: _settings.updateIntervalMinutes,
        );
      }
    }
    return success;
  }

  /// Stop continuous location tracking
  Future<void> stopTracking() async {
    await _locationService.stopTracking();
    await _updateSettings(_settings.copyWith(sharingEnabled: false));

    // Hide notification and stop background tracking
    await _notificationService.hideTrackingNotification();
    await _backgroundService.stopPeriodicTracking();
  }

  // =====================
  // SYNC OPERATIONS
  // =====================

  /// Sync unsynced locations to Supabase
  Future<SyncResult> syncLocations() async {
    if (_userId == null || _coupleId == null) {
      return SyncResult(
        success: false,
        message: 'Not initialized',
        syncedCount: 0,
      );
    }

    final result = await _syncService.syncLocations(_userId!, _coupleId!);

    if (result.success) {
      _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);
      _syncStatus =
          _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.synced;
    }

    notifyListeners();
    return result;
  }

  /// Force refresh partner's location
  Future<void> refreshPartnerLocation() async {
    if (_coupleId == null || _partnerId == null) return;

    _setLoading(true);

    try {
      _partnerLocation = await _syncService.getPartnerLastLocation(
        _coupleId!,
        _partnerId!,
      );
    } catch (e) {
      debugPrint('Error refreshing partner location: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh user data including profile images
  Future<void> refreshUserData() async {
    if (_userId == null) return;

    try {
      _currentUser = await _userService.getUser(_userId!);
      if (_partnerId != null) {
        _partnerUser = await _userService.getUser(_partnerId!);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }

  // =====================
  // HISTORY
  // =====================

  /// Load location history
  Future<void> loadLocationHistory({int limit = 100}) async {
    if (_userId == null) return;

    _setLoading(true);

    try {
      _locationHistory = await _storageService.getLocationHistory(
        _userId!,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load partner's location history
  Future<void> loadPartnerLocationHistory({int limit = 100}) async {
    if (_coupleId == null || _partnerId == null) return;

    _setLoading(true);

    try {
      _partnerLocationHistory = await _syncService.fetchPartnerLocations(
        _coupleId!,
        _partnerId!,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error loading partner history: $e');
    } finally {
      _setLoading(false);
    }
  }

  // =====================
  // PERMISSIONS
  // =====================

  /// Request location permission
  Future<bool> requestPermission() async {
    final permission = await _locationService.requestPermission();
    _permissionStatus = await _locationService.getPermissionStatus();
    notifyListeners();

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  /// Request background location permission
  Future<bool> requestBackgroundPermission() async {
    final granted = await _locationService.requestBackgroundPermission();
    _permissionStatus = await _locationService.getPermissionStatus();
    notifyListeners();
    return granted;
  }

  /// Open device settings
  Future<void> openSettings() async {
    if (_permissionStatus == LocationPermissionStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else {
      await _locationService.openAppSettings();
    }
  }

  // =====================
  // SETTINGS
  // =====================

  /// Toggle location sharing
  Future<void> toggleSharing() async {
    if (_settings.sharingEnabled) {
      await stopTracking();
    } else {
      await startTracking();
    }
  }

  /// Toggle background sharing
  Future<void> toggleBackgroundSharing() async {
    final enabled = !_settings.backgroundSharingEnabled;

    if (enabled) {
      final granted = await requestBackgroundPermission();
      if (!granted) return;

      // Start background periodic tracking
      if (_userId != null && _coupleId != null) {
        await _backgroundService.startPeriodicTracking(
          userId: _userId!,
          coupleId: _coupleId!,
          intervalMinutes: _settings.updateIntervalMinutes,
        );
        await _notificationService.showTrackingNotification(
          title: 'Background tracking active',
          body: 'Location updates every ${_settings.updateIntervalMinutes} min',
        );
      }
    } else {
      // Stop background tracking
      await _backgroundService.stopPeriodicTracking();
      await _notificationService.hideTrackingNotification();
    }

    await _updateSettings(
        _settings.copyWith(backgroundSharingEnabled: enabled));
  }

  /// Toggle data saver mode for slow connections
  Future<void> toggleDataSaver() async {
    final enabled = !_settings.dataSaverEnabled;
    await _updateSettings(_settings.copyWith(dataSaverEnabled: enabled));

    // Update sync service with data saver setting
    _syncService.setDataSaverEnabled(enabled);
  }

  /// Check if data saver is enabled
  bool get isDataSaverEnabled => _settings.dataSaverEnabled;

  Future<void> _updateSettings(LocationSharingSettings newSettings) async {
    if (_userId == null) return;

    _settings = newSettings;
    await _storageService.saveSettings(_userId!, newSettings);
    notifyListeners();
  }

  // =====================
  // PRIVACY
  // =====================

  /// Delete all location history
  Future<void> deleteAllHistory() async {
    if (_userId == null || _coupleId == null) return;

    _setLoading(true);

    try {
      await _syncService.deleteAllUserData(_userId!, _coupleId!);
      _locationHistory.clear();
      _currentLocation = null;
      _pendingSyncCount = 0;
    } catch (e) {
      _error = 'Failed to delete history: $e';
    } finally {
      _setLoading(false);
    }
  }

  // =====================
  // UTILITY
  // =====================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update partner info (when couple links)
  void updatePartnerInfo(String coupleId, String partnerId) {
    _coupleId = coupleId;
    _partnerId = partnerId;
    _startPartnerLocationListening();
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusSubscription?.cancel();
    _partnerLocationSubscription?.cancel();
    _syncService.stopListeningToPartner();
    // Note: Don't stop background tracking on dispose - keep running in background
    super.dispose();
  }

  /// Method to restore background tracking state on app resume
  Future<void> restoreBackgroundTrackingState() async {
    if (_userId == null || _coupleId == null) return;

    final isTrackingEnabled = await _backgroundService.isTrackingEnabled();
    if (isTrackingEnabled && _settings.backgroundSharingEnabled) {
      await _notificationService.showTrackingNotification(
        title: 'Background tracking active',
        body: 'Location updates every ${_settings.updateIntervalMinutes} min',
      );
    }
  }
}
