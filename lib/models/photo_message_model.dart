import 'package:intl/intl.dart';

class PhotoMessageModel {
  final String? id;
  final String coupleId;
  final String senderId;
  final String receiverId;
  final String imageUrl;
  final String? caption;
  final DateTime sentAt;
  final DateTime? createdAt;

  PhotoMessageModel({
    this.id,
    required this.coupleId,
    required this.senderId,
    required this.receiverId,
    required this.imageUrl,
    this.caption,
    required this.sentAt,
    this.createdAt,
  });

  factory PhotoMessageModel.fromJson(Map<String, dynamic> json) {
    final sentAtValue = json['sent_at'] ?? json['created_at'];
    return PhotoMessageModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      caption: json['caption'] as String?,
      sentAt: sentAtValue != null
          ? DateTime.parse(sentAtValue as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'couple_id': coupleId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'image_url': imageUrl,
      if (caption != null && caption!.trim().isNotEmpty)
        'caption': caption!.trim(),
      'sent_at': sentAt.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  String get formattedDate => DateFormat('MMM d, yyyy').format(sentAt);

  String get formattedTime => DateFormat('h:mm a').format(sentAt);

  String get formattedDateTime => '$formattedDate • $formattedTime';
}
