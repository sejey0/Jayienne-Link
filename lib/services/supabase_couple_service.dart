import 'package:flutter/foundation.dart';
import '../models/couple_model.dart';
import '../models/supabase_invite_code_model.dart';
import '../models/user_model.dart';
import '../services/supabase_data_service.dart';
import '../core/utils/invite_code_generator.dart';

/// Supabase-based couple service handling relationship management and invite codes
class SupabaseCoupleService {
  static const String _codesTable = 'invite_codes';
  static const String _couplesTable = 'couples';
  static const String _usersTable = 'users';

  /// Generate a unique invite code and store it in the database
  Future<String> generateAndStoreInviteCode(String userId) async {
    const maxAttempts = 5;

    debugPrint('📝 Generating invite code for user ID: $userId');

    // First, verify the user exists in the users table
    final userExists = await SupabaseDataService.getSingleRecord(
      _usersTable,
      whereColumn: 'id',
      whereValue: userId,
    );

    if (userExists == null) {
      debugPrint('❌ User not found in users table: $userId');
      throw Exception('User not found. Please complete your profile first.');
    }

    debugPrint('✅ User verified in database: ${userExists['email']}');

    for (var i = 0; i < maxAttempts; i++) {
      final code = InviteCodeGenerator.generate();

      try {
        // Check if code already exists
        final existing = await SupabaseDataService.getSingleRecord(
          _codesTable,
          whereColumn: 'code',
          whereValue: code,
        );

        if (existing == null) {
          // Code is unique, create invite
          final inviteCode = InviteCodeModel.create(
            code: code,
            userId: userId,
            expiration: const Duration(hours: 48),
          );

          await SupabaseDataService.insertRecord(
            _codesTable,
            inviteCode.toInsertJson(),
          );

          // Update user's invite code reference
          await SupabaseDataService.updateRecords(
            _usersTable,
            {'invite_code': code},
            whereColumn: 'id',
            whereValue: userId,
          );

          debugPrint('✅ Invite code generated: $code for user: $userId');
          return code;
        }
      } catch (e) {
        debugPrint('Attempt ${i + 1}: Failed to generate code - $e');
        if (i == maxAttempts - 1) rethrow;
      }
    }

    throw Exception(
        'Failed to generate a unique invite code after $maxAttempts attempts');
  }

  /// Get an invite code by its code string
  Future<InviteCodeModel?> getInviteCode(String code) async {
    try {
      final codeData = await SupabaseDataService.getSingleRecord(
        _codesTable,
        whereColumn: 'code',
        whereValue: code.toUpperCase(),
      );

      if (codeData == null) {
        debugPrint('Invite code not found: $code');
        return null;
      }

      debugPrint('📋 Invite code found: $code, owner user_id: ${codeData['user_id']}');
      return InviteCodeModel.fromJson(codeData);
    } catch (e) {
      debugPrint('Failed to get invite code $code: $e');
      return null;
    }
  }

  /// Regenerate an invite code (delete old, create new)
  Future<String> regenerateInviteCode(String userId, String? oldCode) async {
    try {
      // Delete old code if it exists
      if (oldCode != null) {
        await SupabaseDataService.deleteRecords(
          _codesTable,
          whereColumn: 'code',
          whereValue: oldCode.toUpperCase(),
        );
        debugPrint('Deleted old invite code: $oldCode');
      }

      // Generate new code
      return await generateAndStoreInviteCode(userId);
    } catch (e) {
      debugPrint('Failed to regenerate invite code: $e');
      throw Exception('Failed to regenerate invite code: $e');
    }
  }

