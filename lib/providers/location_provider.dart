import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../services/offline_location_service.dart';
import '../services/offline_storage_service.dart';
import '../services/firebase_location_service.dart';
import '../services/background_location_service.dart';
import '../services/foreground_notification_service.dart';
import '../services/supabase_user_service.dart';
import '../services/local_cache_service.dart';
import 'debug_provider.dart';

/// Result object for location sync operations
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final String? error;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    this.failedCount = 0,
    this.error,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, synced: $syncedCount, failed: $failedCount, message: $message)';
}

/// Senior GIS & Location Provider managing Geolocator streams, battery efficiency,
/// real-time partner location updates, geodesic distance calculations, and Firebase streaming.
class LocationProvider extends ChangeNotifier with WidgetsBindingObserver {
  final OfflineLocationService _locationService = OfflineLocationService.instance;
  final OfflineStorageService _storageService = OfflineStorageService.instance;
  final FirebaseLocationService _firebaseLocationService = FirebaseLocationService.instance;
  final BackgroundLocationService _backgroundService = BackgroundLocationService.instance;
  final ForegroundNotificationService _notificationService = ForegroundNotificationService.instance;
  final SupabaseUserService _userService;
  final DebugProvider? _debugProvider;
  final Battery _battery = Battery();

  StreamSubscription<bool>? _offlineStreamSub;

  LocationProvider(this._userService, [this._debugProvider]) {
    WidgetsBinding.instance.addObserver(this);
    _debugProvider?.addListener(_onDebugModeChanged);
    _offlineStreamSub = DebugProvider.offlineModeStream.listen((_) => _onDebugModeChanged());
  }

  void _onDebugModeChanged() async {
    final forcedOffline = (_debugProvider?.forceOfflineMode ?? false) || DebugProvider.isOfflineForced;
    if (_userId != null) {
      _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);
    }
    if (forcedOffline) {
      _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.offline;
    } else {
      _syncStatus = isOnline
          ? (_pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.synced)
          : SyncStatus.offline;
    }
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // State
  LocationModel? _currentLocation;
  LocationModel? _partnerLocation;
  List<LocationModel> _locationHistory = [];
  List<LocationModel> _partnerLocationHistory = [];
  LocationSharingSettings _settings = LocationSharingSettings();
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.denied;
  final bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.synced;
  int _pendingSyncCount = 0;
  bool _isLoading = false;
  String? _error;

  // User details
  String? _userId;
  String? _partnerId;
  String? _coupleId;
  UserModel? _currentUser;
  UserModel? _partnerUser;

  // Battery monitoring
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  int? _partnerBatteryLevel;
  bool _isPartnerCharging = false;
  bool _isPartnerOnline = false;
  DateTime? _partnerLastSeen;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _foregroundCaptureTimer;

  // Subscriptions
  StreamSubscription<LocationModel?>? _locationSubscription;
  StreamSubscription<LocationModel?>? _partnerLocationSubscription;
  StreamSubscription<Map<String, dynamic>>? _partnerBatterySubscription;
  StreamSubscription<Position>? _devicePositionSubscription;

  // Throttling references
  Position? _lastSavedPosition;
  DateTime? _lastSavedTime;
  int? _lastSavedBattery;

  // Route playback state
  List<LocationModel> _historyLocations = [];
  bool _isHistoryMode = false;
  bool _isLoadingHistory = false;
  bool _isPlayingRoute = false;
  int _playbackIndex = 0;
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;
  DateTime _selectedHistoryDate = DateTime.now();
  String? _historyOwnerId;

