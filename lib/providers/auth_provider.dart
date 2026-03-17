import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  User? _firebaseUser;
  bool _isLoading = false;
  String? _error;

  // Phone auth state
  String? _verificationId;
  // ignore: unused_field
  int? _resendToken; // needed for phone auth resend

  AuthProvider(this._authService) {
    _authService.authStateChanges.listen((user) {
      _firebaseUser = user;
      notifyListeners();
    });
  }

  bool get isAuthenticated => _firebaseUser != null;
  User? get firebaseUser => _firebaseUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get verificationId => _verificationId;
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;

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
      await _authService.sendEmailVerification();
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
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
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  Future<bool> checkEmailVerified() async {
    final verified = await _authService.checkEmailVerified();
    if (verified) {
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
      onAutoVerify: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _isLoading = false;
        notifyListeners();
      },
      onCodeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        _isLoading = false;
        notifyListeners();
      },
      onFailed: (e) {
        _error = _mapAuthError(e.code);
        _isLoading = false;
        notifyListeners();
      },
      onAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<bool> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _error = 'Verification session expired. Please resend the code.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyOtp(_verificationId!, otp);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
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
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid code. Please try again.';
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
