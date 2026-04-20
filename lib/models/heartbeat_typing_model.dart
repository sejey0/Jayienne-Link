class HeartbeatTypingModel {
  final String? id;
  final String coupleId;
  final String userId;
  final bool isTyping;
  final DateTime updatedAt;

  HeartbeatTypingModel({
    this.id,
    required this.coupleId,
    required this.userId,
    required this.isTyping,
    required this.updatedAt,
  });

  factory HeartbeatTypingModel.fromJson(Map<String, dynamic> json) {
    final updatedAtValue = json['updated_at'] ?? json['created_at'];
    return HeartbeatTypingModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      isTyping: json['is_typing'] as bool? ?? false,
      updatedAt: updatedAtValue != null
          ? DateTime.parse(updatedAtValue as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'couple_id': coupleId,
      'user_id': userId,
      'is_typing': isTyping,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
