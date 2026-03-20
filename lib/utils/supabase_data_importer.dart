import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/supabase_data_service.dart';
import '../models/supabase_user_model.dart';
import '../models/supabase_couple_model.dart';
import '../models/supabase_invite_code_model.dart';
import '../models/supabase_location_model.dart';

/// Supabase data importer for migrating from Firebase
/// Imports Firebase exported data into Supabase PostgreSQL database
class SupabaseDataImporter {
  // ID mapping for maintaining relationships
  final Map<String, String> _userIdMap = {}; // Firebase UID -> Supabase UUID
  final Map<String, String> _coupleIdMap = {}; // Firebase ID -> Supabase UUID
  final Map<String, String> _codeIdMap = {}; // Firebase code -> Supabase UUID

  /// Import users from Firebase export data
  Future<int> importUsers(List<Map<String, dynamic>> usersData) async {
    debugPrint('📥 Importing ${usersData.length} users to Supabase...');
    int successCount = 0;
    int errorCount = 0;

    for (final userData in usersData) {
      try {
        final firebaseId = userData['uid'] as String;

        // Convert Firebase data to Supabase format
        final supabaseData = {
          'firebase_uid': firebaseId,
          'email': userData['email'] ?? '',
          'phone_number': userData['phoneNumber'],
          'display_name': userData['displayName'] ?? '',
          'photo_url': userData['photoUrl'],
          'birthday': userData['birthday'] is Timestamp
              ? (userData['birthday'] as Timestamp).toDate().toIso8601String()
              : userData['birthday']?.toString(),
          'couple_id': null, // Will be updated after couples import
          'invite_code': userData['inviteCode'],
          'profile_complete': userData['profileComplete'] ?? false,
        };

        // Insert into Supabase
        final result = await SupabaseDataService.insertRecord(
          'users',
          supabaseData,
        );

        // Store ID mapping
        _userIdMap[firebaseId] = result['id'] as String;
        successCount++;

        if (successCount % 10 == 0) {
          debugPrint('   Imported $successCount users...');
        }
      } catch (e) {
        errorCount++;
        debugPrint('❌ Error importing user: $e');
      }
    }

    debugPrint(
        '✅ Users import complete: $successCount success, $errorCount errors');
    return successCount;
  }

  /// Import couples from Firebase export data
  Future<int> importCouples(List<Map<String, dynamic>> couplesData) async {
    debugPrint('📥 Importing ${couplesData.length} couples to Supabase...');
    int successCount = 0;
    int errorCount = 0;

    for (final coupleData in couplesData) {
      try {
        final firebaseId = coupleData['_firebase_doc_id'] as String;

        // Map partner Firebase UIDs to Supabase UUIDs
        final firebasePartnerIds =
            List<String>.from(coupleData['partnerIds'] ?? []);
        final supabasePartnerIds = firebasePartnerIds
            .map((fid) => _userIdMap[fid])
            .where((sid) => sid != null)
            .cast<String>()
            .toList();

        if (supabasePartnerIds.length != 2) {
          debugPrint(
              '⚠️ Skipping couple $firebaseId: Could not map both partner IDs');
          errorCount++;
          continue;
        }

        // Convert Firebase data to Supabase format
        final supabaseData = {
          'partner_ids': supabasePartnerIds,
          'partner_names': List<String>.from(coupleData['partnerNames'] ?? []),
          'couple_name': coupleData['coupleName'],
          'anniversary': coupleData['anniversary'] is Timestamp
              ? (coupleData['anniversary'] as Timestamp)
                  .toDate()
                  .toIso8601String()
              : coupleData['anniversary']?.toString(),
          'status': coupleData['status'] ?? 'active',
        };

        // Insert into Supabase
        final result = await SupabaseDataService.insertRecord(
          'couples',
          supabaseData,
        );

        // Store ID mapping
        final supabaseId = result['id'] as String;
        _coupleIdMap[firebaseId] = supabaseId;

        // Update users with couple_id
        for (final userId in supabasePartnerIds) {
          await SupabaseDataService.updateRecords(
            'users',
            {'couple_id': supabaseId},
            whereColumn: 'id',
            whereValue: userId,
          );
        }

        successCount++;
      } catch (e) {
        errorCount++;
        debugPrint('❌ Error importing couple: $e');
      }
    }

    debugPrint(
        '✅ Couples import complete: $successCount success, $errorCount errors');
    return successCount;
  }

