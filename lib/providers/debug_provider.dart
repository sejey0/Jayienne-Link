import 'package:flutter/foundation.dart';

/// Debug provider for testing offline mode and other debugging features
class DebugProvider extends ChangeNotifier {
  bool _forceOfflineMode = false;
  bool? _simulatedPartnerOnlineStatus; // null = Auto (Realtime), true = Active Now, false = Offline

  bool get forceOfflineMode => _forceOfflineMode;
  bool? get simulatedPartnerOnlineStatus => _simulatedPartnerOnlineStatus;

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
