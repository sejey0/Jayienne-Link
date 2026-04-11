class PartnerRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderEmail;
  final String receiverEmail;
  final String senderName;
  final String receiverName;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const PartnerRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderEmail,
    required this.receiverEmail,
    required this.senderName,
    required this.receiverName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCanceled => status == 'canceled';

  factory PartnerRequestModel.fromJson(Map<String, dynamic> json) {
    return PartnerRequestModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      senderEmail: json['sender_email'] as String? ?? '',
      receiverEmail: json['receiver_email'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
      receiverName: json['receiver_name'] as String? ?? '',
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
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender_email': senderEmail,
      'receiver_email': receiverEmail,
      'sender_name': senderName,
      'receiver_name': receiverName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}
