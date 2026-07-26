import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/supabase_user_service.dart';
import '../services/supabase_storage_service.dart';
import '../services/supabase_couple_service.dart';
import '../services/local_cache_service.dart';

class UserProvider extends ChangeNotifier {
  final SupabaseUserService _userService;
  final SupabaseStorageService _storageService;
  final SupabaseCoupleService _coupleService;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _userSubscription;

  UserProvider(this._userService, this._storageService, this._coupleService);

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isProfileComplete => _user?.profileComplete ?? false;
  String? get coupleId => _user?.coupleId;

  void loadUser(String uid) {
    _userSubscription?.cancel();
    LocalCacheService.loadUser().then((cached) {
      if (cached != null && cached.id == uid) {
        _user = cached;
        notifyListeners();
      }
    });
    _userSubscription = _userService.userStream(uid).listen((user) {
      if (user != null) {
        _user = user;
        LocalCacheService.saveUser(user);
        // ignore: curly_braces_in_flow_control_structures
      } else {
        _user ??= null;
      }
      notifyListeners();
    });
  }

  void loadUserByEmail(String email) {
    _userSubscription?.cancel();
    final normalizedEmail = email.trim().toLowerCase();
    LocalCacheService.loadUser().then((cached) {
      if (cached != null && cached.email.toLowerCase() == normalizedEmail) {
        _user = cached;
        notifyListeners();
      }
    });
    // First try to get user by email, then start stream with correct ID
    _userService.getUserByEmail(normalizedEmail).then((user) {
      if (user != null) {
        debugPrint('✅ User found by email, loading stream for ID: ${user.id}');
        _user = user;
        LocalCacheService.saveUser(user);
        notifyListeners();
        // Now start the stream with the correct database ID
        _userSubscription =
            _userService.userStream(user.id).listen((updatedUser) {
          if (updatedUser != null) {
            _user = updatedUser;
            LocalCacheService.saveUser(updatedUser);
          }
          notifyListeners();
        });
      } else {
        debugPrint(
            '⚠️ User not found for email: $email. Awaiting profile setup.');
        if (_user == null || _user?.email.toLowerCase() != normalizedEmail) {
          _user = null;
          notifyListeners();
        }
      }
    }).catchError((error) {
      debugPrint('❌ Error loading user by email: $error');
      if (_user == null || _user?.email.toLowerCase() != normalizedEmail) {
        _user = null;
        notifyListeners();
      }
    });
  }

  void clearUser() {
    _userSubscription?.cancel();
    _user = null;
    LocalCacheService.clearUser();
    notifyListeners();
  }

  Future<bool> createProfile({
    required String uid,
    required String email,
    String? phoneNumber,
    required String displayName,
    File? photoFile,
    DateTime? birthday,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? photoUrl;
      if (photoFile != null) {
        debugPrint('Uploading profile photo for $uid...');

        // Test storage connectivity first
        final storageTest = await _storageService.testConnectivity();
        if (!storageTest) {
          throw Exception(
              'Cannot connect to storage service. Please check your internet connection.');
        }

        photoUrl = await _storageService.uploadProfilePhoto(uid, photoFile);
        debugPrint('Photo uploaded successfully: $photoUrl');

        // Check if using Base64 fallback and inform user
        if (photoUrl.startsWith('data:image/')) {
          debugPrint('Using Base64 storage fallback');
        }
      }

      final now = DateTime.now();
      final user = UserModel(
        id: uid,
        email: email,
        phoneNumber: phoneNumber,
        displayName: displayName,
        photoUrl: photoUrl,
        birthday: birthday,
        profileComplete: true,
        createdAt: now,
        updatedAt: now,
      );

      await _userService.createUser(user);

      // After creating/updating, reload user from database by email to get correct UUID
      final dbUser = await _userService.getUserByEmail(email);
      if (dbUser != null) {
        _user = dbUser;
      } else {
        _user = user;
      }
      if (_user != null) {
        await LocalCacheService.saveUser(_user!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('Profile creation error: $e');
      debugPrint('Stack trace: $stackTrace');

      // Provide user-friendly error messages
      if (e.toString().contains('Storage')) {
        _error =
            'Failed to upload profile photo. Please check your internet connection and try again.';
      } else if (e.toString().contains('unauthorized')) {
        _error = 'Not authorized to upload images. Please contact support.';
      } else if (e.toString().contains('canceled')) {
        _error = 'Upload was canceled. Please try again.';
      } else {
        _error = 'Failed to create profile. Please try again.';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String uid,
    String? displayName,
    File? photoFile,
    DateTime? birthday,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};

      if (displayName != null) updates['displayName'] = displayName;
      if (birthday != null) {
        updates['birthday'] = birthday;
      }

      if (photoFile != null) {
        debugPrint('Updating profile photo for $uid...');

        // Test storage connectivity first
        final storageTest = await _storageService.testConnectivity();
        if (!storageTest) {
          throw Exception(
              'Cannot connect to storage service. Please check your internet connection.');
        }

        final photoUrl =
            await _storageService.uploadProfilePhoto(uid, photoFile);
        updates['photoUrl'] = photoUrl;
        debugPrint('Photo updated successfully: $photoUrl');

        // Check if using Base64 fallback and inform user
        if (photoUrl.startsWith('data:image/')) {
          debugPrint('Using Base64 storage fallback');
        }
      }

      if (updates.isNotEmpty) {
        await _userService.updateUser(uid, updates);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Profile update error: $e');

      // Provide user-friendly error messages
      if (e.toString().contains('Storage')) {
        _error =
            'Failed to upload profile photo. Please check your internet connection and try again.';
      } else if (e.toString().contains('unauthorized')) {
        _error = 'Not authorized to upload images. Please contact support.';
      } else if (e.toString().contains('canceled')) {
        _error = 'Upload was canceled. Please try again.';
      } else {
        _error = 'Failed to update profile. Please try again.';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBubbleTheme(String themeKey) async {
    final currentUser = _user;
    if (currentUser == null) return false;

    _user = currentUser.copyWith(bubbleTheme: themeKey);
    notifyListeners();
    await LocalCacheService.saveUser(_user!);

    try {
      await _userService.updateUser(currentUser.id, {
        'bubbleTheme': themeKey,
      });
      return true;
    } catch (e) {
      _user = currentUser;
      notifyListeners();
      await LocalCacheService.saveUser(currentUser);
      debugPrint('Bubble theme update error: $e');
      return false;
    }
  }

  /// Skip couple linking for now
  Future<bool> skipCoupleLink(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      // couple_id is UUID in PostgreSQL; use invite_code flag for "skipped" state.
      await _userService.updateUser(uid, {'inviteCode': 'SKIPPED'});

      // Update local user object immediately so router can see the change
      if (_user != null) {
        _user = _user!.copyWith(inviteCode: 'SKIPPED');
        debugPrint('✅ Local user updated with SKIPPED flag');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to skip. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear skipped status to allow linking
  Future<bool> clearSkippedStatus(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear skipped marker and keep couple_id null until linking
      await _userService
          .updateUser(uid, {'inviteCode': null, 'coupleId': null});

      // Reset any invite codes this user generated back to unused status
      await _coupleService.resetInviteCodes(uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _userSubscription?.cancel();
    super.dispose();
  }
}
