/// PostgreSQL-compatible InviteCodeModel for Supabase integration
class InviteCodeModel {
  final String? id; // Supabase UUID
  final String code;
  final String userId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;
  final String? usedBy;
  final DateTime? usedAt;

  const InviteCodeModel({
    this.id,
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

  /// Human-readable time remaining string
  String get timeRemainingFormatted {
    if (isExpired) return 'Expired';

    final remaining = timeRemaining;
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours % 24}h remaining';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m remaining';
    } else {
      return '${remaining.inMinutes}m remaining';
    }
  }

  InviteCodeModel copyWith({
    String? id,
    String? code,
    String? userId,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? used,
    String? usedBy,
    DateTime? usedAt,
  }) {
    return InviteCodeModel(
      id: id ?? this.id,
      code: code ?? this.code,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      used: used ?? this.used,
      usedBy: usedBy ?? this.usedBy,
      usedAt: usedAt ?? this.usedAt,
    );
  }

  /// Create from Supabase JSON response
  factory InviteCodeModel.fromJson(Map<String, dynamic> json) {
    return InviteCodeModel(
      id: json['id'] as String?,
      code: json['code'] as String,
      userId: json['user_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().add(const Duration(hours: 48)),
      used: json['used'] as bool? ?? false,
      usedBy: json['used_by'] as String?,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'used': used,
      'used_by': usedBy,
      'used_at': usedAt?.toIso8601String(),
    };
  }

  /// Convert to JSON for database insertion (excludes auto-generated fields)
  Map<String, dynamic> toInsertJson() {
    final json = toJson();
    json.remove('id'); // Let database generate UUID
    json.remove('created_at'); // Let database set default
    return json;
  }

  /// Convert to JSON for database updates (excludes immutable fields)
  Map<String, dynamic> toUpdateJson() {
    final json = toJson();
    json.remove('id');
    json.remove('code'); // Immutable
    json.remove('user_id'); // Immutable
    json.remove('created_at'); // Immutable
    json.remove('expires_at'); // Usually immutable
    return json;
  }

  /// Create a new invite code with 48-hour expiration
  factory InviteCodeModel.create({
    required String code,
    required String userId,
    Duration expiration = const Duration(hours: 48),
  }) {
    final now = DateTime.now();
    return InviteCodeModel(
      code: code,
      userId: userId,
      createdAt: now,
      expiresAt: now.add(expiration),
      used: false,
    );
  }

  /// Mark the invite code as used
  InviteCodeModel markAsUsed(String usedByUserId) {
    return copyWith(
      used: true,
      usedBy: usedByUserId,
      usedAt: DateTime.now(),
    );
  }

  /// Firebase Firestore compatibility methods (for existing code)
  @Deprecated(
      'Use fromJson instead. This is for Firebase migration compatibility only.')
  factory InviteCodeModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return InviteCodeModel(
      code: docId,
      userId: data['userId'] as String,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
      expiresAt: data['expiresAt'] as DateTime? ?? DateTime.now(),
      used: data['used'] as bool? ?? false,
      usedBy: data['usedBy'] as String?,
      usedAt: data['usedAt'] as DateTime?,
    );
  }

  @Deprecated(
      'Use toJson instead. This is for Firebase migration compatibility only.')
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'used': used,
      'usedBy': usedBy,
      'usedAt': usedAt,
    };
  }

  @override
  String toString() =>
      'InviteCodeModel(code: $code, used: $used, expires: ${expiresAt.toLocal()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteCodeModel &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  /// Validate invite code format
  static bool isValidCodeFormat(String code) {
    // Expecting 6-character alphanumeric code (e.g., "ABC123")
    return RegExp(r'^[A-Z0-9]{6}$').hasMatch(code);
  }

  /// Generate a random invite code
  static String generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    var seed = random;

    for (int i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      code += chars[seed % chars.length];
    }

    return code;
  }
}
