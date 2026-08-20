import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/couple_model.dart';
import '../models/user_model.dart';

class LocalCacheService {
  static const String _userKey = 'cache_user';
  static const String _partnerKey = 'cache_partner';
  static const String _coupleKey = 'cache_couple';
  static const String _firstLaunchKey = 'is_first_launch';

  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<UserModel?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  static Future<void> savePartner(UserModel partner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_partnerKey, jsonEncode(partner.toJson()));
  }

  static Future<UserModel?> loadPartner() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_partnerKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPartner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_partnerKey);
  }

  static Future<void> saveCouple(CoupleModel couple) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coupleKey, jsonEncode(couple.toJson()));
  }

  static Future<CoupleModel?> loadCouple() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_coupleKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CoupleModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCouple() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_coupleKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_partnerKey);
    await prefs.remove(_coupleKey);
  }

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    // Returns true if the key doesn't exist (first launch)
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  static Future<void> markFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  static const String _sharingEnabledKey = 'location_sharing_enabled';

  /// Load persisted sharing state (defaults to true so tracking stays active)
  static Future<bool> loadSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sharingEnabledKey) ?? true;
  }

  /// Save persisted sharing state
  static Future<void> saveSharingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharingEnabledKey, enabled);
  }
}
