import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/couple_model.dart';
import '../models/invite_code_model.dart';
import '../models/user_model.dart';
import '../core/constants/firestore_paths.dart';
import '../core/utils/invite_code_generator.dart';

class CoupleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _codesRef =>
      _db.collection(FirestorePaths.inviteCodes);
  CollectionReference get _couplesRef => _db.collection(FirestorePaths.couples);
  CollectionReference get _usersRef => _db.collection(FirestorePaths.users);

  /// Generates a unique invite code and stores it in Firestore.
  /// Returns the generated code string.
  Future<String> generateAndStoreInviteCode(String userId) async {
    const maxAttempts = 5;

    for (var i = 0; i < maxAttempts; i++) {
      final code = InviteCodeGenerator.generate();
      final existing = await _codesRef.doc(code).get();

      if (!existing.exists) {
        final now = DateTime.now();
        final inviteCode = InviteCodeModel(
          code: code,
          userId: userId,
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 48)),
        );
        await _codesRef.doc(code).set(inviteCode.toFirestore());

        // Also store the code reference on the user doc
        await _usersRef.doc(userId).set(
          {'inviteCode': code},
          SetOptions(merge: true),
        );

        return code;
      }
    }

    throw Exception(
        'Failed to generate a unique invite code after $maxAttempts attempts');
  }

  Future<InviteCodeModel?> getInviteCode(String code) async {
    final doc = await _codesRef.doc(code.toUpperCase()).get();
    if (!doc.exists) return null;
    return InviteCodeModel.fromFirestore(doc);
  }

  /// Regenerates an invite code: deletes the old one, creates a new one.
  Future<String> regenerateInviteCode(String userId, String? oldCode) async {
    if (oldCode != null) {
      await _codesRef.doc(oldCode).delete();
    }
    return generateAndStoreInviteCode(userId);
  }

  /// Links two users as a couple using a Firestore transaction.
  /// Validates all business rules atomically.
  Future<CoupleModel> linkCouple(String code, String currentUserId) async {
    return _db.runTransaction<CoupleModel>((transaction) async {
      // 1. Read the invite code document
      final codeDoc = await transaction.get(_codesRef.doc(code.toUpperCase()));
      if (!codeDoc.exists) {
        throw Exception('Invalid invite code');
      }
      final inviteCode = InviteCodeModel.fromFirestore(codeDoc);

      // 2. Validate business rules
      if (inviteCode.used) {
        throw Exception('This code has already been used');
      }
      if (inviteCode.isExpired) {
        throw Exception('This code has expired');
      }
      if (inviteCode.userId == currentUserId) {
        throw Exception('You cannot use your own code');
      }

      // 3. Read both user documents
      final currentUserDoc =
          await transaction.get(_usersRef.doc(currentUserId));
      final partnerDoc =
          await transaction.get(_usersRef.doc(inviteCode.userId));

      if (!currentUserDoc.exists || !partnerDoc.exists) {
        throw Exception('User not found');
      }

      final currentUser = UserModel.fromFirestore(currentUserDoc);
      final partner = UserModel.fromFirestore(partnerDoc);

      if (currentUser.coupleId != null) {
        throw Exception('You are already linked with a partner');
      }
      if (partner.coupleId != null) {
        throw Exception('This person is already linked with someone');
      }

      // 4. Create the couple document
      final coupleRef = _couplesRef.doc();
      final now = DateTime.now();
      final couple = CoupleModel(
        id: coupleRef.id,
        partnerIds: [partner.uid, currentUser.uid],
        partnerNames: [partner.displayName, currentUser.displayName],
        createdAt: now,
      );
      transaction.set(coupleRef, couple.toFirestore());

      // 5. Update both user documents with the couple ID
      transaction.update(_usersRef.doc(currentUserId), {
        'coupleId': coupleRef.id,
        'updatedAt': Timestamp.fromDate(now),
      });
      transaction.update(_usersRef.doc(partner.uid), {
        'coupleId': coupleRef.id,
        'updatedAt': Timestamp.fromDate(now),
      });

      // 6. Mark the invite code as used
      transaction.update(_codesRef.doc(code.toUpperCase()), {
        'used': true,
        'usedBy': currentUserId,
        'usedAt': Timestamp.fromDate(now),
      });

      return couple;
    });
  }

  Stream<CoupleModel?> coupleStream(String coupleId) {
    return _couplesRef.doc(coupleId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CoupleModel.fromFirestore(doc);
    });
  }
}
