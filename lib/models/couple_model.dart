import 'dart:math' as math;

/// PostgreSQL-compatible CoupleModel for Supabase integration
class CoupleModel {
  final String? id; // Supabase UUID
  final List<String> partnerIds;
  final List<String> partnerNames;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? anniversary;
  final String? coupleName;
  final String status;

  const CoupleModel({
    this.id,
    required this.partnerIds,
    required this.partnerNames,
    required this.createdAt,
    this.updatedAt,
    this.anniversary,
    this.coupleName,
    this.status = 'active',
  });

  String getPartnerName(String myUid, {String? livePartnerName}) {
    if (livePartnerName != null && livePartnerName.trim().isNotEmpty) {
      return livePartnerName.trim();
    }
    final myIndex = partnerIds.indexOf(myUid);
    if (myIndex == -1) return '';
    final targetIndex = myIndex == 0 ? 1 : 0;
    if (targetIndex < partnerNames.length && partnerNames[targetIndex].trim().isNotEmpty) {
      return partnerNames[targetIndex].trim();
    }
    return '';
  }

  String getPartnerId(String myUid) {
    return partnerIds.firstWhere((id) => id != myUid, orElse: () => '');
  }

  int get daysTogether {
    final startDate = (anniversary ?? createdAt).toLocal();
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(startDay).inDays;
    return math.max(0, days);
  }

  CoupleModel copyWith({
    String? id,
    List<String>? partnerIds,
    List<String>? partnerNames,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? anniversary,
    String? coupleName,
    String? status,
  }) {
    return CoupleModel(
      id: id ?? this.id,
      partnerIds: partnerIds ?? this.partnerIds,
      partnerNames: partnerNames ?? this.partnerNames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      anniversary: anniversary ?? this.anniversary,
      coupleName: coupleName ?? this.coupleName,
      status: status ?? this.status,
    );
  }

  /// Create from Supabase JSON response
  factory CoupleModel.fromJson(Map<String, dynamic> json) {
    return CoupleModel(
      id: json['id'] as String?,
      partnerIds: List<String>.from(json['partner_ids'] ?? []),
      partnerNames: List<String>.from(json['partner_names'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      anniversary: json['anniversary'] != null
          ? DateTime.parse(json['anniversary'] as String)
          : null,
      coupleName: json['couple_name'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'partner_ids': partnerIds,
      'partner_names': partnerNames,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'anniversary': anniversary?.toIso8601String(),
      'couple_name': coupleName,
      'status': status,
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
    json.remove('partner_ids'); // Usually immutable after creation
    json.remove('created_at'); // Immutable
    json.remove('updated_at'); // Updated by trigger
    return json;
  }

  @override
  String toString() =>
      'CoupleModel(id: $id, partners: ${partnerNames.join(" & ")})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Check if both partners are in the couple
  bool hasPartner(String userId) => partnerIds.contains(userId);

  /// Validate couple data integrity
  bool get isValid =>
      partnerIds.length == 2 &&
      partnerNames.length == 2 &&
      partnerIds[0] != partnerIds[1] &&
      partnerNames[0].isNotEmpty &&
      partnerNames[1].isNotEmpty;
}
