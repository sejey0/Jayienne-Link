import 'package:flutter/foundation.dart';

/// Debug provider for testing offline mode and other debugging features
class DebugProvider extends ChangeNotifier {
  bool _forceOfflineMode = false;

  bool get forceOfflineMode => _forceOfflineMode;

  void toggleOfflineMode() {
    _forceOfflineMode = !_forceOfflineMode;
    notifyListeners();
  }

  void setOfflineMode(bool offline) {
    _forceOfflineMode = offline;
    notifyListeners();
  }

  void reset() {
    _forceOfflineMode = false;
    notifyListeners();
  }
}
