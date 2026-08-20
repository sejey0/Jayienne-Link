import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../services/offline_location_service.dart';
import '../services/offline_storage_service.dart';
import '../services/supabase_location_sync_service.dart';
import '../services/background_location_service.dart';
import '../services/foreground_notification_service.dart';
import '../services/supabase_user_service.dart';
import '../services/local_cache_service.dart';
import 'debug_provider.dart';

/// Senior GIS & Location Provider managing Geolocator streams, battery efficiency,
/// real-time partner location lerp interpolation, geodesic distance calculations, and camera bounds.
class LocationProvider extends ChangeNotifier {
  final OfflineLocationService _locationService = OfflineLocationService.instance;
  final OfflineStorageService _storageService = OfflineStorageService.instance;
  final SupabaseLocationSyncService _syncService = SupabaseLocationSyncService.instance;
  final BackgroundLocationService _backgroundService = BackgroundLocationService.instance;
  final ForegroundNotificationService _notificationService = ForegroundNotificationService.instance;
  final SupabaseUserService _userService;
  final DebugProvider? _debugProvider;
  final Battery _battery = Battery();

  LocationProvider(this._userService, [this._debugProvider]) {
    _debugProvider?.addListener(_onDebugModeChanged);
  }

  void _onDebugModeChanged() async {
    final forcedOffline = _debugProvider?.forceOfflineMode ?? false;
    if (_userId != null) {
      _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);
    }
    if (forcedOffline) {
      _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.offline;
    } else {
      if (isOnline && _pendingSyncCount > 0 && _coupleId != null) {
        syncLocations();
      } else {
        _syncStatus = isOnline
            ? (_pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.synced)
            : SyncStatus.offline;
      }
    }
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // User credentials & models
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

  // Smooth Interpolation State
  LatLng? _visualPartnerLatLng;

  // Battery State
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;

  // Settings & Permission
  LocationSharingSettings _settings = LocationSharingSettings();
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.denied;

  // Status flags
  bool _isOnline = false;
  SyncStatus _syncStatus = SyncStatus.synced;
  int _pendingSyncCount = 0;
  bool _isLoading = false;
  String? _error;

  // Stream Subscriptions
  StreamSubscription<Position>? _devicePositionSubscription;
  StreamSubscription<BatteryState>? _batterySubscription;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _syncStatusSubscription;
  StreamSubscription<LocationModel>? _partnerLocationSubscription;
  Timer? _foregroundCaptureTimer;

  static const Distance _distanceCalculator = Distance();
  static const Duration _foregroundCaptureInterval = Duration(minutes: 1);

  // Getters
  LocationModel? get currentLocation => _currentLocation;
  LocationModel? get partnerLocation => _partnerLocation;
  List<LocationModel> get locationHistory => _locationHistory;
  List<LocationModel> get partnerLocationHistory => _partnerLocationHistory;
  LocationSharingSettings get settings => _settings;
  LocationPermissionStatus get permissionStatus => _permissionStatus;
  bool get isOnline => _isOnline && !(_debugProvider?.forceOfflineMode ?? false);
  SyncStatus get syncStatus => _syncStatus;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSharingEnabled => _settings.sharingEnabled;
  bool get isBackgroundSharingEnabled => _settings.backgroundSharingEnabled;
  bool get hasPartner => _coupleId != null && _coupleId!.isNotEmpty;
  bool get canShare => _permissionStatus.canTrack && hasPartner;
  UserModel? get currentUser => _currentUser;
  UserModel? get partnerUser => _partnerUser;
  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;

  /// Current user position as LatLng
  LatLng? get myLatLng {
    if (_currentLocation == null) return null;
    return LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
  }

  /// Partner position as LatLng
  LatLng? get partnerLatLng {
    if (_partnerLocation == null) return null;
    return LatLng(_partnerLocation!.latitude, _partnerLocation!.longitude);
  }

  LatLng _interpolateLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Smoothly interpolated partner position for 60 FPS map rendering
  LatLng? get interpolatedPartnerLatLng {
    final target = partnerLatLng;
    if (target == null) return null;
    if (_visualPartnerLatLng == null) {
      _visualPartnerLatLng = target;
      return target;
    }
    _visualPartnerLatLng = _interpolateLatLng(_visualPartnerLatLng!, target, 0.25);
    return _visualPartnerLatLng;
  }

