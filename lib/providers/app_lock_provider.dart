import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLockProvider extends ChangeNotifier {
  static const String _enabledKey = 'app_lock_enabled';
  static const String _pinKey = 'app_lock_pin';

  bool _isLoaded = false;
  bool _isEnabled = false;
  String? _pin;
  String? _unlockedSessionToken;
  String? _error;

  bool get isLoaded => _isLoaded;
  bool get isEnabled => _isEnabled && hasPin;
  bool get hasPin => _pin != null && _pin!.isNotEmpty;
  String? get error => _error;

  bool get requiresUnlock => isEnabled && !isUnlockedForCurrentSession;

  bool get isUnlockedForCurrentSession {
    final currentToken = _currentSessionToken();
    return currentToken != null && _unlockedSessionToken == currentToken;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    _pin = prefs.getString(_pinKey);
    _isLoaded = true;
    notifyListeners();
  }

  Future<bool> setPin(String pin, {bool notify = true}) async {
    final normalizedPin = pin.trim();
    if (!_isValidPassword(normalizedPin)) {
      _error = 'Password cannot be empty.';
      notifyListeners();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_pinKey, normalizedPin);

    _pin = normalizedPin;
    _isEnabled = true;
    _unlockCurrentSession();
    _error = null;
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  Future<bool> changePin(String currentPin, String newPin,
      {bool notify = true}) async {
    if (!_matchesPin(currentPin)) {
      _error = 'Current password is incorrect.';
      notifyListeners();
      return false;
    }

    return setPin(newPin, notify: notify);
  }

  Future<bool> disablePin(String currentPin, {bool notify = true}) async {
    if (!_matchesPin(currentPin)) {
      _error = 'Current password is incorrect.';
      notifyListeners();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_pinKey);

    _pin = null;
    _isEnabled = false;
    _unlockedSessionToken = null;
    _error = null;
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  Future<bool> unlockWithPin(String pin) async {
    if (!isEnabled) {
      _error = 'App lock is not enabled.';
      notifyListeners();
      return false;
    }

    if (!_matchesPin(pin)) {
      _error = 'Incorrect password.';
      notifyListeners();
      return false;
    }

    _unlockCurrentSession();
    _error = null;
    notifyListeners();
    return true;
  }

  void lockSession() {
    _unlockedSessionToken = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String? _currentSessionToken() {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  void _unlockCurrentSession() {
    _unlockedSessionToken = _currentSessionToken();
  }

  bool _matchesPin(String pin) {
    final normalizedPin = pin.trim();
    return _isValidPassword(normalizedPin) && normalizedPin == _pin;
  }

  bool _isValidPassword(String password) {
    return password.isNotEmpty;
  }
}
