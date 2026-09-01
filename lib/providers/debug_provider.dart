import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug provider for testing offline mode, developer tools, and partner status simulation
class DebugProvider extends ChangeNotifier {
  static const String _keyDebugMode = 'admin_debug_mode_override';
  static const String _keyForceOffline = 'debug_force_offline_mode';

  /// Global static accessor so background services, Supabase interceptors, and sync managers
  /// can immediately recognize simulated offline mode without requiring a BuildContext.
  static bool isOfflineForced = false;
  static final StreamController<bool> _offlineModeStreamController =
      StreamController<bool>.broadcast();

  /// Global broadcast stream that fires whenever simulated offline mode is toggled
  static Stream<bool> get offlineModeStream => _offlineModeStreamController.stream;

  bool _forceOfflineMode = false;
  bool? _simulatedPartnerOnlineStatus; // null = Auto (Realtime), true = Active Now, false = Offline
  bool _isDebugModeOverride = false;

  DebugProvider() {
    _loadPersistedState();
  }

  bool get forceOfflineMode => _forceOfflineMode;
  bool? get simulatedPartnerOnlineStatus => _simulatedPartnerOnlineStatus;
  bool get isDebugModeOverride => _isDebugModeOverride;

  /// Returns true if app is in Flutter debug mode OR if the Admin debug mode override is active in release mode
  bool get isDebugMode => kDebugMode || _isDebugModeOverride;

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDebugModeOverride = prefs.getBool(_keyDebugMode) ?? false;
      _forceOfflineMode = prefs.getBool(_keyForceOffline) ?? false;
      isOfflineForced = _forceOfflineMode;
      _offlineModeStreamController.add(_forceOfflineMode);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleDebugModeOverride() async {
    _isDebugModeOverride = !_isDebugModeOverride;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDebugMode, _isDebugModeOverride);
    } catch (_) {}
  }

  Future<void> setDebugModeOverride(bool enabled) async {
    if (_isDebugModeOverride == enabled) return;
    _isDebugModeOverride = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDebugMode, _isDebugModeOverride);
    } catch (_) {}
  }

  void toggleOfflineMode() {
    setOfflineMode(!_forceOfflineMode);
  }

  void setOfflineMode(bool offline) {
    if (_forceOfflineMode == offline) return;
    _forceOfflineMode = offline;
    isOfflineForced = offline;
    _offlineModeStreamController.add(offline);
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_keyForceOffline, offline);
    }).catchError((_) {});
  }

  void setSimulatedPartnerOnline(bool? status) {
    _simulatedPartnerOnlineStatus = status;
    notifyListeners();
  }

  void toggleSimulatedPartnerOnline() {
    if (_simulatedPartnerOnlineStatus == null) {
      _simulatedPartnerOnlineStatus = true;
    } else if (_simulatedPartnerOnlineStatus == true) {
      _simulatedPartnerOnlineStatus = false;
    } else {
      _simulatedPartnerOnlineStatus = null;
    }
    notifyListeners();
  }

  void reset() {
    _forceOfflineMode = false;
    isOfflineForced = false;
    _offlineModeStreamController.add(false);
    _simulatedPartnerOnlineStatus = null;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_keyForceOffline);
    }).catchError((_) {});
  }
}
