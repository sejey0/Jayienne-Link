import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'debug_provider.dart';

/// App-wide real-time network connectivity provider.
/// Accurately combines physical hardware connectivity (Wi-Fi, Mobile Data)
/// with the Admin Console's "Simulate Offline Mode" override.
class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  StreamSubscription? _offlineOverrideSub;

  List<ConnectivityResult> _currentResults = const [ConnectivityResult.none];
  bool _isRealConnected = true;
  bool _isInitialized = false;

  ConnectivityProvider() {
    _init();
  }

  bool get isInitialized => _isInitialized;

  /// Effective online status: True ONLY if physical device has active connection
  /// AND simulated offline mode is NOT active.
  bool get isOnline => _isRealConnected && !DebugProvider.isOfflineForced;

  /// Effective offline status
  bool get isOffline => !isOnline;

  /// Whether simulated offline mode is currently active from Admin Console
  bool get isSimulatedOffline => DebugProvider.isOfflineForced;

  /// Whether the device physically has Wi-Fi or Mobile Data connected
  bool get hasRealConnection => _isRealConnected;

  /// Hardware Wi-Fi connection active (and not simulated offline)
  bool get isWifi =>
      isOnline && _currentResults.contains(ConnectivityResult.wifi);

  /// Hardware Mobile Data connection active (and not simulated offline)
  bool get isMobileData =>
      isOnline && _currentResults.contains(ConnectivityResult.mobile);

  /// Human-readable connectivity description for UI & debugging
  String get statusDescription {
    if (DebugProvider.isOfflineForced) {
      return 'Simulated Offline (Admin)';
    }
    if (!_isRealConnected) {
      return 'No Wi-Fi or Mobile Data';
    }
    if (_currentResults.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi Connected';
    }
    if (_currentResults.contains(ConnectivityResult.mobile)) {
      return 'Mobile Data Connected';
    }
    return 'Online';
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      debugPrint('⚠️ [ConnectivityProvider] Initial check notice: $e');
    }

    // Real hardware connectivity updates
    _connectivitySub = _connectivity.onConnectivityChanged.listen((dynamic event) {
      if (event is List<ConnectivityResult>) {
        _handleConnectivityChange(event);
      } else if (event is ConnectivityResult) {
        _handleConnectivityChange([event]);
      }
    });

    // Admin Console simulated offline mode updates
    _offlineOverrideSub = DebugProvider.offlineModeStream.listen((isForced) {
      _applyEffectiveState();
      notifyListeners();
    });

    _isInitialized = true;
    _applyEffectiveState();
    notifyListeners();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    _currentResults = results;
    _isRealConnected = results.any((r) => r != ConnectivityResult.none);
    _applyEffectiveState();
    notifyListeners();
  }

  void _applyEffectiveState() {
    final effectiveOffline = isOffline;
    try {
      if (effectiveOffline) {
        FirebaseDatabase.instance.goOffline();
      } else {
        FirebaseDatabase.instance.goOnline();
      }
    } catch (_) {}
  }

  /// Manually re-check real hardware connectivity
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      debugPrint('⚠️ [ConnectivityProvider] Check error: $e');
    }
    return isOnline;
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _offlineOverrideSub?.cancel();
    super.dispose();
  }
}
