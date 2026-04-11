class AnniversaryRequestModel {
  final String id;
  final String coupleId;
  final String proposerId;
  final String partnerId;
  final DateTime proposedDate;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const AnniversaryRequestModel({
    required this.id,
    required this.coupleId,
    required this.proposerId,
    required this.partnerId,
    required this.proposedDate,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';

  factory AnniversaryRequestModel.fromJson(Map<String, dynamic> json) {
    return AnniversaryRequestModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      proposerId: json['proposer_id'] as String,
      partnerId: json['partner_id'] as String,
      proposedDate: json['proposed_date'] != null
          ? DateTime.parse(json['proposed_date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'couple_id': coupleId,
      'proposer_id': proposerId,
      'partner_id': partnerId,
      'proposed_date': proposedDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}