  /// Import invite codes from Firebase export data
  Future<int> importInviteCodes(List<Map<String, dynamic>> codesData) async {
    debugPrint('📥 Importing ${codesData.length} invite codes to Supabase...');
    int successCount = 0;
    int errorCount = 0;

    for (final codeData in codesData) {
      try {
        final code = codeData['_code'] as String;
        final firebaseUserId = codeData['userId'] as String;

        // Map Firebase UID to Supabase UUID
        final supabaseUserId = _userIdMap[firebaseUserId];
        if (supabaseUserId == null) {
          debugPrint('⚠️ Skipping invite code $code: User not found');
          errorCount++;
          continue;
        }

        // Convert Firebase data to Supabase format
        final supabaseData = {
          'code': code,
          'user_id': supabaseUserId,
          'created_at': codeData['createdAt'] is Timestamp
              ? (codeData['createdAt'] as Timestamp).toDate().toIso8601String()
              : codeData['createdAt']?.toString() ??
                  DateTime.now().toIso8601String(),
          'expires_at': codeData['expiresAt'] is Timestamp
              ? (codeData['expiresAt'] as Timestamp).toDate().toIso8601String()
              : codeData['expiresAt']?.toString() ??
                  DateTime.now().add(Duration(hours: 48)).toIso8601String(),
          'used': codeData['used'] ?? false,
          'used_by': codeData['usedBy'] != null
              ? _userIdMap[codeData['usedBy']]
              : null,
          'used_at': codeData['usedAt'] is Timestamp
              ? (codeData['usedAt'] as Timestamp).toDate().toIso8601String()
              : codeData['usedAt']?.toString(),
        };

        // Insert into Supabase
        final result = await SupabaseDataService.insertRecord(
          'invite_codes',
          supabaseData,
        );

        _codeIdMap[code] = result['id'] as String;
        successCount++;

        if (successCount % 10 == 0) {
          debugPrint('   Imported $successCount codes...');
        }
      } catch (e) {
        errorCount++;
        debugPrint('❌ Error importing invite code: $e');
      }
    }

    debugPrint(
        '✅ Invite codes import complete: $successCount success, $errorCount errors');
    return successCount;
  }

  /// Import locations from Firebase export data
  Future<int> importLocations(List<Map<String, dynamic>> locationsData,
      {int batchSize = 100}) async {
    debugPrint('📥 Importing ${locationsData.length} locations to Supabase...');
    int successCount = 0;
    int errorCount = 0;

    // Process in batches for better performance
    for (var i = 0; i < locationsData.length; i += batchSize) {
      final batch = locationsData.skip(i).take(batchSize).toList();
      final batchData = <Map<String, dynamic>>[];

      for (final locationData in batch) {
        try {
          final firebaseCoupleId = locationData['_couple_id'] as String;
          final firebaseOwnerId = locationData['owner_id'] as String;

          // Map IDs
          final supabaseCoupleId = _coupleIdMap[firebaseCoupleId];
          final supabaseOwnerId = _userIdMap[firebaseOwnerId];

          if (supabaseCoupleId == null || supabaseOwnerId == null) {
            errorCount++;
            continue;
          }

          // Convert Firebase data to Supabase format
          final supabaseData = {
            'couple_id': supabaseCoupleId,
            'owner_id': supabaseOwnerId,
            'partner_id': locationData['partner_id'] != null
                ? _userIdMap[locationData['partner_id']]
                : null,
            'latitude': (locationData['latitude'] as num).toDouble(),
            'longitude': (locationData['longitude'] as num).toDouble(),
            'accuracy': (locationData['accuracy'] as num?)?.toDouble() ?? 15.0,
            'timestamp': locationData['timestamp'] is Timestamp
                ? (locationData['timestamp'] as Timestamp)
                    .toDate()
                    .toIso8601String()
                : locationData['timestamp']?.toString() ??
                    DateTime.now().toIso8601String(),
          };

          batchData.add(supabaseData);
        } catch (e) {
          errorCount++;
          debugPrint('❌ Error preparing location: $e');
        }
      }

      // Batch insert
      if (batchData.isNotEmpty) {
        try {
          await SupabaseDataService.client.from('locations').insert(batchData);
          successCount += batchData.length;
          debugPrint('   Imported $successCount locations...');
        } catch (e) {
          errorCount += batchData.length;
          debugPrint('❌ Error importing location batch: $e');
        }
      }
    }

    debugPrint(
        '✅ Locations import complete: $successCount success, $errorCount errors');
    return successCount;
  }

