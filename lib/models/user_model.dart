/// PostgreSQL-compatible UserModel for Supabase integration
/// Maintains compatibility with existing code while adding Supabase support
class UserModel {
  final String? id; // Supabase UUID (null for new records)
  final String? firebaseUid; // Firebase UID for migration compatibility
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
    this.id,
    this.firebaseUid,
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

  /// Compatibility getter for existing code that expects 'uid'
  String get uid => id ?? firebaseUid ?? '';

  UserModel copyWith({
    String? id,
    String? firebaseUid,
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
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
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

  /// Create from Supabase JSON response
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String?,
      firebaseUid: json['firebase_uid'] as String?,
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      displayName: json['display_name'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      coupleId: json['couple_id'] as String?,
      inviteCode: json['invite_code'] as String?,
      profileComplete: json['profile_complete'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      'email': email,
      'phone_number': phoneNumber,
      'display_name': displayName,
      'photo_url': photoUrl,
      'birthday': birthday?.toIso8601String(),
      'couple_id': coupleId,
      'invite_code': inviteCode,
      'profile_complete': profileComplete,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON for database insertion (excludes auto-generated fields)
  Map<String, dynamic> toInsertJson() {
    final json = toJson();
    json.remove('id'); // Let database generate UUID
    json.remove('created_at'); // Let database set default
    json.remove('updated_at'); // Let database set default
    return json;
  }

  /// Convert to JSON for database updates (excludes immutable fields)
  Map<String, dynamic> toUpdateJson() {
    final json = toJson();
    json.remove('id');
    json.remove('firebase_uid'); // Immutable
    json.remove('created_at'); // Immutable
    json.remove('updated_at'); // Updated by trigger
    return json;
  }

  /// Firebase Firestore compatibility methods (for existing code)
  @Deprecated(
      'Use fromJson instead. This is for Firebase migration compatibility only.')
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      firebaseUid: data['uid'] as String?,
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      birthday:
          data['birthday'] is DateTime ? data['birthday'] as DateTime : null,
      coupleId: data['coupleId'] as String?,
      inviteCode: data['inviteCode'] as String?,
      profileComplete: data['profileComplete'] as bool? ?? false,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
      updatedAt: data['updatedAt'] as DateTime? ?? DateTime.now(),
    );
  }

  @Deprecated(
      'Use toJson instead. This is for Firebase migration compatibility only.')
  Map<String, dynamic> toFirestore() {
    return {
      'uid': firebaseUid ?? id,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'birthday': birthday,
      'coupleId': coupleId,
      'inviteCode': inviteCode,
      'profileComplete': profileComplete,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() =>
      'UserModel(id: ${id ?? firebaseUid}, displayName: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          (id == other.id || firebaseUid == other.firebaseUid);

  @override
  int get hashCode => (id ?? firebaseUid).hashCode;

  /// Check if user skipped couple linking (has placeholder coupleId)
  bool get hasSkippedCoupleLink =>
      coupleId != null &&
      (coupleId!.startsWith('skipped_') || coupleId!.startsWith('dev_skip_'));

  /// Check if user has a real partner link
  bool get hasRealPartner =>
      coupleId != null &&
      !coupleId!.startsWith('skipped_') &&
      !coupleId!.startsWith('dev_skip_');

  /// Check if this is a Supabase user (has UUID id) vs Firebase user (has firebaseUid only)
  bool get isSupabaseUser => id != null;

  /// Check if this is a Firebase migration user
  bool get isFirebaseMigrationUser => firebaseUid != null;
}
