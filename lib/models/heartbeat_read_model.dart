class HeartbeatReadModel {
  final String? id;
  final String coupleId;
  final String heartbeatId;
  final String readerId;
  final DateTime readAt;

  HeartbeatReadModel({
    this.id,
    required this.coupleId,
    required this.heartbeatId,
    required this.readerId,
    required this.readAt,
  });

  factory HeartbeatReadModel.fromJson(Map<String, dynamic> json) {
    final readAtValue = json['read_at'] ?? json['created_at'];
    return HeartbeatReadModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      heartbeatId: json['heartbeat_id'] as String? ?? '',
      readerId: json['reader_id'] as String? ?? '',
      readAt: readAtValue != null
          ? DateTime.parse(readAtValue as String)
          : DateTime.now(),
    );
  }
}