  /// Import all data from Firebase export
  Future<Map<String, int>> importAllData(
      Map<String, dynamic> exportData) async {
    debugPrint('🚀 Starting full data import to Supabase...');

    final results = <String, int>{};

    // Import in order (users -> couples -> codes -> locations)
    // to maintain referential integrity

    // 1. Import users
    if (exportData.containsKey('users')) {
      final users = List<Map<String, dynamic>>.from(exportData['users']);
      results['users'] = await importUsers(users);
    }

    // 2. Import couples
    if (exportData.containsKey('couples')) {
      final couples = List<Map<String, dynamic>>.from(exportData['couples']);
      results['couples'] = await importCouples(couples);
    }

    // 3. Import invite codes
    if (exportData.containsKey('invite_codes')) {
      final codes = List<Map<String, dynamic>>.from(exportData['invite_codes']);
      results['invite_codes'] = await importInviteCodes(codes);
    }

    // 4. Import locations
    if (exportData.containsKey('locations')) {
      final locations =
          List<Map<String, dynamic>>.from(exportData['locations']);
      results['locations'] = await importLocations(locations);
    }

    debugPrint('✅ Import complete!');
    debugPrint('📊 Results:');
    debugPrint('   Users: ${results['users'] ?? 0}');
    debugPrint('   Couples: ${results['couples'] ?? 0}');
    debugPrint('   Invite Codes: ${results['invite_codes'] ?? 0}');
    debugPrint('   Locations: ${results['locations'] ?? 0}');

    return results;
  }

  /// Import from JSON string
  Future<Map<String, int>> importFromJson(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;
    return await importAllData(data);
  }

  /// Get ID mappings for debugging
  Map<String, dynamic> getIdMappings() {
    return {
      'users': _userIdMap,
      'couples': _coupleIdMap,
      'codes': _codeIdMap,
    };
  }

  /// Clear ID mappings (useful for fresh imports)
  void clearIdMappings() {
    _userIdMap.clear();
    _coupleIdMap.clear();
    _codeIdMap.clear();
    debugPrint('🧹 ID mappings cleared');
  }

  /// Test Supabase connection
  Future<bool> testConnection() async {
    try {
      await SupabaseDataService.testConnectivity();
      debugPrint('✅ Supabase connection: OK');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connection: FAILED - $e');
      return false;
    }
  }

  /// Verify import integrity
  Future<Map<String, dynamic>> verifyImport() async {
    try {
      final stats = await SupabaseDataService.getDatabaseHealth();
      debugPrint('📊 Supabase database statistics:');
      debugPrint('   Users: ${stats['users_count']}');
      debugPrint('   Couples: ${stats['couples_count']}');
      debugPrint('   Locations: ${stats['locations_count']}');

      return stats;
    } catch (e) {
      debugPrint('❌ Failed to verify import: $e');
      return {'error': e.toString()};
    }
  }
}
