import 'package:cloud_firestore/cloud_firestore.dart';

class InviteCodeModel {
  final String code;
  final String userId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;
  final String? usedBy;
  final DateTime? usedAt;

  const InviteCodeModel({
    required this.code,
    required this.userId,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
    this.usedBy,
    this.usedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !used && !isExpired;

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  factory InviteCodeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InviteCodeModel(
      code: doc.id,
      userId: data['userId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      used: data['used'] as bool? ?? false,
      usedBy: data['usedBy'] as String?,
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': used,
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
    };
  }
}
