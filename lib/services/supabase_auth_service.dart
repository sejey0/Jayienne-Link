import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Authentication service using Supabase Auth
/// Provides compatible interface with the original Firebase auth service
class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((data) => data.session?.user);

  /// Current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Current user ID (compatible with existing code expecting Firebase UID)
  String? get currentUserId => currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      debugPrint('🔐 Attempting Supabase signup with email: $email');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Supabase signup successful for: ${response.user!.email}');
      } else {
        debugPrint('⚠️ Supabase signup completed but no user object returned');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Supabase signup failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      debugPrint('🔐 Attempting Supabase signin with email: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Supabase signin successful for: ${response.user!.email}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Supabase signin failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // In Supabase, email verification is sent automatically on signup
      // This method can be used to resend verification
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user.email!,
      );

      debugPrint('✅ Email verification sent to: ${user.email}');
    } catch (e) {
      debugPrint('❌ Failed to send email verification: $e');
      throw _handleAuthError(e);
    }
  }

  /// Check if current user's email is verified
  bool checkEmailVerified() {
    final user = currentUser;
    if (user == null) return false;

    // In Supabase, emailConfirmedAt indicates email verification
    return user.emailConfirmedAt != null;
  }

  /// Verify phone number with OTP
  /// Note: This is a simplified interface compared to Firebase's complex phone auth flow
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(User user) onSuccess,
    required void Function(String error) onError,
  }) async {
    try {
      debugPrint('📱 Sending OTP to phone: $phoneNumber');

      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
      );

      debugPrint('✅ OTP sent successfully to: $phoneNumber');
      // Note: The actual verification happens in verifyOtp method
    } catch (e) {
      debugPrint('❌ Failed to send OTP: $e');
      onError(_handleAuthError(e).toString());
    }
  }

  /// Verify OTP for phone authentication
  Future<AuthResponse> verifyOtp(String phone, String otp) async {
    try {
      debugPrint('📱 Verifying OTP for phone: $phone');

      final response = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: otp,
      );

      if (response.user != null) {
        debugPrint('✅ Phone verification successful');
      }

      return response;
    } catch (e) {
      debugPrint('❌ OTP verification failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('🔓 Sending password reset email to: $email');

      await _supabase.auth.resetPasswordForEmail(email);

      debugPrint('✅ Password reset email sent successfully');
    } catch (e) {
      debugPrint('❌ Failed to send password reset email: $e');
      throw _handleAuthError(e);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Signing out current user');

      await _supabase.auth.signOut();

      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Update user profile (display name, etc.)
  Future<UserResponse> updateProfile({
    String? displayName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('👤 Updating user profile');

      final updates = <String, dynamic>{};

      if (displayName != null) {
        updates['display_name'] = displayName;
      }

      if (metadata != null) {
        updates.addAll(metadata);
      }

      final response = await _supabase.auth.updateUser(
        UserAttributes(data: updates),
      );

      debugPrint('✅ Profile updated successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Profile update failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      debugPrint('🔐 Updating user password');

      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      debugPrint('✅ Password updated successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Password update failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Update user email
  Future<UserResponse> updateEmail(String newEmail) async {
    try {
      debugPrint('📧 Updating user email to: $newEmail');

      final response = await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      debugPrint('✅ Email update initiated (verification required)');
      return response;
    } catch (e) {
      debugPrint('❌ Email update failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      debugPrint('🗑️ Deleting user account');

      // Note: Supabase doesn't have built-in user deletion from client
      // This would typically be handled by a server-side function
      // For now, we'll sign out and let server-side cleanup handle it
      await signOut();

      debugPrint(
          '✅ User signed out (account deletion requires server-side handling)');
    } catch (e) {
      debugPrint('❌ Account deletion failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Get user metadata
  Map<String, dynamic>? getUserMetadata() {
    return currentUser?.userMetadata;
  }

  /// Get app metadata
  Map<String, dynamic>? getAppMetadata() {
    return currentUser?.appMetadata;
  }

  /// Refresh current session
  Future<AuthResponse> refreshSession() async {
    try {
      debugPrint('🔄 Refreshing user session');

      final response = await _supabase.auth.refreshSession();

      debugPrint('✅ Session refreshed successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Session refresh failed: $e');
      throw _handleAuthError(e);
    }
  }

  /// Check if current session is valid
  bool isSessionValid() {
    final session = currentSession;
    if (session == null) return false;

    // Check if session is expired
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return session.expiresAt != null && session.expiresAt! > now;
  }

  /// Handle Supabase auth errors and convert to user-friendly messages
  Exception _handleAuthError(dynamic error) {
    debugPrint('Supabase Auth Error: $error');

    if (error is AuthException) {
      switch (error.message.toLowerCase()) {
        case 'invalid login credentials':
        case 'invalid_credentials':
          return Exception(
              'Invalid email or password. Please check your credentials.');

        case 'user not found':
        case 'user_not_found':
          return Exception('No account found with this email address.');

        case 'email not confirmed':
        case 'email_not_confirmed':
          return Exception(
              'Please verify your email address before signing in.');

        case 'too many requests':
        case 'rate_limit_exceeded':
          return Exception('Too many attempts. Please try again later.');

        case 'weak password':
        case 'password_too_weak':
          return Exception(
              'Password is too weak. Please choose a stronger password.');

        case 'email already registered':
        case 'user_already_registered':
          return Exception('An account with this email already exists.');

        case 'invalid email':
        case 'invalid_email':
          return Exception('Please enter a valid email address.');

        case 'network error':
        case 'network_request_failed':
          return Exception(
              'Network error. Please check your internet connection.');

        default:
          return Exception('Authentication error: ${error.message}');
      }
    }

    if (error is Exception) {
      return error;
    }

    return Exception('An unexpected error occurred: ${error.toString()}');
  }

  /// Initialize auth service and handle any setup
  Future<bool> initialize() async {
    try {
      debugPrint('🔄 Initializing Supabase Auth Service...');

      // Check if there's a saved session
      if (currentSession != null) {
        debugPrint('✅ Found existing session for: ${currentUser?.email}');
      } else {
        debugPrint('ℹ️ No existing session found');
      }

      debugPrint('✅ Supabase Auth Service initialized');
      return true;
    } catch (e) {
      debugPrint('❌ Auth service initialization failed: $e');
      return false;
    }
  }
}