  /// Link two users as a couple using the invite code
  /// This performs atomic operations to ensure data consistency
  Future<CoupleModel> linkCouple(String code, String currentUserId) async {
    try {
      debugPrint('🔗 Attempting to link couple with code: $code');

      // Step 1: Get and validate invite code
      final inviteCode = await getInviteCode(code);
      if (inviteCode == null) {
        throw Exception('Invalid invite code');
      }

      // Step 2: Validate business rules
      if (inviteCode.isExpired) {
        throw Exception('This code has expired');
      }
      if (inviteCode.userId == currentUserId) {
        throw Exception('You cannot use your own code');
      }

      // Step 3: Get both users
      debugPrint('🔍 Looking up current user: $currentUserId');
      final currentUserData = await SupabaseDataService.getSingleRecord(
        _usersTable,
        whereColumn: 'id',
        whereValue: currentUserId,
      );
      debugPrint('🔍 Current user found: ${currentUserData != null}');

      debugPrint('🔍 Looking up partner (code owner): ${inviteCode.userId}');
      final partnerData = await SupabaseDataService.getSingleRecord(
        _usersTable,
        whereColumn: 'id',
        whereValue: inviteCode.userId,
      );
      debugPrint('🔍 Partner found: ${partnerData != null}');

      if (currentUserData == null || partnerData == null) {
        if (currentUserData == null) {
          debugPrint('❌ Current user NOT in database: $currentUserId');
        }
        if (partnerData == null) {
          debugPrint('❌ Partner (code owner) NOT in database: ${inviteCode.userId}');
        }
        throw Exception('User not found');
      }

      final currentUser = UserModel.fromJson(currentUserData);
      final partner = UserModel.fromJson(partnerData);

      debugPrint('=== Link Couple Debug ===');
      debugPrint(
          'Current user: ${currentUser.id}, coupleId: ${currentUser.coupleId}');
      debugPrint('Current user hasRealPartner: ${currentUser.hasRealPartner}');
      debugPrint('Partner: ${partner.id}, coupleId: ${partner.coupleId}');
      debugPrint('Partner hasRealPartner: ${partner.hasRealPartner}');
      debugPrint('Code used: ${inviteCode.used}');
      debugPrint('=======================');

      // Step 4: Check if users are already linked
      if (currentUser.hasRealPartner) {
        throw Exception('You are already linked with a partner');
      }
      if (partner.hasRealPartner) {
        throw Exception('This person is already linked with someone');
      }

      // Step 5: Handle edge case - code marked used but partner only has skipped status
      if (inviteCode.used && !partner.hasRealPartner) {
        debugPrint('Resetting invite code - partner has skipped status');
        await SupabaseDataService.updateRecords(
          _codesTable,
          {
            'used': false,
            'used_by': null,
            'used_at': null,
          },
          whereColumn: 'code',
          whereValue: code.toUpperCase(),
        );
      } else if (inviteCode.used && partner.hasRealPartner) {
        throw Exception('This code has already been used');
      }

      // Step 6: Create the couple using PostgreSQL function for atomicity
      final coupleData = await SupabaseDataService.executeProcedure(
        'create_couple',
        params: {
          'user1_id': partner.id,
          'user2_id': currentUser.id,
          'user1_name': partner.displayName,
          'user2_name': currentUser.displayName,
        },
      );

      if (coupleData.isEmpty) {
        throw Exception('Failed to create couple relationship');
      }

      final coupleId = coupleData.first['create_couple'] as String;
      debugPrint('✅ Couple created with ID: $coupleId');

      // Step 7: Mark invite code as used
      await SupabaseDataService.updateRecords(
        _codesTable,
        {
          'used': true,
          'used_by': currentUserId,
          'used_at': DateTime.now().toIso8601String(),
        },
        whereColumn: 'code',
        whereValue: code.toUpperCase(),
      );

      // Step 8: Get the created couple data
      final createdCoupleData = await SupabaseDataService.getSingleRecord(
        _couplesTable,
        whereColumn: 'id',
        whereValue: coupleId,
      );

      if (createdCoupleData == null) {
        throw Exception('Failed to retrieve created couple');
      }

      final couple = CoupleModel.fromJson(createdCoupleData);
      debugPrint(
          '✅ Couple linked successfully: ${couple.partnerNames.join(" & ")}');

      return couple;
    } catch (e) {
      debugPrint('❌ Failed to link couple: $e');
      throw Exception('Failed to link couple: $e');
    }
  }

  /// Get real-time stream of couple data
  Stream<CoupleModel?> coupleStream(String coupleId) {
    try {
      return SupabaseDataService.getSingleRecordStream(
        _couplesTable,
        whereColumn: 'id',
        whereValue: coupleId,
      ).map((coupleData) {
        if (coupleData == null) return null;
        return CoupleModel.fromJson(coupleData);
      }).handleError((error) {
        debugPrint('Couple stream error for $coupleId: $error');
      });
    } catch (e) {
      debugPrint('Failed to create couple stream for $coupleId: $e');
      return Stream.error(e);
    }
  }

  /// Get couple data by ID
  Future<CoupleModel?> getCouple(String coupleId) async {
    try {
      final coupleData = await SupabaseDataService.getSingleRecord(
        _couplesTable,
        whereColumn: 'id',
        whereValue: coupleId,
      );

      if (coupleData == null) {
        debugPrint('Couple not found: $coupleId');
        return null;
      }

      return CoupleModel.fromJson(coupleData);
    } catch (e) {
      debugPrint('Failed to get couple $coupleId: $e');
      return null;
    }
  }

  /// Update couple information
  Future<void> updateCouple(String coupleId, Map<String, dynamic> data) async {
    try {
      debugPrint('Updating couple: $coupleId');

      // Convert field names if needed
      final pgData = <String, dynamic>{};
      for (final entry in data.entries) {
        switch (entry.key) {
          case 'coupleName':
            pgData['couple_name'] = entry.value;
            break;
          case 'anniversary':
            pgData['anniversary'] = entry.value is DateTime
                ? (entry.value as DateTime).toIso8601String()
                : entry.value;
            break;
          default:
            pgData[entry.key] = entry.value;
        }
      }

      await SupabaseDataService.updateRecords(
        _couplesTable,
        pgData,
        whereColumn: 'id',
        whereValue: coupleId,
      );

      debugPrint('✅ Couple updated successfully: $coupleId');
    } catch (e) {
      debugPrint('❌ Failed to update couple $coupleId: $e');
      throw Exception('Failed to update couple: $e');
    }
  }