  /// Real-time geodesic distance in meters between partners
  double get distanceInMeters {
    final p1 = myLatLng;
    final p2 = partnerLatLng;
    if (p1 == null || p2 == null) return 0.0;
    return _distanceCalculator.as(LengthUnit.Meter, p1, p2);
  }

  /// Formatted real-time distance string (e.g., "450 m away" or "12.4 km away")
  String get formattedDistance {
    final meters = distanceInMeters;
    if (meters <= 0.0) return 'Location unknown';
    if (meters < 1000) {
      return '${meters.round()} m away';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km away';
  }

  /// Movement activity status derived from partner speed
  String get partnerActivityStatus {
    if (_partnerLocation == null || _partnerLocation!.speed == null) {
      return 'Stationary';
    }
    final speedMs = _partnerLocation!.speed!;
    final speedKmh = speedMs * 3.6;

    if (speedKmh < 2.0) {
      return 'Stationary';
    } else if (speedKmh < 8.0) {
      return 'Walking';
    } else if (speedKmh < 25.0) {
      return 'Cycling (${speedKmh.toStringAsFixed(0)} km/h)';
    } else {
      return 'Driving (${speedKmh.toStringAsFixed(0)} km/h)';
    }
  }

  /// Calculate bounding box fitting both partners on the map
  LatLngBounds? get coupleBounds {
    final p1 = myLatLng;
    final p2 = partnerLatLng;
    if (p1 == null || p2 == null) return null;
    return LatLngBounds.fromPoints([p1, p2]);
  }

  // =====================
  // INITIALIZATION
  // =====================

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
      await _syncService.initialize();
      await _backgroundService.initialize();
      await _notificationService.initialize();
      await _initBatteryMonitoring();

      if (_coupleId != null && _coupleId!.isNotEmpty) {
        _syncService.setCredentials(userId, _coupleId!);
      }

      final savedSharingEnabled = await LocalCacheService.loadSharingEnabled();
      final dbSettings = await _storageService.getSettings(userId);
      _settings = (dbSettings ?? LocationSharingSettings(sharingEnabled: savedSharingEnabled)).copyWith(
        sharingEnabled: dbSettings?.sharingEnabled ?? savedSharingEnabled,
      );
      _permissionStatus = await _locationService.getPermissionStatus();
      _currentLocation = await _storageService.getLastKnownLocation(userId);

      if (_partnerId != null) {
        _partnerLocation = await _storageService.getPartnerLastLocation(_partnerId!);
      }

      final cachedUser = await LocalCacheService.loadUser();
      if (cachedUser != null && cachedUser.id == userId) {
        _currentUser = cachedUser;
        if ((_coupleId == null || _coupleId!.isEmpty) &&
            cachedUser.coupleId != null &&
            cachedUser.coupleId!.isNotEmpty) {
          _coupleId = cachedUser.coupleId;
          _syncService.setCredentials(userId, _coupleId!);
        }
      }

      UserModel? cachedPartner;
      if (_partnerId != null || _coupleId != null) {
        cachedPartner = await LocalCacheService.loadPartner();
      }
      if (cachedPartner != null) {
        if (_partnerId == null && _coupleId != null) {
          _partnerId = cachedPartner.id;
          _partnerUser = cachedPartner;
        } else if (_partnerId != null && cachedPartner.id == _partnerId) {
          _partnerUser = cachedPartner;
        }
      }

      try {
        _currentUser = await _userService.getUser(userId);
        if (_currentUser != null) {
          await LocalCacheService.saveUser(_currentUser!);
        }
      } catch (e) {
        debugPrint('Offline user fetch failed: $e');
      }

      if (_partnerId != null) {
        try {
          _partnerUser = await _userService.getUser(_partnerId!);
          if (_partnerUser != null) {
            await LocalCacheService.savePartner(_partnerUser!);
          }
        } catch (e) {
          debugPrint('Offline partner fetch failed: $e');
        }
      }

      _pendingSyncCount = await _storageService.getUnsyncedCount(userId);
      _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.synced;

      // Fallback: If local SQLite has no last known coordinates (e.g. Web), fetch from Supabase
      if (_currentLocation == null && _coupleId != null) {
        _currentLocation = await _syncService.fetchUserLastLocation(_coupleId!, userId);
      }
      if (_partnerLocation == null && _coupleId != null && _partnerId != null) {
        _partnerLocation = await _syncService.getPartnerLastLocation(_coupleId!, _partnerId!);
      }

      _subscribeToStreams();
      _startBatterySmartLocationStream();

      if (_coupleId != null && _partnerId != null) {
        _startPartnerLocationListening();
      }

      if (_syncService.isOnline && _pendingSyncCount > 0 && _coupleId != null) {
        syncLocations();
      }
    } catch (e) {
      _error = 'Failed to initialize location: $e';
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  /// Initialize Battery Monitoring
  Future<void> _initBatteryMonitoring() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
        _batteryState = state;
        _batteryLevel = await _battery.batteryLevel;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Battery info unavailable: $e');
    }
  }

  /// Start battery-smart Geolocator stream with distance filter (10m)
  void _startBatterySmartLocationStream() {
    if (!_permissionStatus.canTrack) return;

    _devicePositionSubscription?.cancel();
    final locationSettings = LocationSettings(
      accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
      distanceFilter: 10, // Only trigger after 10m movement to save battery
    );

    _devicePositionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      if (_userId == null) return;

      if (!kIsWeb) {
        try {
          _batteryLevel = await _battery.batteryLevel;
        } catch (_) {}
      }

      final locationModel = LocationModel(
        coupleId: _coupleId ?? '',
        ownerId: _userId!,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        accuracy: position.accuracy,
        batteryLevel: _batteryLevel,
        timestamp: DateTime.now(),
        createdAt: DateTime.now(),
      );

      _currentLocation = locationModel;
      await _storageService.insertLocation(locationModel);
      _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);

      if (isOnline && _coupleId != null) {
        syncLocations();
      } else {
        _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.offline;
      }

      notifyListeners();
    }, onError: (err) {
      debugPrint('Geolocator position stream error: $err');
    });
  }

  void _subscribeToStreams() {
    _locationSubscription = _locationService.locationStream.listen(
      (location) async {
        _currentLocation = location;
        if (_userId != null) {
          _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);
        } else {
          _pendingSyncCount++;
        }
        _syncStatus = isOnline ? SyncStatus.pending : SyncStatus.offline;
        notifyListeners();
      },
    );

    _connectivitySubscription = _syncService.connectivityStream.listen(
      (realtimeOnline) {
        final wasOffline = isOnline;
        _isOnline = realtimeOnline;

        if (isOnline && !wasOffline && _pendingSyncCount > 0) {
          syncLocations();
        }

        if (!isOnline) {
          _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.offline;
        }

        notifyListeners();
      },
    );

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
  // LOCATION CAPTURE & TRACKING
  // =====================

  Future<void> startForegroundRecording() async {
    if (_userId == null || !_permissionStatus.canTrack) return;

    await _locationService.captureLocationSmart(_userId!);

    _foregroundCaptureTimer?.cancel();
    _foregroundCaptureTimer = Timer.periodic(
      _foregroundCaptureInterval,
      (_) async {
        if (_userId == null || !_permissionStatus.canTrack) return;
        if (_locationService.isTracking) return;
        await _locationService.captureLocationSmart(_userId!);
      },
    );
  }

  Future<void> stopForegroundRecording() async {
    _foregroundCaptureTimer?.cancel();
    _foregroundCaptureTimer = null;
  }

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
        _syncStatus = isOnline
            ? (_pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.synced)
            : (_pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.offline);

        if (isOnline && _coupleId != null) {
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

  Future<bool> startTracking() async {
    if (_userId == null || !_permissionStatus.canTrack) return false;

    final success = await _locationService.startTracking(_userId!);
    if (success) {
      await _updateSettings(_settings.copyWith(sharingEnabled: true));
      await _notificationService.showTrackingNotification();

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

  Future<void> stopTracking() async {
    await _locationService.stopTracking();
    await _updateSettings(_settings.copyWith(sharingEnabled: false));
    await _notificationService.hideTrackingNotification();
    await _backgroundService.stopPeriodicTracking();
  }

  // =====================
  // SYNC OPERATIONS
  // =====================

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
      _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.synced;
    }

    notifyListeners();
    return result;
  }

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

  Future<void> refreshUserData() async {
    if (_userId == null) return;

    try {
      _currentUser = await _userService.getUser(_userId!);
      if (_partnerId != null) {
        _partnerUser = await _userService.getUser(_partnerId!);
      }
      if (_currentUser != null) {
        await LocalCacheService.saveUser(_currentUser!);
      }
      if (_partnerUser != null) {
        await LocalCacheService.savePartner(_partnerUser!);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }

  // =====================
  // HISTORY & PERMISSIONS
  // =====================

  Future<void> loadLocationHistory({int limit = 100, bool forceRefresh = false}) async {
    if (_userId == null) return;
    _setLoading(true);

    try {
      var localHistory = await _storageService.getLocationHistory(_userId!, limit: limit);
      final canFetchRemote = _coupleId != null && _syncService.isOnline;

      if (canFetchRemote && (forceRefresh || localHistory.isEmpty)) {
        await _syncService.fetchUserLocations(_coupleId!, _userId!, limit: limit);
        localHistory = await _storageService.getLocationHistory(_userId!, limit: limit);
      }

      _locationHistory = localHistory;
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _setLoading(false);
    }
  }

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

  Future<bool> requestPermission() async {
    final permission = await _locationService.requestPermission();
    _permissionStatus = await _locationService.getPermissionStatus();
    _startBatterySmartLocationStream();
    notifyListeners();
    return permission != LocationPermission.denied && permission != LocationPermission.deniedForever;
  }

  Future<bool> requestBackgroundPermission() async {
    final granted = await _locationService.requestBackgroundPermission();
    _permissionStatus = await _locationService.getPermissionStatus();
    notifyListeners();
    return granted;
  }

  Future<void> openSettings() async {
    if (_permissionStatus == LocationPermissionStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else {
      await _locationService.openAppSettings();
    }
  }

  Future<void> toggleSharing() async {
    if (_settings.sharingEnabled) {
      await stopTracking();
    } else {
      await startTracking();
    }
  }

  Future<void> toggleBackgroundSharing() async {
    final enabled = !_settings.backgroundSharingEnabled;
    if (enabled) {
      final granted = await requestBackgroundPermission();
      if (!granted) return;

      if (_userId != null && _coupleId != null) {
        await _backgroundService.startPeriodicTracking(
          userId: _userId!,
          coupleId: _coupleId!,
          intervalMinutes: _settings.updateIntervalMinutes,
        );
      }
    } else {
      await _backgroundService.stopPeriodicTracking();
      await _notificationService.hideTrackingNotification();
    }

    await _updateSettings(_settings.copyWith(backgroundSharingEnabled: enabled));
  }

  Future<void> toggleDataSaver() async {
    final enabled = !_settings.dataSaverEnabled;
    await _updateSettings(_settings.copyWith(dataSaverEnabled: enabled));
    _syncService.setDataSaverEnabled(enabled);
  }

  bool get isDataSaverEnabled => _settings.dataSaverEnabled;

  Future<void> _updateSettings(LocationSharingSettings newSettings) async {
    if (_userId == null) return;
    _settings = newSettings;
    await LocalCacheService.saveSharingEnabled(newSettings.sharingEnabled);
    await _storageService.saveSettings(_userId!, newSettings);
    notifyListeners();
  }

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

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void updatePartnerInfo(String coupleId, String partnerId) {
    _coupleId = coupleId;
    _partnerId = partnerId;
    _startPartnerLocationListening();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debugProvider?.removeListener(_onDebugModeChanged);
    _devicePositionSubscription?.cancel();
    _batterySubscription?.cancel();
    _locationSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusSubscription?.cancel();
    _partnerLocationSubscription?.cancel();
    _syncService.stopListeningToPartner();
    _foregroundCaptureTimer?.cancel();
    super.dispose();
  }

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
