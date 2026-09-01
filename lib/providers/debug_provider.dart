import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug provider for testing offline mode, developer tools, and partner status simulation
class DebugProvider extends ChangeNotifier {
  static const String _keyDebugMode = 'admin_debug_mode_override';

  bool _forceOfflineMode = false;
  bool? _simulatedPartnerOnlineStatus; // null = Auto (Realtime), true = Active Now, false = Offline
  bool _isDebugModeOverride = false;

  DebugProvider() {
    _loadDebugOverride();
  }

  bool get forceOfflineMode => _forceOfflineMode;
  bool? get simulatedPartnerOnlineStatus => _simulatedPartnerOnlineStatus;
  bool get isDebugModeOverride => _isDebugModeOverride;

  /// Returns true if app is in Flutter debug mode OR if the Admin debug mode override is active in release mode
  bool get isDebugMode => kDebugMode || _isDebugModeOverride;

  Future<void> _loadDebugOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDebugModeOverride = prefs.getBool(_keyDebugMode) ?? false;
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
    _forceOfflineMode = !_forceOfflineMode;
    notifyListeners();
  }

  void setOfflineMode(bool offline) {
    _forceOfflineMode = offline;
    notifyListeners();
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
    _simulatedPartnerOnlineStatus = null;
    notifyListeners();
  }
}
