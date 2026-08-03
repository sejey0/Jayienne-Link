import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/vault_cache_manager.dart';

/// Hardened App Lock Provider supporting Flexible Alphanumeric Passcodes (Minimum 8 Characters),
/// SHA-256 + Salt Encryption, Lifecycle Observer, Biometrics, and Brute-Force Lockout Protection.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _pinHashKey = 'secure_app_lock_pin_hash';
  static const String _saltKey = 'secure_app_lock_salt';
  static const String _enabledKey = 'secure_app_lock_enabled';
  static const String _biometricEnabledKey = 'secure_biometric_enabled';

  static const int maxFailedAttempts = 5;
  static const int minPasscodeLength = 8;
  static const Duration lockoutDuration = Duration(seconds: 30);

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoaded = false;
  bool _isEnabled = false;
  bool _isLocked = true;
  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;

  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  String? _unlockedSessionToken;
  String? _error;
  Timer? _lockoutTimer;

  // Getters
  bool get isLoaded => _isLoaded;
  bool get isEnabled => _isEnabled && _hasPin;
  bool get isLocked => _isLocked;
  bool get hasPin => _hasPin;
  bool get hasPasscode => _hasPin;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isBiometricAvailable => _isBiometricAvailable;
  int get failedAttempts => _failedAttempts;
  String? get error => _error;

  /// Returns true if passcode meets minimum length requirement (8+ chars)
  bool validatePasscode(String value) {
    return value.trim().length >= minPasscodeLength;
  }

  /// Returns true if currently locked out due to brute-force protection
  bool get isLockedOut {
    if (_lockoutEndTime == null) return false;
    if (DateTime.now().isAfter(_lockoutEndTime!)) {
      _lockoutEndTime = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  /// Remaining lockout time in seconds
  int get remainingLockoutSeconds {
    if (_lockoutEndTime == null) return 0;
    final remaining = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Indicates if session requires unlock overlay
  bool get requiresUnlock => isEnabled && (!isUnlockedForCurrentSession || _isLocked);

  bool get isUnlockedForCurrentSession {
    final currentToken = _currentSessionToken();
    return currentToken != null && _unlockedSessionToken == currentToken && !_isLocked;
  }

  AppLockProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Initialize and load security configurations
  Future<void> load() async {
    try {
      final enabledStr = await _secureStorage.read(key: _enabledKey);
      final pinHash = await _secureStorage.read(key: _pinHashKey);
      final bioEnabledStr = await _secureStorage.read(key: _biometricEnabledKey);

      _isEnabled = enabledStr == 'true';
      _hasPin = pinHash != null && pinHash.isNotEmpty;
      _isBiometricEnabled = bioEnabledStr == 'true';

      await checkBiometricAvailability();

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppLockProvider] Error loading security state: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Check hardware biometric capabilities (Fingerprint / Face ID)
  Future<void> checkBiometricAvailability() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      _isBiometricAvailable = false;
      notifyListeners();
      return;
    }
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      _isBiometricAvailable = canCheck && isSupported;
    } on MissingPluginException {
      _isBiometricAvailable = false;
    } catch (e) {
      debugPrint('[AppLockProvider] Error checking biometrics: $e');
      _isBiometricAvailable = false;
    }
    notifyListeners();
  }

  /// Hash Passcode using SHA-256 with local salt
  Future<String> _hashPin(String passcode, String salt) async {
    final bytes = utf8.encode('$passcode:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get or create local cryptographic salt
  Future<String> _getOrCreateSalt() async {
    var salt = await _secureStorage.read(key: _saltKey);
    if (salt == null || salt.isEmpty) {
      salt = DateTime.now().microsecondsSinceEpoch.toString();
      await _secureStorage.write(key: _saltKey, value: salt);
    }
    return salt;
  }

  /// Set new security Passcode (Encrypted via SHA-256 + Salt in FlutterSecureStorage)
  Future<bool> setPin(String passcode, {bool notify = true}) async {
    final normalizedPasscode = passcode.trim();
    if (!validatePasscode(normalizedPasscode)) {
      _error = 'Passcode must be at least $minPasscodeLength characters long.';
      if (notify) notifyListeners();
      return false;
    }

    try {
      final salt = await _getOrCreateSalt();
      final hashedPin = await _hashPin(normalizedPasscode, salt);

      await _secureStorage.write(key: _pinHashKey, value: hashedPin);
      await _secureStorage.write(key: _enabledKey, value: 'true');

      _hasPin = true;
      _isEnabled = true;
      _isLocked = false;
      _unlockCurrentSession();
      _error = null;

      if (notify) notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save security passcode.';
      if (notify) notifyListeners();
      return false;
    }
  }

  /// Alias for setPin
  Future<bool> setPasscode(String passcode, {bool notify = true}) =>
      setPin(passcode, notify: notify);

  /// Change existing Passcode
  Future<bool> changePin(String currentPasscode, String newPasscode, {bool notify = true}) async {
    if (!await _verifyPin(currentPasscode)) {
      _error = 'Current passcode is incorrect.';
      if (notify) notifyListeners();
      return false;
    }
    return setPin(newPasscode, notify: notify);
  }

  /// Alias for changePin
  Future<bool> changePasscode(String currentPasscode, String newPasscode, {bool notify = true}) =>
      changePin(currentPasscode, newPasscode, notify: notify);

  /// Verify entered passcode against stored secure hash
  Future<bool> _verifyPin(String passcode) async {
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    final salt = await _secureStorage.read(key: _saltKey);
    if (storedHash == null || salt == null) return false;

    final inputHash = await _hashPin(passcode.trim(), salt);
    return inputHash == storedHash;
  }

  /// Unlock app using Passcode with brute-force protection
  Future<bool> unlockWithPin(String passcode) async {
    if (isLockedOut) {
      _error = 'Too many failed attempts. Try again in ${remainingLockoutSeconds}s.';
      notifyListeners();
      return false;
    }

    if (!isEnabled) {
      _error = 'App lock is disabled.';
      notifyListeners();
      return false;
    }

    final isValid = await _verifyPin(passcode);
    if (!isValid) {
      _failedAttempts++;
      if (_failedAttempts >= maxFailedAttempts) {
        _lockoutEndTime = DateTime.now().add(lockoutDuration);
        _startLockoutTimer();
        _error = 'Too many failed attempts. Locked out for 30 seconds.';
      } else {
        final remainingAttempts = maxFailedAttempts - _failedAttempts;
        _error = 'Incorrect passcode. $remainingAttempts attempts remaining.';
      }
      notifyListeners();
      return false;
    }

    // Success
    _failedAttempts = 0;
    _lockoutEndTime = null;
    _isLocked = false;
    _unlockCurrentSession();
    _error = null;
    notifyListeners();
    return true;
  }

  /// Alias for unlockWithPin
  Future<bool> unlockWithPasscode(String passcode) => unlockWithPin(passcode);

  /// Unlock using Biometrics (Fingerprint / Face ID)
  Future<bool> unlockWithBiometrics() async {
    if (isLockedOut) {
      _error = 'Too many failed attempts. Try again in ${remainingLockoutSeconds}s.';
      notifyListeners();
      return false;
    }

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS) ||
        !_isBiometricAvailable) {
      _error = 'Biometric authentication is not supported on this platform.';
      notifyListeners();
      return false;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock Jayienne Link',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        _failedAttempts = 0;
        _lockoutEndTime = null;
        _isLocked = false;
        _unlockCurrentSession();
        _error = null;
        notifyListeners();
        return true;
      }
    } on MissingPluginException {
      _error = 'Biometric authentication is not supported on this platform.';
    } catch (e) {
      debugPrint('[AppLockProvider] Biometric error: $e');
      _error = 'Biometric authentication failed.';
    }

    notifyListeners();
    return false;
  }

  /// Toggle Biometric Unlock Preference
  Future<void> setBiometricEnabled(bool enabled) async {
    _isBiometricEnabled = enabled;
    await _secureStorage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
    notifyListeners();
  }

  /// Disable Passcode lock completely
  Future<bool> disablePin(String currentPasscode, {bool notify = true}) async {
    if (!await _verifyPin(currentPasscode)) {
      _error = 'Current passcode is incorrect.';
      if (notify) notifyListeners();
      return false;
    }

    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _enabledKey);
    await _secureStorage.delete(key: _biometricEnabledKey);

    _hasPin = false;
    _isEnabled = false;
    _isLocked = false;
    _unlockedSessionToken = null;
    _error = null;
    if (notify) notifyListeners();
    return true;
  }

  /// Alias for disablePin
  Future<bool> disablePasscode(String currentPasscode, {bool notify = true}) =>
      disablePin(currentPasscode, notify: notify);

  /// Lock session and purge unencrypted vault cache
  void lockSession() {
    _isLocked = true;
    _unlockedSessionToken = null;

    // Purge unencrypted vault cache immediately
    VaultCacheManager.instance.purgeVaultCache();
    notifyListeners();
  }

  /// Lifecycle Observer: Detects when app goes into background/paused state
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      debugPrint('[AppLockProvider] App paused/detached -> Auto-locking vault & purging cache...');
      lockSession();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isLockedOut) {
        timer.cancel();
        _error = null;
      }
      notifyListeners();
    });
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockoutTimer?.cancel();
    super.dispose();
  }
}
