import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? phoneNumber;
  final String displayName;
  final String? photoUrl;
  final DateTime? birthday;
  final String? coupleId;
  final String? inviteCode;
  final bool profileComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.phoneNumber,
    required this.displayName,
    this.photoUrl,
    this.birthday,
    this.coupleId,
    this.inviteCode,
    this.profileComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    DateTime? birthday,
    String? coupleId,
    String? inviteCode,
    bool? profileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      birthday: birthday ?? this.birthday,
      coupleId: coupleId ?? this.coupleId,
      inviteCode: inviteCode ?? this.inviteCode,
      profileComplete: profileComplete ?? this.profileComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] as String,
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      coupleId: data['coupleId'] as String?,
      inviteCode: data['inviteCode'] as String?,
      profileComplete: data['profileComplete'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'coupleId': coupleId,
      'inviteCode': inviteCode,
      'profileComplete': profileComplete,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  String toString() => 'UserModel(uid: $uid, displayName: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