  // Getters
  LocationModel? get currentLocation => _currentLocation;
  LocationModel? get partnerLocation => _partnerLocation;
  List<LocationModel> get locationHistory => _locationHistory;
  List<LocationModel> get partnerLocationHistory => _partnerLocationHistory;
  LocationSharingSettings get settings => _settings;
  LocationPermissionStatus get permissionStatus => _permissionStatus;
  bool get isOnline => _isOnline && !(_debugProvider?.forceOfflineMode ?? false) && !DebugProvider.isOfflineForced;
  SyncStatus get syncStatus => _syncStatus;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSharingEnabled => _settings.sharingEnabled;
  bool get isBackgroundSharingEnabled => _settings.backgroundSharingEnabled;
  String? get userId => _userId;
  String? get partnerId => _partnerId;
  String? get coupleId => _coupleId;
  bool get hasPartner => _coupleId != null && _coupleId!.isNotEmpty;
  bool get canShare => _permissionStatus.canTrack && hasPartner;
  UserModel? get currentUser => _currentUser;
  UserModel? get partnerUser => _partnerUser;
  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  bool get isMyCharging => _batteryState == BatteryState.charging;
  int? get partnerBatteryLevel => _partnerBatteryLevel;
  bool get isPartnerCharging => _isPartnerCharging;
  DateTime? get partnerLastSeen => _partnerLastSeen ?? _partnerLocation?.timestamp;

  // History Getters
  List<LocationModel> get historyLocations => _historyLocations;
  bool get isHistoryMode => _isHistoryMode;
  bool get isPlayingRoute => _isPlayingRoute;
  int get playbackIndex => _playbackIndex;
  double get playbackSpeed => _playbackSpeed;
  DateTime get selectedHistoryDate => _selectedHistoryDate;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get historyOwnerId => _historyOwnerId;
  LocationModel? get currentPlaybackLocation =>
      (_historyLocations.isNotEmpty && _playbackIndex < _historyLocations.length)
          ? _historyLocations[_playbackIndex]
          : null;

  // Geodesic calculations
  LatLng? get currentLatLng => _currentLocation?.latLng;
  LatLng? get myLatLng => currentLatLng;
  LatLng? get partnerLatLng => _partnerLocation?.latLng;
  LatLng? get interpolatedPartnerLatLng => partnerLatLng;
  List<LatLng> get historyPolylinePoints =>
      _historyLocations.map((l) => l.latLng).toList();
  LatLng? get playbackLatLng => currentPlaybackLocation?.latLng;

  double? get distanceToPartner {
    if (currentLatLng == null || partnerLatLng == null) return null;
    const distance = Distance();
    return distance.as(LengthUnit.Meter, currentLatLng!, partnerLatLng!);
  }

  double? get distanceInMeters => distanceToPartner;

  double? get distanceToPartnerKm {
    final meters = distanceToPartner;
    return meters != null ? meters / 1000.0 : null;
  }

