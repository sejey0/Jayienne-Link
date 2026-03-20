import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../services/supabase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseAuthService _authService;

  User? _currentUser;
  String? _pendingVerificationEmail;
  bool _isLoading = false;
  String? _error;

  // Phone auth state
  String? _verificationId;
  // ignore: unused_field
  int? _resendToken; // needed for phone auth resend

  AuthProvider(this._authService) {
    _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;
  String? get verificationEmail => _currentUser?.email ?? _pendingVerificationEmail;
  String? get currentUserId => _currentUser?.id;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get verificationId => _verificationId;
  bool get isEmailVerified => _authService.checkEmailVerified();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signUpWithEmail(email, password);
      _pendingVerificationEmail = email;
      await _authService.sendEmailVerification(email: email);
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
    notifyListeners();

    try {
      await _authService.signInWithEmail(email, password);
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
      await _authService.verifyOtp(phoneNumber, otp);
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

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
