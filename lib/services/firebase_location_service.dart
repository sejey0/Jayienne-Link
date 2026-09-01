import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/location_model.dart';
import '../providers/debug_provider.dart';

/// Senior Real-Time Location & Battery Engine powered by Firebase Realtime Database.
/// Provides sub-second latency, continuous GPS streaming, battery state sync,
/// and automatic disconnect presence detection between couples.
class FirebaseLocationService {
  static FirebaseLocationService? _instance;

  static const String _databaseUrl =
      'https://jayienne-link-51c81-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _rootNode = 'live_locations';

  FirebaseDatabase? _database;
  bool _isInitialized = false;

  // Realtime subscriptions
  StreamSubscription<DatabaseEvent>? _partnerLocationSub;
  final StreamController<LocationModel?> _partnerLocationController =
      StreamController<LocationModel?>.broadcast();

  final StreamController<Map<String, dynamic>> _partnerBatteryController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Active tracking credentials
  String? _activePartnerId;

  FirebaseLocationService._();

  static FirebaseLocationService get instance {
    _instance ??= FirebaseLocationService._();
    return _instance!;
  }

  /// Stream emitting partner's live location and battery updates
  Stream<LocationModel?> get partnerLocationStream =>
      _partnerLocationController.stream;

  /// Stream emitting partner's live battery status (level & isCharging)
  Stream<Map<String, dynamic>> get partnerBatteryStream =>
      _partnerBatteryController.stream;

  bool get isInitialized => _isInitialized;

  /// Initialize Firebase Realtime Database instance and configure options
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _databaseUrl,
      );

      // Enable offline disk persistence on native platforms for fast cache
      if (!kIsWeb) {
        try {
          _database!.setPersistenceEnabled(true);
          _database!.setPersistenceCacheSizeBytes(10 * 1024 * 1024); // 10MB
        } catch (_) {}
      }

      _isInitialized = true;
      debugPrint('🔥 [FirebaseLocationService] Initialized with RTDB node: $_databaseUrl');
    } catch (e) {
      debugPrint('⚠️ [FirebaseLocationService] Initialization notice: $e');
    }
  }

  DatabaseReference _getCoupleNode(String coupleId) {
    _database ??= FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    );
    return _database!.ref('$_rootNode/$coupleId');
  }

  /// Publish the current user's live coordinates, telemetry, and battery status
  Future<void> publishLiveLocation({
    required String coupleId,
    required String userId,
    required LocationModel location,
    required int batteryLevel,
    required bool isCharging,
  }) async {
    if (DebugProvider.isOfflineForced) {
      debugPrint('🔌 [FirebaseLocationService] Skipped publish: Simulated Offline Mode');
      return;
    }

    try {
      final userNode = _getCoupleNode(coupleId).child(userId);

      final payload = location.toFirebase(
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        isOnline: true,
      );

      await userNode.set(payload);

      // Register automatic onDisconnect presence
      await userNode.child('isOnline').onDisconnect().set(false);
      await userNode.child('lastSeen').onDisconnect().set(ServerValue.timestamp);
    } catch (e) {
      debugPrint('❌ [FirebaseLocationService] publishLiveLocation error: $e');
    }
  }

  /// Publish instantaneous battery level & charging state updates (e.g. cable plugged in)
  Future<void> publishBatteryStatus({
    required String coupleId,
    required String userId,
    required int batteryLevel,
    required bool isCharging,
  }) async {
    if (DebugProvider.isOfflineForced) return;

    try {
      final userNode = _getCoupleNode(coupleId).child(userId);
      await userNode.update({
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
        'isOnline': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('⚠️ [FirebaseLocationService] publishBatteryStatus error: $e');
    }
  }

  /// Start real-time listening to partner's location & battery node
  void startListeningToPartner({
    required String coupleId,
    required String partnerId,
  }) {
    if (_activePartnerId == partnerId && _partnerLocationSub != null) {
      return;
    }

    _partnerLocationSub?.cancel();
    _activePartnerId = partnerId;

    try {
      final partnerNode = _getCoupleNode(coupleId).child(partnerId);

      _partnerLocationSub = partnerNode.onValue.listen(
        (event) {
          if (DebugProvider.isOfflineForced) {
            _partnerLocationController.add(null);
            return;
          }

          final data = event.snapshot.value;
          if (data != null && data is Map) {
            try {
              final location = LocationModel.fromFirebase(
                data,
                coupleId: coupleId,
                partnerId: partnerId,
              );

              _partnerLocationController.add(location);

              if (data['batteryLevel'] != null) {
                _partnerBatteryController.add({
                  'batteryLevel': (data['batteryLevel'] as num).toInt(),
                  'isCharging': data['isCharging'] == true,
                  'isOnline': data['isOnline'] == true,
                  'timestamp': data['timestamp'],
                });
              }
            } catch (err) {
              debugPrint('⚠️ [FirebaseLocationService] Parse error: $err');
            }
          } else {
            _partnerLocationController.add(null);
          }
        },
        onError: (err) {
          debugPrint('⚠️ [FirebaseLocationService] Partner stream error: $err');
        },
      );

      debugPrint('🔥 [FirebaseLocationService] Listening to partner: $partnerId in couple: $coupleId');
    } catch (e) {
      debugPrint('❌ [FirebaseLocationService] startListeningToPartner failed: $e');
    }
  }

  /// Fetch partner's latest location snapshot once
  Future<LocationModel?> getPartnerLatestLocation({
    required String coupleId,
    required String partnerId,
  }) async {
    if (DebugProvider.isOfflineForced) return null;

    try {
      final partnerNode = _getCoupleNode(coupleId).child(partnerId);
      final snapshot = await partnerNode.get();
      final data = snapshot.value;

      if (data != null && data is Map) {
        return LocationModel.fromFirebase(
          data,
          coupleId: coupleId,
          partnerId: partnerId,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [FirebaseLocationService] getPartnerLatestLocation error: $e');
    }
    return null;
  }

  /// Stop listening to partner
  void stopListeningToPartner() {
    _partnerLocationSub?.cancel();
    _partnerLocationSub = null;
    _activePartnerId = null;
  }

  /// Disconnect user presence when logging out
  Future<void> markUserOffline(String coupleId, String userId) async {
    try {
      final userNode = _getCoupleNode(coupleId).child(userId);
      await userNode.update({
        'isOnline': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}
