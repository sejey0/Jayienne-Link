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
  LocationModel? _lastPartnerSavedLocation;

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
  String? get effectiveCoupleId {
    if (_coupleId != null && _coupleId!.isNotEmpty) return _coupleId;
    if (_currentUser?.coupleId != null && _currentUser!.coupleId!.isNotEmpty) {
      return _currentUser!.coupleId;
    }
    return null;
  }
  String? get effectiveUserId => _userId ?? _currentUser?.id;
  bool get hasPartner => (effectiveCoupleId != null && effectiveCoupleId!.isNotEmpty);
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

      if (isOnline) {
        unawaited(syncLocations());
      } else {
        _pendingSyncCount = await _storageService.getUnsyncedCount(userId);
        _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pending : SyncStatus.offline;
      }

      // Auto-restore location history from Firebase if local SQLite cache is empty (e.g. after fresh install)
      unawaited(() async {
        try {
          final count = await _storageService.getLocationCount(userId);
          if (count == 0) {
            debugPrint('📥 [LocationProvider] Reinstalled app or empty cache detected. Restoring history from Firebase...');
            await loadLocationHistory();
            if (_partnerId != null || _partnerUser?.id != null) {
              await loadPartnerLocationHistory();
            }
          }
        } catch (restoreErr) {
          debugPrint('⚠️ [LocationProvider] Auto-restore history error: $restoreErr');
        }
      }());

      // Fetch latest partner state directly from Firebase Realtime Database
      final cId = effectiveCoupleId;
      final pId = _partnerId ?? _partnerUser?.id;
      if (cId != null && pId != null) {
        final partnerLoc = await _firebaseLocationService.getPartnerLatestLocation(
          coupleId: cId,
          partnerId: pId,
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

      if (cId != null && pId != null) {
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
      final uId = effectiveUserId;
      if (uId == null) return;
      final cId = effectiveCoupleId;

      if (!kIsWeb) {
        try {
          _batteryLevel = await _battery.batteryLevel;
        } catch (_) {}
      }

      final now = DateTime.now();

      final locationModel = LocationModel(
        coupleId: cId ?? '',
        ownerId: uId,
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

        final locToSave = locationModel.copyWith(
          isSynced: isOnline,
          coupleId: cId ?? locationModel.coupleId,
          ownerId: uId,
        );
        await _storageService.insertLocation(locToSave);
        _pendingSyncCount = await _storageService.getUnsyncedCount(uId);
        _syncStatus = isOnline ? SyncStatus.synced : SyncStatus.offline;

        if (cId != null && cId.isNotEmpty) {
          _firebaseLocationService.recordHistoryPoint(
            coupleId: cId,
            userId: uId,
            location: locToSave,
          );
        }
      }

      // Publish directly to Firebase Realtime Database for true sub-second live tracking
      if (cId != null && cId.isNotEmpty) {
        _firebaseLocationService.publishLiveLocation(
          coupleId: cId,
          userId: uId,
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
          // Store partner location locally with smart deduplication (preventing duplicate stationary points)
          bool shouldSavePartner = true;
          if (_lastPartnerSavedLocation != null) {
            final partnerDistance = Geolocator.distanceBetween(
              _lastPartnerSavedLocation!.latitude,
              _lastPartnerSavedLocation!.longitude,
              location.latitude,
              location.longitude,
            );
            final elapsed = location.timestamp
                .difference(_lastPartnerSavedLocation!.timestamp)
                .abs();
            if (partnerDistance < 15.0 && elapsed < const Duration(seconds: 45)) {
              shouldSavePartner = false;
            }
          }

          if (shouldSavePartner) {
            _lastPartnerSavedLocation = location;
            await _storageService.insertLocation(location.copyWith(
              ownerId: _partnerId,
              source: LocationSource.partner,
              isSynced: true,
            ));
          }
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

    final uId = effectiveUserId;
    if (uId == null) return;
    final cId = effectiveCoupleId;

    final loc = _currentLocation ??
        await _storageService.getLastKnownLocation(uId);
    if (loc != null) {
      final updatedLoc = loc.copyWith(
        batteryLevel: _batteryLevel,
        timestamp: DateTime.now(),
        coupleId: cId ?? loc.coupleId,
        ownerId: uId,
      );
      _currentLocation = updatedLoc;

      // Only insert into local SQLite history & Firebase history if moved >= 15m or elapsed >= 5m
      bool shouldSaveToHistory = true;
      if (_lastSavedPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastSavedPosition!.latitude,
          _lastSavedPosition!.longitude,
          updatedLoc.latitude,
          updatedLoc.longitude,
        );
        final elapsed = DateTime.now().difference(_lastSavedTime ?? DateTime.now()).abs();
        if (distance < 15.0 && elapsed < const Duration(minutes: 5)) {
          shouldSaveToHistory = false;
        }
      }

      if (shouldSaveToHistory) {
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

        final locToSave = updatedLoc.copyWith(
          isSynced: isOnline,
          coupleId: cId ?? updatedLoc.coupleId,
          ownerId: uId,
        );
        await _storageService.insertLocation(locToSave);
        _pendingSyncCount = await _storageService.getUnsyncedCount(uId);

        if (cId != null && cId.isNotEmpty) {
          _firebaseLocationService.recordHistoryPoint(
            coupleId: cId,
            userId: uId,
            location: locToSave,
          );
        }
      }

      // Always publish current live location & battery to Firebase
      if (cId != null && cId.isNotEmpty) {
        _firebaseLocationService.publishLiveLocation(
          coupleId: cId,
          userId: uId,
          location: updatedLoc,
          batteryLevel: _batteryLevel,
          isCharging: _batteryState == BatteryState.charging,
        );
      }

      notifyListeners();
    } else if (cId != null && cId.isNotEmpty) {
      _firebaseLocationService.publishBatteryStatus(
        coupleId: cId,
        userId: uId,
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
    final uid = effectiveUserId;
    final cid = effectiveCoupleId;
    if (uid == null || cid == null || cid.isEmpty) {
      return SyncResult(
        success: false,
        message: 'Not initialized',
        syncedCount: 0,
      );
    }

    if (isOnline) {
      final unsynced = await _storageService.getUnsyncedLocations(uid);
      if (unsynced.isNotEmpty) {
        await _firebaseLocationService.recordHistoryBatch(
          coupleId: cid,
          userId: uid,
          locations: unsynced
              .map((loc) => loc.copyWith(isSynced: true, coupleId: cid, ownerId: uid))
              .toList(),
        );
        await _storageService.markAllAsSynced(uid);
        debugPrint('🚀 [LocationProvider] Synced ${unsynced.length} offline/background locations to Firebase');
      }
    }

    await _refreshLiveBatteryAndSync();
    _pendingSyncCount = await _storageService.getUnsyncedCount(uid);
    _syncStatus = isOnline ? SyncStatus.synced : SyncStatus.offline;
    notifyListeners();

    return SyncResult(
      success: true,
      message: 'Live Firebase synchronization active',
      syncedCount: 1,
    );
  }

  Future<void> refreshPartnerLocation() async {
    final cid = effectiveCoupleId;
    final pid = _partnerId ?? _partnerUser?.id;
    if (cid == null || pid == null) return;

    _setLoading(true);

    try {
      final latest = await _firebaseLocationService.getPartnerLatestLocation(
        coupleId: cid,
        partnerId: pid,
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
    final uid = effectiveUserId;
    if (uid == null) return;

    try {
      _currentUser = await _userService.getUser(uid);
      final pid = _partnerId ?? _partnerUser?.id;
      if (pid != null) {
        _partnerUser = await _userService.getUser(pid);
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
    final uid = effectiveUserId;
    if (uid == null) return;
    _setLoading(true);

    try {
      var localHistory = await _storageService.getLocationHistory(uid, limit: limit);
      final cid = effectiveCoupleId;

      // If local cache is empty (e.g. freshly reinstalled app) OR user forced refresh
      if ((localHistory.isEmpty || forceRefresh) && cid != null && cid.isNotEmpty) {
        debugPrint('🔄 [LocationProvider] Fetching remote history from Firebase for user $uid');
        final remoteHistory = await _firebaseLocationService.fetchAllHistory(
          coupleId: cid,
          userId: uid,
          limit: limit,
          source: LocationSource.local,
        );
        if (remoteHistory.isNotEmpty) {
          await _storageService.insertLocationsBatch(remoteHistory);
          localHistory = remoteHistory;
          debugPrint('✅ [LocationProvider] Restored ${remoteHistory.length} history points from Firebase into SQLite');
        }
      }

      _locationHistory = localHistory;
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPartnerLocationHistory({int limit = 100, bool forceRefresh = false}) async {
    final pid = _partnerId ?? _partnerUser?.id;
    if (pid == null) return;
    _setLoading(true);

    try {
      var partnerHistory = await _storageService.getLocationHistory(
        pid,
        limit: limit,
      );
      final cid = effectiveCoupleId;

      // If local cache is empty OR user forced refresh, fetch partner history from Firebase
      if ((partnerHistory.isEmpty || forceRefresh) && cid != null && cid.isNotEmpty) {
        debugPrint('🔄 [LocationProvider] Fetching partner history from Firebase for $pid');
        final remoteHistory = await _firebaseLocationService.fetchAllHistory(
          coupleId: cid,
          userId: pid,
          limit: limit,
          source: LocationSource.partner,
        );
        if (remoteHistory.isNotEmpty) {
          await _storageService.insertLocationsBatch(remoteHistory);
          partnerHistory = remoteHistory;
          debugPrint('✅ [LocationProvider] Restored ${remoteHistory.length} partner history points from Firebase into SQLite');
        }
      }

      _partnerLocationHistory = partnerHistory;
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

      final uid = effectiveUserId;
      final cid = effectiveCoupleId;
      if (uid != null && cid != null) {
        await _backgroundService.startPeriodicTracking(
          userId: uid,
          coupleId: cid,
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
    final uid = effectiveUserId;
    if (uid == null) return;
    _settings = newSettings;
    await LocalCacheService.saveSharingEnabled(newSettings.sharingEnabled);
    await _storageService.saveSettings(uid, newSettings);
    notifyListeners();
  }

  Future<void> deleteAllHistory() async {
    final uid = effectiveUserId;
    if (uid == null) return;
    _setLoading(true);

    try {
      await _storageService.deleteAllUserLocations(uid);
      final cid = effectiveCoupleId;
      if (cid != null && cid.isNotEmpty) {
        await _firebaseLocationService.deleteHistory(
          coupleId: cid,
          userId: uid,
        );
      }
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
    _historyLocations = [];
    notifyListeners();

    try {
      var points = await _storageService.getLocationsByDate(
        ownerId,
        date,
      );

      final cid = effectiveCoupleId;
      // If local storage has 0 points, fetch history from Firebase and cache locally
      if (points.isEmpty && cid != null && cid.isNotEmpty) {
        final remotePoints = await _firebaseLocationService.fetchHistoryForDate(
          coupleId: cid,
          userId: ownerId,
          date: date,
        );
        if (remotePoints.isNotEmpty) {
          await _storageService.insertLocationsBatch(remotePoints);
          points = remotePoints;
        }
      }

      _historyLocations = sanitizeRouteLocations(points);
      _playbackIndex = 0;
    } catch (e) {
      debugPrint('Error loading location history: $e');
      _historyLocations = [];
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Sanitize & filter location history points to eliminate GPS outliers,
  /// (0,0) null-island glitches, inaccurate cell-tower estimates, and teleportation spikes.
  List<LocationModel> sanitizeRouteLocations(List<LocationModel> raw) {
    if (raw.isEmpty) return [];

    // 1. Basic Validity & Coordinates Range Filter
    final validPoints = raw.where((loc) {
      if (loc.latitude == 0.0 && loc.longitude == 0.0) return false;
      if (loc.latitude.isNaN || loc.longitude.isNaN) return false;
      if (loc.latitude.abs() > 90.0 || loc.longitude.abs() > 180.0) return false;
      return true;
    }).toList();

    if (validPoints.length <= 1) return validPoints;

    // 2. Accuracy Filter:
    // Prioritize high-accuracy GPS fixes (<= 40m).
    // Drop coarse cell tower triangulations (> 60m) that jump across neighborhoods.
    final tightAccuracyPoints =
        validPoints.where((loc) => loc.accuracy <= 40.0).toList();
    final moderateAccuracyPoints =
        validPoints.where((loc) => loc.accuracy <= 60.0).toList();

    final candidatePoints = tightAccuracyPoints.length >= 2
        ? tightAccuracyPoints
        : (moderateAccuracyPoints.length >= 2
            ? moderateAccuracyPoints
            : validPoints);

    if (candidatePoints.length <= 1) return candidatePoints;

    // 3. Teleportation / Impossible Speed & Bounce Spike Filter
    final List<LocationModel> clean = [candidatePoints.first];

    for (int i = 1; i < candidatePoints.length; i++) {
      final current = candidatePoints[i];
      final lastValid = clean.last;

      final distanceMeters = Geolocator.distanceBetween(
        lastValid.latitude,
        lastValid.longitude,
        current.latitude,
        current.longitude,
      );

      final seconds = current.timestamp
          .difference(lastValid.timestamp)
          .inSeconds
          .abs();
      final effectiveSeconds = seconds > 0 ? seconds : 1;
      final speedMps = distanceMeters / effectiveSeconds;

      // Impossible speed (> 38 m/s = ~137 km/h) over a noticeable distance (> 70m)
      if (distanceMeters > 70 && speedMps > 38.0) {
        if (i + 1 < candidatePoints.length) {
          final next = candidatePoints[i + 1];
          final nextDistFromLast = Geolocator.distanceBetween(
            lastValid.latitude,
            lastValid.longitude,
            next.latitude,
            next.longitude,
          );
          if (nextDistFromLast < distanceMeters * 0.45) {
            // Outlier bounce spike - skip!
            continue;
          }
        }
        if (speedMps > 55.0) continue;
      }

      // Isolated spatial jump filter (> 500m that snaps back)
      if (distanceMeters > 500 && i + 1 < candidatePoints.length) {
        final next = candidatePoints[i + 1];
        final nextDistFromLast = Geolocator.distanceBetween(
          lastValid.latitude,
          lastValid.longitude,
          next.latitude,
          next.longitude,
        );
        if (nextDistFromLast < 250) {
          continue;
        }
      }

      clean.add(current);
    }

    if (clean.length <= 1) return clean;

    // 4. Stationary Day Collapse:
    // If the user stayed in one place (all points fall within a 60m radius of origin),
    // collapse the entire day into the single highest-accuracy stationary anchor point.
    // This eliminates indoor GPS wandering, spiderwebs, and erratic vehicle movements.
    double maxSpreadFromFirst = 0.0;
    final firstPoint = clean.first;
    for (final pt in clean) {
      final d = Geolocator.distanceBetween(
        firstPoint.latitude,
        firstPoint.longitude,
        pt.latitude,
        pt.longitude,
      );
      if (d > maxSpreadFromFirst) {
        maxSpreadFromFirst = d;
      }
    }

    if (maxSpreadFromFirst < 60.0) {
      LocationModel bestAnchor = clean.first;
      for (final pt in clean) {
        if (pt.accuracy < bestAnchor.accuracy) {
          bestAnchor = pt;
        }
      }
      return [bestAnchor];
    }

    // 5. Stationary Dwell Clustering (for actual travel routes):
    // When stopped at home, work, or school, GPS jitters by 10-30m.
    // Do not create polyline vertices for stationary jitter; only progress
    // when moving progressively >= 30m away from the active anchor.
    final List<LocationModel> stabilized = [clean.first];
    LocationModel activeAnchor = clean.first;

    for (int i = 1; i < clean.length - 1; i++) {
      final current = clean[i];
      final distFromAnchor = Geolocator.distanceBetween(
        activeAnchor.latitude,
        activeAnchor.longitude,
        current.latitude,
        current.longitude,
      );

      if (distFromAnchor < 30.0) {
        if (current.accuracy < activeAnchor.accuracy) {
          activeAnchor = current;
          stabilized[stabilized.length - 1] = current;
        }
        continue;
      }

      stabilized.add(current);
      activeAnchor = current;
    }

    final lastPoint = clean.last;
    final distFromLastSaved = Geolocator.distanceBetween(
      stabilized.last.latitude,
      stabilized.last.longitude,
      lastPoint.latitude,
      lastPoint.longitude,
    );
    if (distFromLastSaved > 15.0) {
      stabilized.add(lastPoint);
    }

    return stabilized.isNotEmpty ? stabilized : clean;
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
    if (_playbackIndex >= _historyLocations.length - 1) {
      _playbackIndex = 0;
    }
    _isPlayingRoute = true;
    _playbackTimer?.cancel();

    // Step to the next point immediately if starting at beginning
    if (_playbackIndex < _historyLocations.length - 1) {
      _playbackIndex++;
    }

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
      if (_historyLocations.isNotEmpty &&
          _playbackIndex >= _historyLocations.length - 1) {
        _playbackIndex = 0;
      }
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
    final cid = effectiveCoupleId;
    final uid = effectiveUserId;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // App went to background or user backed out -> immediately mark offline with exact lastSeen timestamp
      if (cid != null && uid != null) {
        _firebaseLocationService.markUserOffline(cid, uid);
      }
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground -> push current location & battery immediately and sync
      if (cid != null && uid != null) {
        _refreshLiveBatteryAndSync();
        unawaited(syncLocations());
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
