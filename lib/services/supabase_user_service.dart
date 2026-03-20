import 'package:flutter/foundation.dart';
import '../models/supabase_user_model.dart';
import '../services/supabase_data_service.dart';

/// Supabase-based user service providing the same interface as the original Firebase service
/// Handles all user profile CRUD operations using PostgreSQL
class SupabaseUserService {
  static const String _tableName = 'users';

  /// Get a user by their ID (supports both Supabase UUID and Firebase UID)
  Future<UserModel?> getUser(String uid) async {
    try {
      // Try to find by Supabase UUID first
      Map<String, dynamic>? userData =
          await SupabaseDataService.getSingleRecord(
        _tableName,
        whereColumn: 'id',
        whereValue: uid,
      );

      // If not found, try Firebase UID for migration compatibility
      userData ??= await SupabaseDataService.getSingleRecord(
        _tableName,
        whereColumn: 'firebase_uid',
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
      // First try to get by Supabase UUID
      return SupabaseDataService.getSingleRecordStream(
        _tableName,
        whereColumn: 'id',
        whereValue: uid,
      ).asyncMap((userData) async {
        // If not found by UUID, try Firebase UID
        if (userData == null) {
          userData = await SupabaseDataService.getSingleRecord(
            _tableName,
            whereColumn: 'firebase_uid',
            whereValue: uid,
          );
        }

        return userData != null ? UserModel.fromJson(userData) : null;
      }).handleError((error) {
        debugPrint('User stream error for $uid: $error');
      });
    } catch (e) {
      debugPrint('Failed to create user stream for $uid: $e');
      return Stream.error(e);
    }
  }

  /// Create a new user profile
  Future<void> createUser(UserModel user) async {
    try {
      debugPrint('Creating user profile for: ${user.email}');

      await SupabaseDataService.insertRecord(
        _tableName,
        user.toInsertJson(),
      );

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

      // Convert Firestore-style field names to PostgreSQL format if needed
      final pgData = _convertFieldNames(data);

      // Add updated timestamp
      pgData['updated_at'] = DateTime.now().toIso8601String();

      // Try to update by Supabase UUID first
      final results = await SupabaseDataService.updateRecords(
        _tableName,
        pgData,
        whereColumn: 'id',
        whereValue: uid,
      );

      // If no rows updated, try Firebase UID
      if (results.isEmpty) {
        await SupabaseDataService.updateRecords(
          _tableName,
          pgData,
          whereColumn: 'firebase_uid',
          whereValue: uid,
        );
      }

      debugPrint('✅ User profile updated successfully: $uid');
    } catch (e) {
      debugPrint('❌ Failed to update user $uid: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Delete a user profile (admin function)
  Future<void> deleteUser(String uid) async {
    try {
      debugPrint('Deleting user profile: $uid');

      // Try to delete by Supabase UUID first
      await SupabaseDataService.deleteRecords(
        _tableName,
        whereColumn: 'id',
        whereValue: uid,
      );

      // Also try by Firebase UID if it exists
      try {
        await SupabaseDataService.deleteRecords(
          _tableName,
          whereColumn: 'firebase_uid',
          whereValue: uid,
        );
      } catch (e) {
        // Ignore if not found by Firebase UID
      }

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

  /// Search users by email (for admin/debug purposes)
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

      // Filter users with invite codes
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

      // Get total user count
      final totalUsers = await SupabaseDataService.getRecords(_tableName);
      stats['total_users'] = totalUsers.length;

      // Count users with complete profiles
      final completeProfiles = totalUsers
          .map((data) => UserModel.fromJson(data))
          .where((user) => user.profileComplete)
          .length;
      stats['complete_profiles'] = completeProfiles;

      // Count users in couples
      final usersInCouples = totalUsers
          .map((data) => UserModel.fromJson(data))
          .where((user) => user.hasRealPartner)
          .length;
      stats['users_in_couples'] = usersInCouples;

      // Count users with photos
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

  /// Migrate user from Firebase to Supabase (keeping Firebase UID for compatibility)
  Future<UserModel> migrateFirebaseUser(
      String firebaseUid, Map<String, dynamic> firebaseData) async {
    try {
      debugPrint('Migrating Firebase user to Supabase: $firebaseUid');

      // Check if user already exists
      final existingUser = await getUserByFirebaseUid(firebaseUid);
      if (existingUser != null) {
        debugPrint('User already migrated: $firebaseUid');
        return existingUser;
      }

      // Convert Firebase data to Supabase format
      final userData = _convertFirebaseToSupabase(firebaseData, firebaseUid);

      // Create the user
      final newUserData =
          await SupabaseDataService.insertRecord(_tableName, userData);
      final migratedUser = UserModel.fromJson(newUserData);

      debugPrint(
          '✅ User migrated successfully: $firebaseUid -> ${migratedUser.id}');
      return migratedUser;
    } catch (e) {
      debugPrint('❌ Failed to migrate user $firebaseUid: $e');
      throw Exception('Failed to migrate user: $e');
    }
  }

  /// Get user by Firebase UID (for migration support)
  Future<UserModel?> getUserByFirebaseUid(String firebaseUid) async {
    try {
      final userData = await SupabaseDataService.getSingleRecord(
        _tableName,
        whereColumn: 'firebase_uid',
        whereValue: firebaseUid,
      );

      return userData != null ? UserModel.fromJson(userData) : null;
    } catch (e) {
      debugPrint('Failed to get user by Firebase UID $firebaseUid: $e');
      return null;
    }
  }

  /// Convert field names from Firestore format to PostgreSQL format
  Map<String, dynamic> _convertFieldNames(Map<String, dynamic> firestoreData) {
    final pgData = <String, dynamic>{};

    for (final entry in firestoreData.entries) {
      switch (entry.key) {
        case 'uid':
          pgData['firebase_uid'] = entry.value;
          break;
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

  /// Convert Firebase user data to Supabase format
  Map<String, dynamic> _convertFirebaseToSupabase(
      Map<String, dynamic> firebaseData, String firebaseUid) {
    return {
      'firebase_uid': firebaseUid,
      'email': firebaseData['email'] ?? '',
      'phone_number': firebaseData['phoneNumber'],
      'display_name': firebaseData['displayName'] ?? '',
      'photo_url': firebaseData['photoUrl'],
      'birthday': firebaseData['birthday'] is DateTime
          ? (firebaseData['birthday'] as DateTime).toIso8601String()
          : firebaseData['birthday'],
      'couple_id': firebaseData['coupleId'],
      'invite_code': firebaseData['inviteCode'],
      'profile_complete': firebaseData['profileComplete'] ?? false,
    };
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
