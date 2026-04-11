/// Supabase UserModel for PostgreSQL database
class UserModel {
  final String id;
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
    required this.id,
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
  String get uid => id;

  UserModel copyWith({
    String? id,
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
      id: json['id'] as String,
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
      'id': id,
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
    json.remove('created_at'); // Let database set default
    json.remove('updated_at'); // Let database set default
    return json;
  }

  /// Convert to JSON for database updates (excludes immutable fields)
  Map<String, dynamic> toUpdateJson() {
    final json = toJson();
    json.remove('id'); // Immutable
    json.remove('created_at'); // Immutable
    json.remove('updated_at'); // Updated by trigger
    return json;
  }

  @override
  String toString() => 'UserModel(id: $id, displayName: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Check if user skipped couple linking (only when not linked)
  bool get hasSkippedCoupleLink => inviteCode == 'SKIPPED' && coupleId == null;

  /// Check if user has a real partner link
  bool get hasRealPartner => coupleId != null;
}
