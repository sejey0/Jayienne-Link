import 'package:intl/intl.dart';

class HeartbeatModel {
  final String? id;
  final String coupleId;
  final String senderId;
  final String receiverId;
  final DateTime sentAt;
  final DateTime? createdAt;

  HeartbeatModel({
    this.id,
    required this.coupleId,
    required this.senderId,
    required this.receiverId,
    required this.sentAt,
    this.createdAt,
  });

  factory HeartbeatModel.fromJson(Map<String, dynamic> json) {
    final sentAtValue = json['sent_at'] ?? json['created_at'];
    return HeartbeatModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
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
      'sent_at': sentAt.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  String get timeAgo {
    final diff = DateTime.now().difference(sentAt);
    if (diff.inSeconds < 60) {
      final seconds = diff.inSeconds < 1 ? 1 : diff.inSeconds;
      return '$seconds sec ago';
    }
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  String get formattedTime => DateFormat('h:mm a').format(sentAt);
}
