import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_data_service.dart';
import '../services/local_cache_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseAuthService _authService;

  User? _currentUser;
  String? _pendingVerificationEmail;
  bool _isLoading = false;
  String? _error;
  bool _needsProfileSetup = false;
  bool _isPasswordRecovery = false;

  // Phone auth state
  String? _verificationId;
  // ignore: unused_field
  int? _resendToken; // needed for phone auth resend
  String? _pendingPhoneNumber;

  AuthProvider(this._authService) {
    _currentUser = _authService.currentUser;
    _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        notifyListeners();
      }
    });
  }

  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;
  String? get verificationEmail =>
      _currentUser?.email ?? _pendingVerificationEmail;
  String? get currentUserId => _currentUser?.id;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get needsProfileSetup => _needsProfileSetup;
  bool get isPasswordRecovery => _isPasswordRecovery;
  String? get verificationId => _verificationId;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  bool get isEmailVerified => _authService.checkEmailVerified();

  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearNeedsProfileSetup() {
    _needsProfileSetup = false;
    notifyListeners();
  }

  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _error = null;
    _needsProfileSetup = false;
    notifyListeners();

    try {
      await _authService.signUpWithEmail(email, password);
      _pendingVerificationEmail = email;
      // Note: Supabase automatically sends verification email on signup
      // when email confirmation is enabled in the dashboard
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    _needsProfileSetup = false;
    notifyListeners();

    try {
      await _authService.signInWithEmail(email, password);
      final profile = await SupabaseDataService.getSingleRecord(
        'users',
        whereColumn: 'email',
        whereValue: email.trim().toLowerCase(),
      );

      if (profile == null) {
        _needsProfileSetup = true;
        _error = 'Please complete your profile to finish registration.';
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _pendingVerificationEmail = email;
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendEmailVerification() async {
    final email = _currentUser?.email ?? _pendingVerificationEmail;
    if (email == null || email.isEmpty) {
      throw Exception('No email available for verification');
    }
    await _authService.sendEmailVerification(email: email);
  }

  Future<bool> checkEmailVerified() async {
    final verified = _authService.checkEmailVerified();
    if (verified) {
      _pendingVerificationEmail = null;
      notifyListeners();
    }
    return verified;
  }

  Future<void> verifyPhone(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    _pendingPhoneNumber = phoneNumber;
    notifyListeners();

    await _authService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onSuccess: (user) {
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _error = error;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> verifyOtp(String otp, String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final effectivePhone =
          phoneNumber.isNotEmpty ? phoneNumber : _pendingPhoneNumber;

      if (effectivePhone == null || effectivePhone.isEmpty) {
        _error = 'Phone number missing for verification.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _authService.verifyOtp(effectivePhone, otp);
      _pendingPhoneNumber = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyPasswordResetOtp(email: email, token: token);
      _isLoading = false;
      notifyListeners();

      Future.microtask(() {
        _isPasswordRecovery = true;
        notifyListeners();
      });
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.updatePassword(newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> directChangePassword({
    required String email,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (isAuthenticated) {
        await _authService.updatePassword(newPassword);
      } else {
        await _authService.sendPasswordResetEmail(email);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _pendingVerificationEmail = null;
    _verificationId = null;
    _pendingPhoneNumber = null;
    _error = null;
    await LocalCacheService.clearAll();
    await _authService.signOut();
    notifyListeners();
  }
}
