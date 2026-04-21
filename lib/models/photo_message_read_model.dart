class PhotoMessageReadModel {
  final String? id;
  final String coupleId;
  final String photoMessageId;
  final String readerId;
  final DateTime readAt;

  PhotoMessageReadModel({
    this.id,
    required this.coupleId,
    required this.photoMessageId,
    required this.readerId,
    required this.readAt,
  });

  factory PhotoMessageReadModel.fromJson(Map<String, dynamic> json) {
    final readAtValue = json['read_at'] ?? json['created_at'];
    return PhotoMessageReadModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      photoMessageId: json['photo_message_id'] as String? ?? '',
      readerId: json['reader_id'] as String? ?? '',
      readAt: readAtValue != null
          ? DateTime.parse(readAtValue as String)
          : DateTime.now(),
    );
  }
}
