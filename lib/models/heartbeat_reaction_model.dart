class HeartbeatReactionModel {
  final String? id;
  final String coupleId;
  final String heartbeatId;
  final String userId;
  final String reaction;
  final DateTime createdAt;

  HeartbeatReactionModel({
    this.id,
    required this.coupleId,
    required this.heartbeatId,
    required this.userId,
    required this.reaction,
    required this.createdAt,
  });

  factory HeartbeatReactionModel.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['created_at'] ?? json['updated_at'];
    return HeartbeatReactionModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      heartbeatId: json['heartbeat_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      reaction: json['reaction'] as String? ?? 'purple_heart',
      createdAt: createdAtValue != null
          ? DateTime.parse(createdAtValue as String)
          : DateTime.now(),
    );
  }
}
