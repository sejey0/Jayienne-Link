import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/supabase_data_service.dart';

/// Supabase user service for PostgreSQL database operations
class SupabaseUserService {
  static const String _tableName = 'users';

  /// Get a user by their ID
  Future<UserModel?> getUser(String uid) async {
    try {
      final userData = await SupabaseDataService.getSingleRecord(
        _tableName,
        whereColumn: 'id',
        whereValue: uid,
      );

      if (userData == null) {
        debugPrint('User not found: $uid');
        return null;
      }

      return UserModel.fromJson(userData);
    } catch (e) {
      debugPrint('Failed to get user $uid: $e');
      return null;
    }
  }

  /// Get a real-time stream of user data
  Stream<UserModel?> userStream(String uid) {
    try {
      return SupabaseDataService.getSingleRecordStream(
        _tableName,
        whereColumn: 'id',
        whereValue: uid,
      ).map((userData) {
        if (userData != null) {
          debugPrint('User loaded: id=${userData['id']}');
          return UserModel.fromJson(userData);
        }
        return null;
      }).handleError((error) {
        debugPrint('User stream error for $uid: $error');
      });
    } catch (e) {
      debugPrint('Failed to create user stream for $uid: $e');
      return Stream.error(e);
    }
  }

  /// Create a new user profile (or update if exists)
  Future<void> createUser(UserModel user) async {
    try {
      debugPrint('Creating user profile for: ${user.email}');

      // First check if user already exists by email
      final existing = await SupabaseDataService.getSingleRecord(
        _tableName,
        whereColumn: 'email',
        whereValue: user.email,
      );

      if (existing != null) {
        // User already exists, update instead (don't include id to avoid FK conflicts)
        debugPrint('User already exists, updating profile: ${user.email}');
        final updateData = user.toUpdateJson();
        await SupabaseDataService.updateRecords(
          _tableName,
          updateData,
          whereColumn: 'id',
          whereValue: existing['id'],
        );
        return;
      }

      final payload = user.toInsertJson();
      await SupabaseDataService.insertRecord(_tableName, payload);

      debugPrint('✅ User profile created successfully: ${user.email}');
    } catch (e) {
      debugPrint('❌ Failed to create user: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Update user profile data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      debugPrint('Updating user profile: $uid');

      // Convert camelCase field names to snake_case for PostgreSQL
      final pgData = _convertFieldNames(data);

      // Add updated timestamp
      pgData['updated_at'] = DateTime.now().toIso8601String();

      await SupabaseDataService.updateRecords(
        _tableName,
        pgData,
        whereColumn: 'id',
        whereValue: uid,
      );

      debugPrint('✅ User profile updated successfully: $uid');
    } catch (e) {
      debugPrint('❌ Failed to update user $uid: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Delete a user profile
  Future<void> deleteUser(String uid) async {
    try {
      debugPrint('Deleting user profile: $uid');

      await SupabaseDataService.deleteRecords(
        _tableName,
        whereColumn: 'id',
        whereValue: uid,
      );

      debugPrint('✅ User profile deleted successfully: $uid');
    } catch (e) {
      debugPrint('❌ Failed to delete user $uid: $e');
      throw Exception('Failed to delete user profile: $e');
    }
  }

  /// Get users by couple ID
  Future<List<UserModel>> getUsersByCoupleId(String coupleId) async {
    try {
      final usersData = await SupabaseDataService.getRecords(
        _tableName,
        whereColumn: 'couple_id',
        whereValue: coupleId,
        orderBy: 'display_name',
      );

      return usersData.map((data) => UserModel.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Failed to get users by couple ID $coupleId: $e');
      return [];
    }
  }

  /// Search users by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final userData = await SupabaseDataService.getSingleRecord(
        _tableName,
        whereColumn: 'email',
        whereValue: email.toLowerCase(),
      );

      return userData != null ? UserModel.fromJson(userData) : null;
    } catch (e) {
      debugPrint('Failed to get user by email $email: $e');
      return null;
    }
  }

  /// Get users with pending invite codes
  Future<List<UserModel>> getUsersWithInviteCodes() async {
    try {
      final usersData = await SupabaseDataService.getRecords(
        _tableName,
        orderBy: 'created_at',
        ascending: false,
      );

      return usersData
          .map((data) => UserModel.fromJson(data))
          .where(
              (user) => user.inviteCode != null && user.inviteCode!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Failed to get users with invite codes: $e');
      return [];
    }
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final stats = <String, dynamic>{};

      final totalUsers = await SupabaseDataService.getRecords(_tableName);
      stats['total_users'] = totalUsers.length;

      final completeProfiles = totalUsers
          .map((data) => UserModel.fromJson(data))
          .where((user) => user.profileComplete)
          .length;
      stats['complete_profiles'] = completeProfiles;

      final usersInCouples = totalUsers
          .map((data) => UserModel.fromJson(data))
          .where((user) => user.hasRealPartner)
          .length;
      stats['users_in_couples'] = usersInCouples;

      final usersWithPhotos = totalUsers
          .map((data) => UserModel.fromJson(data))
          .where((user) => user.photoUrl != null && user.photoUrl!.isNotEmpty)
          .length;
      stats['users_with_photos'] = usersWithPhotos;

      return stats;
    } catch (e) {
      debugPrint('Failed to get user stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Convert camelCase field names to snake_case for PostgreSQL
  Map<String, dynamic> _convertFieldNames(Map<String, dynamic> data) {
    final pgData = <String, dynamic>{};

    for (final entry in data.entries) {
      switch (entry.key) {
        case 'phoneNumber':
          pgData['phone_number'] = entry.value;
          break;
        case 'displayName':
          pgData['display_name'] = entry.value;
          break;
        case 'photoUrl':
          pgData['photo_url'] = entry.value;
          break;
        case 'coupleId':
          pgData['couple_id'] = entry.value;
          break;
        case 'inviteCode':
          pgData['invite_code'] = entry.value;
          break;
        case 'profileComplete':
          pgData['profile_complete'] = entry.value;
          break;
        case 'createdAt':
          pgData['created_at'] = entry.value is DateTime
              ? (entry.value as DateTime).toIso8601String()
              : entry.value;
          break;
        case 'updatedAt':
          pgData['updated_at'] = entry.value is DateTime
              ? (entry.value as DateTime).toIso8601String()
              : entry.value;
          break;
        default:
          pgData[entry.key] = entry.value;
      }
    }

    return pgData;
  }

  /// Test database connectivity
  Future<bool> testConnectivity() async {
    try {
      await SupabaseDataService.testConnectivity();
      return true;
    } catch (e) {
      debugPrint('User service connectivity test failed: $e');
      return false;
    }
  }
}
