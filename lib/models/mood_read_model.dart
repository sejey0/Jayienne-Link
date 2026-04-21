class MoodReadModel {
  final String? id;
  final String coupleId;
  final String moodMessageId;
  final String readerId;
  final DateTime readAt;

  MoodReadModel({
    this.id,
    required this.coupleId,
    required this.moodMessageId,
    required this.readerId,
    required this.readAt,
  });

  factory MoodReadModel.fromJson(Map<String, dynamic> json) {
    final readAtValue = json['read_at'] ?? json['created_at'];
    return MoodReadModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      moodMessageId: json['mood_message_id'] as String? ?? '',
      readerId: json['reader_id'] as String? ?? '',
      readAt: readAtValue != null
          ? DateTime.parse(readAtValue as String)
          : DateTime.now(),
    );
  }
}