  String get formattedDistanceToPartner {
    final meters = distanceToPartner;
    if (meters == null) return 'Distance unavailable';
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m away';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km away';
    }
  }

  String get formattedDistance => formattedDistanceToPartner;

  // Camera & Bounds Helpers
  LatLng get mapCenter {
    if (currentLatLng != null && partnerLatLng != null) {
      final midLat = (currentLatLng!.latitude + partnerLatLng!.latitude) / 2;
      final midLng = (currentLatLng!.longitude + partnerLatLng!.longitude) / 2;
      return LatLng(midLat, midLng);
    }
    return currentLatLng ?? partnerLatLng ?? const LatLng(14.5995, 120.9842); // Default to Manila
  }

  LatLngBounds? get coupleBounds {
    if (currentLatLng == null || partnerLatLng == null) return null;
    return LatLngBounds.fromPoints([currentLatLng!, partnerLatLng!]);
  }

  bool isPartnerOnline() {
    if (_debugProvider?.simulatedPartnerOnlineStatus != null) {
      return _debugProvider!.simulatedPartnerOnlineStatus!;
    }
    if (_isPartnerOnline) return true;
    if (_partnerLocation == null) return false;
    final diff = DateTime.now().difference(_partnerLocation!.timestamp.toLocal());
    return diff.inMinutes < 5;
  }

  String get partnerTimeAgo {
    if (_partnerLocation == null || !isPartnerOnline()) return 'Offline';
    final diff = DateTime.now().difference(_partnerLocation!.timestamp.toLocal());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return 'Offline';
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
      await _firebaseLocationService.initialize();
      await _backgroundService.initialize();
      await _notificationService.initialize();
      await _initBatteryMonitoring();

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

      // Fetch latest partner state directly from Firebase Realtime Database
      if (_coupleId != null && _partnerId != null) {
        final partnerLoc = await _firebaseLocationService.getPartnerLatestLocation(
          coupleId: _coupleId!,
          partnerId: _partnerId!,
        );
        if (partnerLoc != null) {
          _partnerLocation = partnerLoc;
          _partnerLastSeen = partnerLoc.timestamp;
          if (partnerLoc.batteryLevel != null) {
            _partnerBatteryLevel = partnerLoc.batteryLevel;
          }
        }
      }

      _subscribeToStreams();
      _startBatterySmartLocationStream();

      if (_coupleId != null && _partnerId != null) {
        _startPartnerLocationListening();
      }

      // Auto-start sharing location if phone location is enabled and permission is granted
      if (_userId != null && _permissionStatus.canTrack && hasPartner) {
        if (!_settings.sharingEnabled) {
          _settings = _settings.copyWith(sharingEnabled: true);
          await _updateSettings(_settings);
        }
        await startTracking();
        await startForegroundRecording();
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
    if (kIsWeb) return;
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      _batterySubscription?.cancel();
      _batterySubscription =
          _battery.onBatteryStateChanged.listen((state) async {
        _batteryState = state;
        try {
          _batteryLevel = await _battery.batteryLevel;
        } catch (_) {}
        notifyListeners();
        // Immediately sync live battery change to partner via Firebase
        _refreshLiveBatteryAndSync();
      });
    } catch (e) {
      debugPrint('Battery info unavailable: $e');
    }
  }

  /// Start battery-smart Geolocator stream with distance filter (15m)
  void _startBatterySmartLocationStream() {
    if (!_permissionStatus.canTrack) return;

    _devicePositionSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
      distanceFilter: 15, // Only trigger after 15m movement to save battery
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

      final now = DateTime.now();

      final locationModel = LocationModel(
        coupleId: _coupleId ?? '',
        ownerId: _userId!,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
        batteryLevel: _batteryLevel,
        timestamp: now,
        createdAt: now,
      );

      _currentLocation = locationModel;

      // Smart database throttling check to prevent 1-second local disk database bloat
      bool shouldSaveToDb = true;
      if (_lastSavedPosition != null && _lastSavedTime != null) {
        final elapsed = now.difference(_lastSavedTime!);
        final distance = Geolocator.distanceBetween(
          _lastSavedPosition!.latitude,
          _lastSavedPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        if (position.speed < 0.5 && distance < 15.0) {
          if (_lastSavedBattery != _batteryLevel ||
              elapsed >= const Duration(minutes: 2)) {
            shouldSaveToDb = true;
          } else {
            shouldSaveToDb = false;
          }
        } else if (elapsed < const Duration(seconds: 15) && distance < 20.0) {
          shouldSaveToDb = false;
        }
      }

      if (shouldSaveToDb) {
        _lastSavedPosition = position;
        _lastSavedTime = now;
        _lastSavedBattery = _batteryLevel;

        await _storageService.insertLocation(locationModel);
        _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);
        _syncStatus = SyncStatus.synced;

        if (_coupleId != null && _userId != null) {
          _firebaseLocationService.recordHistoryPoint(
            coupleId: _coupleId!,
            userId: _userId!,
            location: locationModel,
          );
        }
      }

      // Publish directly to Firebase Realtime Database for true sub-second live tracking
      if (_coupleId != null && _userId != null) {
        _firebaseLocationService.publishLiveLocation(
          coupleId: _coupleId!,
          userId: _userId!,
          location: locationModel,
          batteryLevel: _batteryLevel,
          isCharging: _batteryState == BatteryState.charging,
        );
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
        _syncStatus = isOnline ? SyncStatus.synced : SyncStatus.offline;

        if (_coupleId != null && _userId != null) {
          _firebaseLocationService.publishLiveLocation(
            coupleId: _coupleId!,
            userId: _userId!,
            location: location,
            batteryLevel: _batteryLevel,
            isCharging: _batteryState == BatteryState.charging,
          );
        }

        notifyListeners();
      },
    );
  }

  void _startPartnerLocationListening() {
    if (_coupleId == null || _partnerId == null) return;

    _partnerLocationSubscription?.cancel();
    _partnerBatterySubscription?.cancel();

    _firebaseLocationService.startListeningToPartner(
      coupleId: _coupleId!,
      partnerId: _partnerId!,
    );

    _partnerLocationSubscription =
        _firebaseLocationService.partnerLocationStream.listen(
      (location) async {
        if (location != null) {
          _partnerLocation = location;
          _partnerLastSeen = location.timestamp;
          if (location.batteryLevel != null) {
            _partnerBatteryLevel = location.batteryLevel;
          }
          // Store partner location locally in SQLite so history & route playback work
          await _storageService.insertLocation(location.copyWith(
            ownerId: _partnerId,
            source: LocationSource.partner,
          ));
          notifyListeners();
        }
      },
    );

    _partnerBatterySubscription =
        _firebaseLocationService.partnerBatteryStream.listen(
      (batteryData) {
        final level = batteryData['batteryLevel'] as int?;
        final isCharging = batteryData['isCharging'] == true;
        _isPartnerOnline = batteryData['isOnline'] == true;
        final lastSeenVal = batteryData['lastSeen'] ?? batteryData['timestamp'];
        if (lastSeenVal is int) {
          _partnerLastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenVal);
        } else if (lastSeenVal is String) {
          _partnerLastSeen = DateTime.tryParse(lastSeenVal);
        }
        if (level != null) {
          _partnerBatteryLevel = level;
        }
        _isPartnerCharging = isCharging;
        if (_partnerLocation != null && level != null) {
          _partnerLocation = _partnerLocation!.copyWith(
            batteryLevel: level,
          );
        }
        notifyListeners();
      },
    );
  }

  // =====================
  // LOCATION CAPTURE & TRACKING
  // =====================

  Future<void> startForegroundRecording() async {
    if (_userId == null || !_permissionStatus.canTrack) return;

    await _refreshLiveBatteryAndSync();

    _foregroundCaptureTimer?.cancel();
    _foregroundCaptureTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) async {
        if (_userId == null || !_permissionStatus.canTrack) return;
        await _refreshLiveBatteryAndSync();
      },
    );
  }

  Future<void> stopForegroundRecording() async {
    _foregroundCaptureTimer?.cancel();
  }

  Future<LocationModel?> captureLocation() async {
    if (_userId == null) return null;
    await _refreshLiveBatteryAndSync();
    return _currentLocation;
  }

  /// Live Battery & Presence Pulse
  Future<void> _refreshLiveBatteryAndSync() async {
    if (_userId == null) return;
    if (!kIsWeb) {
      try {
        final currentLvl = await _battery.batteryLevel;
        _batteryLevel = currentLvl;
        _batteryState = await _battery.batteryState;
      } catch (_) {}
    }

    final loc = _currentLocation ??
        await _storageService.getLastKnownLocation(_userId!);
    if (loc != null) {
      final updatedLoc = loc.copyWith(
        batteryLevel: _batteryLevel,
        timestamp: DateTime.now(),
      );
      _currentLocation = updatedLoc;
      _lastSavedPosition = Position(
        latitude: updatedLoc.latitude,
        longitude: updatedLoc.longitude,
        timestamp: updatedLoc.timestamp,
        accuracy: updatedLoc.accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: updatedLoc.heading ?? 0,
        headingAccuracy: 0,
        speed: updatedLoc.speed ?? 0,
        speedAccuracy: 0,
      );
      _lastSavedTime = DateTime.now();
      _lastSavedBattery = _batteryLevel;

      await _storageService.insertLocation(updatedLoc);
      _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);

      if (_coupleId != null && _userId != null) {
        _firebaseLocationService.publishLiveLocation(
          coupleId: _coupleId!,
          userId: _userId!,
          location: updatedLoc,
          batteryLevel: _batteryLevel,
          isCharging: _batteryState == BatteryState.charging,
        );
        _firebaseLocationService.recordHistoryPoint(
          coupleId: _coupleId!,
          userId: _userId!,
          location: updatedLoc,
        );
      }

      notifyListeners();
    } else if (_coupleId != null && _userId != null) {
      _firebaseLocationService.publishBatteryStatus(
        coupleId: _coupleId!,
        userId: _userId!,
        batteryLevel: _batteryLevel,
        isCharging: _batteryState == BatteryState.charging,
      );
    }
  }

  Future<void> startTracking() async {
    if (!_permissionStatus.canTrack) {
      await requestPermission();
    }

    if (_permissionStatus.canTrack && _userId != null) {
      await _locationService.startTracking(_userId!);
      await _updateSettings(_settings.copyWith(sharingEnabled: true));
      await _notificationService.showTrackingNotification();
      _startBatterySmartLocationStream();
      await startForegroundRecording();
    }
  }

  Future<void> stopTracking() async {
    _devicePositionSubscription?.cancel();
    _foregroundCaptureTimer?.cancel();
    await _locationService.stopTracking();
    await _updateSettings(_settings.copyWith(sharingEnabled: false));
    await _notificationService.hideTrackingNotification();
    await _backgroundService.stopPeriodicTracking();
  }

  // =====================
  // SYNC & REFRESH OPERATIONS
  // =====================

  Future<SyncResult> syncLocations() async {
    if (_userId == null || _coupleId == null) {
      return SyncResult(
        success: false,
        message: 'Not initialized',
        syncedCount: 0,
      );
    }

    await _refreshLiveBatteryAndSync();
    _pendingSyncCount = await _storageService.getUnsyncedCount(_userId!);
    _syncStatus = SyncStatus.synced;
    notifyListeners();

    return SyncResult(
      success: true,
      message: 'Live Firebase synchronization active',
      syncedCount: 1,
    );
  }

  Future<void> refreshPartnerLocation() async {
    if (_coupleId == null || _partnerId == null) return;

    _setLoading(true);

    try {
      final latest = await _firebaseLocationService.getPartnerLatestLocation(
        coupleId: _coupleId!,
        partnerId: _partnerId!,
      );
      if (latest != null) {
        _partnerLocation = latest;
        notifyListeners();
      }
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

  Future<void> loadLocationHistory({int limit = 100, bool forceRefresh = false}) async {
    if (_userId == null) return;
    _setLoading(true);

    try {
      final localHistory = await _storageService.getLocationHistory(_userId!, limit: limit);
      _locationHistory = localHistory;
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPartnerLocationHistory({int limit = 100}) async {
    if (_partnerId == null) return;
    _setLoading(true);

    try {
      _partnerLocationHistory = await _storageService.getLocationHistory(
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

    if (_userId != null && _permissionStatus.canTrack && hasPartner) {
      if (!_settings.sharingEnabled) {
        _settings = _settings.copyWith(sharingEnabled: true);
        await _updateSettings(_settings);
      }
      await startTracking();
      await startForegroundRecording();
    }

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
    if (_userId == null) return;
    _setLoading(true);

    try {
      await _storageService.deleteAllUserLocations(_userId!);
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
  // LOCATION HISTORY & PLAYBACK
  // =====================

  Future<void> loadLocationHistoryForDate({
    required String ownerId,
    required DateTime date,
  }) async {
    _historyOwnerId = ownerId;
    _selectedHistoryDate = date;
    _isLoadingHistory = true;
    _playbackTimer?.cancel();
    _isPlayingRoute = false;
    _playbackIndex = 0;
    notifyListeners();

    try {
      var points = await _storageService.getLocationsByDate(
        ownerId,
        date,
      );

      // If local storage has 0 points, fetch history from Firebase and cache locally
      if (points.isEmpty && _coupleId != null) {
        final remotePoints = await _firebaseLocationService.fetchHistoryForDate(
          coupleId: _coupleId!,
          userId: ownerId,
          date: date,
        );
        if (remotePoints.isNotEmpty) {
          await _storageService.insertLocationsBatch(remotePoints);
          points = remotePoints;
        }
      }

      _historyLocations = points;
      _playbackIndex = 0;
    } catch (e) {
      debugPrint('Error loading location history: $e');
      _historyLocations = [];
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  void setHistoryOwner(String ownerId) {
    _historyOwnerId = ownerId;
    loadLocationHistoryForDate(ownerId: ownerId, date: _selectedHistoryDate);
  }

  void toggleHistoryMode(bool enable, {String? ownerId}) {
    _isHistoryMode = enable;
    if (enable) {
      final targetOwner = ownerId ?? _historyOwnerId ?? _partnerId ?? _userId;
      if (targetOwner != null) {
        loadLocationHistoryForDate(ownerId: targetOwner, date: _selectedHistoryDate);
      }
    } else {
      pauseRoutePlayback();
    }
    notifyListeners();
  }

  void setSelectedHistoryDate(DateTime date, {String? ownerId}) {
    final targetOwner = ownerId ?? _historyOwnerId ?? _partnerId ?? _userId;
    if (targetOwner != null) {
      loadLocationHistoryForDate(ownerId: targetOwner, date: date);
    }
  }

  void startRoutePlayback() {
    if (_historyLocations.isEmpty) return;
    _isPlayingRoute = true;
    _playbackTimer?.cancel();

    final intervalMs = (1000 / _playbackSpeed).round();
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_playbackIndex < _historyLocations.length - 1) {
        _playbackIndex++;
        notifyListeners();
      } else {
        pauseRoutePlayback();
      }
    });
    notifyListeners();
  }

  void pauseRoutePlayback() {
    _isPlayingRoute = false;
    _playbackTimer?.cancel();
    notifyListeners();
  }

  void toggleRoutePlayback() {
    if (_isPlayingRoute) {
      pauseRoutePlayback();
    } else {
      startRoutePlayback();
    }
  }

  void seekRoutePlayback(int index) {
    if (_historyLocations.isEmpty) return;
    _playbackIndex = index.clamp(0, _historyLocations.length - 1);
    notifyListeners();
  }

  void seekPlayback(int index) => seekRoutePlayback(index);

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlayingRoute) {
      startRoutePlayback();
    } else {
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // App went to background or user backed out -> immediately mark offline with exact lastSeen timestamp
      if (_coupleId != null && _userId != null) {
        _firebaseLocationService.markUserOffline(_coupleId!, _userId!);
      }
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground -> push current location & battery immediately
      if (_coupleId != null && _userId != null) {
        _refreshLiveBatteryAndSync();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _offlineStreamSub?.cancel();
    _debugProvider?.removeListener(_onDebugModeChanged);
    _devicePositionSubscription?.cancel();
    _batterySubscription?.cancel();
    _locationSubscription?.cancel();
    _partnerLocationSubscription?.cancel();
    _partnerBatterySubscription?.cancel();
    _firebaseLocationService.stopListeningToPartner();
    _foregroundCaptureTimer?.cancel();
    _playbackTimer?.cancel();
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
