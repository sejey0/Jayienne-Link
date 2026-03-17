import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService;
  final StorageService _storageService;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _userSubscription;

  UserProvider(this._userService, this._storageService);

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isProfileComplete => _user?.profileComplete ?? false;
  String? get coupleId => _user?.coupleId;

  void loadUser(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _userService.userStream(uid).listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  void clearUser() {
    _userSubscription?.cancel();
    _user = null;
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
        photoUrl = await _storageService.uploadProfilePhoto(uid, photoFile);
      }

      final now = DateTime.now();
      final user = UserModel(
        uid: uid,
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
      _user = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create profile. Please try again.';
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
        updates['birthday'] = Timestamp.fromDate(birthday);
      }

      if (photoFile != null) {
        final photoUrl =
            await _storageService.uploadProfilePhoto(uid, photoFile);
        updates['photoUrl'] = photoUrl;
      }

      if (updates.isNotEmpty) {
        await _userService.updateUser(uid, updates);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