  /// Unlink a couple (break the relationship)
  Future<void> unlinkCouple(String coupleId) async {
    try {
      debugPrint('Unlinking couple: $coupleId');

      // Get users in this couple
      final usersData = await SupabaseDataService.getRecords(
        _usersTable,
        whereColumn: 'couple_id',
        whereValue: coupleId,
      );

      // Update users to remove couple_id
      for (final userData in usersData) {
        await SupabaseDataService.updateRecords(
          _usersTable,
          {'couple_id': null},
          whereColumn: 'id',
          whereValue: userData['id'],
        );
      }

      // Delete the couple record
      await SupabaseDataService.deleteRecords(
        _couplesTable,
        whereColumn: 'id',
        whereValue: coupleId,
      );

      debugPrint('✅ Couple unlinked successfully: $coupleId');
    } catch (e) {
      debugPrint('❌ Failed to unlink couple $coupleId: $e');
      throw Exception('Failed to unlink couple: $e');
    }
  }

  /// Reset invite codes for a user (mark them as unused)
  Future<void> resetInviteCodes(String userId) async {
    try {
      debugPrint('Resetting invite codes for user: $userId');

      // Get all used codes for this user
      final codes = await SupabaseDataService.getRecords(
        _codesTable,
        whereColumn: 'user_id',
        whereValue: userId,
      );

      int resetCount = 0;
      for (final codeData in codes) {
        if (codeData['used'] == true) {
          await SupabaseDataService.updateRecords(
            _codesTable,
            {
              'used': false,
              'used_by': null,
              'used_at': null,
            },
            whereColumn: 'id',
            whereValue: codeData['id'],
          );
          resetCount++;
        }
      }

      debugPrint('✅ Reset $resetCount invite codes for user: $userId');
    } catch (e) {
      debugPrint('❌ Failed to reset invite codes: $e');
      throw Exception('Failed to reset invite codes: $e');
    }
  }

  /// Delete expired invite codes
  Future<int> cleanupExpiredCodes() async {
    try {
      debugPrint('Cleaning up expired invite codes...');

      // Use the PostgreSQL function
      await SupabaseDataService.executeProcedure(
          'cleanup_expired_invite_codes');

      debugPrint('✅ Expired invite codes cleaned up');
      return 0; // Can't return count from void procedure
    } catch (e) {
      debugPrint('❌ Failed to cleanup expired codes: $e');
      return 0;
    }
  }

  /// Get invite codes for a user
  Future<List<InviteCodeModel>> getUserInviteCodes(String userId) async {
    try {
      final codesData = await SupabaseDataService.getRecords(
        _codesTable,
        whereColumn: 'user_id',
        whereValue: userId,
        orderBy: 'created_at',
        ascending: false,
      );

      return codesData.map((data) => InviteCodeModel.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Failed to get user invite codes: $e');
      return [];
    }
  }

  /// Get active (valid, unused) invite codes
  Future<List<InviteCodeModel>> getActiveInviteCodes() async {
    try {
      final codesData = await SupabaseDataService.getRecords(
        _codesTable,
        orderBy: 'created_at',
        ascending: false,
      );

      return codesData
          .map((data) => InviteCodeModel.fromJson(data))
          .where((code) => code.isValid)
          .toList();
    } catch (e) {
      debugPrint('Failed to get active invite codes: $e');
      return [];
    }
  }

  /// Get couple statistics
  Future<Map<String, dynamic>> getCoupleStats() async {
    try {
      final stats = <String, dynamic>{};

      // Get total couples count
      final couples = await SupabaseDataService.getRecords(_couplesTable);
      stats['total_couples'] = couples.length;

      // Get active couples
      final activeCouples = couples
          .map((data) => CoupleModel.fromJson(data))
          .where((couple) => couple.status == 'active')
          .length;
      stats['active_couples'] = activeCouples;

      // Get total invite codes
      final codes = await SupabaseDataService.getRecords(_codesTable);
      stats['total_codes'] = codes.length;

      // Get active invite codes
      final activeCodes = codes
          .map((data) => InviteCodeModel.fromJson(data))
          .where((code) => code.isValid)
          .length;
      stats['active_codes'] = activeCodes;

      // Get used codes
      final usedCodes = codes.where((data) => data['used'] == true).length;
      stats['used_codes'] = usedCodes;

      return stats;
    } catch (e) {
      debugPrint('Failed to get couple stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Test connectivity
  Future<bool> testConnectivity() async {
    try {
      await SupabaseDataService.testConnectivity();
      return true;
    } catch (e) {
      debugPrint('Couple service connectivity test failed: $e');
      return false;
    }
  }
}
