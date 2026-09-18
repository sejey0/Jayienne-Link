import 'package:intl/intl.dart';

enum MoodLetterStatus {
  unread,
  read,
}

class MoodLetterModel {
  final String id;
  final String coupleId;
  final String senderId;
  final String receiverId;
  final String category;
  final String title;
  final String content;
  final MoodLetterStatus status;
  final int readCount;
  final DateTime createdAt;
  final DateTime? firstReadAt;
  final DateTime? lastReadAt;

  const MoodLetterModel({
    required this.id,
    required this.coupleId,
    required this.senderId,
    required this.receiverId,
    required this.category,
    required this.title,
    required this.content,
    required this.status,
    required this.readCount,
    required this.createdAt,
    this.firstReadAt,
    this.lastReadAt,
  });

  bool get isRead => status == MoodLetterStatus.read;

  factory MoodLetterModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String? ?? 'UNREAD').toUpperCase();
    final createdAtRaw = json['created_at'];
    final firstReadRaw = json['first_read_at'];
    final lastReadRaw = json['last_read_at'];

    return MoodLetterModel(
      id: json['id'] as String? ?? '',
      coupleId: json['couple_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      title: json['title'] as String? ?? 'Untitled Letter',
      content: json['content'] as String? ?? '',
      status: statusStr == 'READ' ? MoodLetterStatus.read : MoodLetterStatus.unread,
      readCount: json['read_count'] is int
          ? json['read_count'] as int
          : int.tryParse(json['read_count']?.toString() ?? '0') ?? 0,
      createdAt: createdAtRaw != null
          ? DateTime.parse(createdAtRaw as String)
          : DateTime.now(),
      firstReadAt: firstReadRaw != null
          ? DateTime.parse(firstReadRaw as String)
          : null,
      lastReadAt: lastReadRaw != null
          ? DateTime.parse(lastReadRaw as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'category': category,
      'title': title,
      'content': content,
      'status': status == MoodLetterStatus.read ? 'READ' : 'UNREAD',
      'read_count': readCount,
      'created_at': createdAt.toIso8601String(),
      if (firstReadAt != null) 'first_read_at': firstReadAt!.toIso8601String(),
      if (lastReadAt != null) 'last_read_at': lastReadAt!.toIso8601String(),
    };
  }

  MoodLetterModel copyWith({
    String? id,
    String? coupleId,
    String? senderId,
    String? receiverId,
    String? category,
    String? title,
    String? content,
    MoodLetterStatus? status,
    int? readCount,
    DateTime? createdAt,
    DateTime? firstReadAt,
    DateTime? lastReadAt,
  }) {
    return MoodLetterModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      category: category ?? this.category,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      readCount: readCount ?? this.readCount,
      createdAt: createdAt ?? this.createdAt,
      firstReadAt: firstReadAt ?? this.firstReadAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  String? formatTimestamp(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('MMM d, yyyy • h:mm a').format(dt.toLocal());
  }

  String get formattedCreatedAt => DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toLocal());
  String? get formattedFirstReadAt => formatTimestamp(firstReadAt ?? lastReadAt);
  String? get formattedLastReadAt => formatTimestamp(lastReadAt ?? firstReadAt);
}
