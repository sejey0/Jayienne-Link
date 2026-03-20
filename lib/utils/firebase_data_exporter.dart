import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/couple_model.dart';
import '../models/invite_code_model.dart';
import '../models/location_model.dart';

/// Firebase data export utility for migrating to Supabase
/// Exports all Firestore data to JSON format for migration
class FirebaseDataExporter {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Export all users from Firebase
  Future<List<Map<String, dynamic>>> exportUsers() async {
    try {
      debugPrint('📤 Exporting users from Firebase...');

      final snapshot = await _firestore.collection('users').get();
      final users = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        try {
          final user = UserModel.fromFirestore(doc);
          final userData = user.toFirestore();
          userData['_firebase_doc_id'] = doc.id;
          users.add(userData);
        } catch (e) {
          debugPrint('❌ Error exporting user ${doc.id}: $e');
        }
      }

      debugPrint('✅ Exported ${users.length} users');
      return users;
    } catch (e) {
      debugPrint('❌ Failed to export users: $e');
      return [];
    }
  }

  /// Export all couples from Firebase
  Future<List<Map<String, dynamic>>> exportCouples() async {
    try {
      debugPrint('📤 Exporting couples from Firebase...');

      final snapshot = await _firestore.collection('couples').get();
      final couples = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        try {
          final couple = CoupleModel.fromFirestore(doc);
          final coupleData = couple.toFirestore();
          coupleData['_firebase_doc_id'] = doc.id;
          couples.add(coupleData);
        } catch (e) {
          debugPrint('❌ Error exporting couple ${doc.id}: $e');
        }
      }

      debugPrint('✅ Exported ${couples.length} couples');
      return couples;
    } catch (e) {
      debugPrint('❌ Failed to export couples: $e');
      return [];
    }
  }

  /// Export all invite codes from Firebase
  Future<List<Map<String, dynamic>>> exportInviteCodes() async {
    try {
      debugPrint('📤 Exporting invite codes from Firebase...');

      final snapshot = await _firestore.collection('inviteCodes').get();
      final codes = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        try {
          final code = InviteCodeModel.fromFirestore(doc);
          final codeData = code.toFirestore();
          codeData['_firebase_doc_id'] = doc.id;
          codeData['_code'] = doc.id; // The document ID is the code
          codes.add(codeData);
        } catch (e) {
          debugPrint('❌ Error exporting invite code ${doc.id}: $e');
        }
      }

      debugPrint('✅ Exported ${codes.length} invite codes');
      return codes;
    } catch (e) {
      debugPrint('❌ Failed to export invite codes: $e');
      return [];
    }
  }

  /// Export locations for a specific couple from Firebase
  Future<List<Map<String, dynamic>>> exportLocations(String coupleId) async {
    try {
      debugPrint('📤 Exporting locations for couple $coupleId...');

      final snapshot = await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('locations')
          .get();

      final locations = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        try {
          final location = LocationModel.fromFirestore(doc);
          final locationData = location.toFirestore();
          locationData['_firebase_doc_id'] = doc.id;
          locationData['_couple_id'] = coupleId;
          locations.add(locationData);
        } catch (e) {
          debugPrint('❌ Error exporting location ${doc.id}: $e');
        }
      }

      debugPrint(
          '✅ Exported ${locations.length} locations for couple $coupleId');
      return locations;
    } catch (e) {
      debugPrint('❌ Failed to export locations: $e');
      return [];
    }
  }

  /// Export all data from Firebase
  Future<Map<String, dynamic>> exportAllData() async {
    debugPrint('🚀 Starting full Firebase data export...');

    final exportData = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'export_version': '1.0',
    };

    // Export users
    exportData['users'] = await exportUsers();

    // Export couples
    exportData['couples'] = await exportCouples();

    // Export invite codes
    exportData['invite_codes'] = await exportInviteCodes();

    // Export locations for all couples
    final couples = exportData['couples'] as List<Map<String, dynamic>>;
    final allLocations = <Map<String, dynamic>>[];

    for (final couple in couples) {
      final coupleId = couple['_firebase_doc_id'] as String;
      final locations = await exportLocations(coupleId);
      allLocations.addAll(locations);
    }
    exportData['locations'] = allLocations;

    // Add statistics
    exportData['stats'] = {
      'total_users': (exportData['users'] as List).length,
      'total_couples': couples.length,
      'total_invite_codes': (exportData['invite_codes'] as List).length,
      'total_locations': allLocations.length,
    };

    debugPrint('✅ Export complete!');
    debugPrint('📊 Statistics:');
    debugPrint('   Users: ${exportData['stats']['total_users']}');
    debugPrint('   Couples: ${exportData['stats']['total_couples']}');
    debugPrint('   Invite Codes: ${exportData['stats']['total_invite_codes']}');
    debugPrint('   Locations: ${exportData['stats']['total_locations']}');

    return exportData;
  }

  /// Export data to JSON string
  Future<String> exportToJson() async {
    final data = await exportAllData();
    return jsonEncode(data);
  }

  /// Get migration statistics without exporting
  Future<Map<String, int>> getMigrationStats() async {
    try {
      final usersCount =
          await _firestore.collection('users').get().then((s) => s.size);
      final couplesCount =
          await _firestore.collection('couples').get().then((s) => s.size);
      final codesCount =
          await _firestore.collection('inviteCodes').get().then((s) => s.size);

      // Count locations (need to iterate through couples)
      int locationsCount = 0;
      final couplesSnapshot = await _firestore.collection('couples').get();
      for (final couple in couplesSnapshot.docs) {
        final locSnapshot =
            await couple.reference.collection('locations').get();
        locationsCount += locSnapshot.size;
      }

      return {
        'users': usersCount,
        'couples': couplesCount,
        'invite_codes': codesCount,
        'locations': locationsCount,
      };
    } catch (e) {
      debugPrint('❌ Failed to get migration stats: $e');
      return {};
    }
  }

  /// Test Firebase connection
  Future<bool> testConnection() async {
    try {
      await _firestore.collection('users').limit(1).get();
      debugPrint('✅ Firebase connection: OK');
      return true;
    } catch (e) {
      debugPrint('❌ Firebase connection: FAILED - $e');
      return false;
    }
  }
}
