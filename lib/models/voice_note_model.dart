import 'package:intl/intl.dart';

class VoiceNoteModel {
  final String id;
  final String coupleId;
  final String senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final String audioUrl;
  final int durationSeconds;
  final String? title;
  final bool isListened;
  final DateTime createdAt;

  const VoiceNoteModel({
    required this.id,
    required this.coupleId,
    required this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    required this.audioUrl,
    this.durationSeconds = 10,
    this.title,
    this.isListened = false,
    required this.createdAt,
  });

  String get displaySenderName =>
      (senderName != null && senderName!.isNotEmpty) ? senderName! : 'Partner';

  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  factory VoiceNoteModel.fromJson(Map<String, dynamic> json) {
    return VoiceNoteModel(
      id: json['id']?.toString() ?? '',
      coupleId: json['couple_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name'] as String?,
      senderPhotoUrl: json['sender_photo_url'] as String?,
      audioUrl: json['audio_url']?.toString() ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 10,
      title: json['title'] as String?,
      isListened: json['is_listened'] == true,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  static DateTime _parseDateTime(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) {
      return DateTime(
        raw.year,
        raw.month,
        raw.day,
        raw.hour,
        raw.minute,
        raw.second,
        raw.millisecond,
      );
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return DateTime.now();

    try {
      // Strip any timezone suffix (+00:00, Z, etc.) to preserve the exact date/time stored in database
      final cleaned = str
          .replaceFirst(RegExp(r'(Z|[+-]\d{2}(:\d{2})?)$'), '')
          .replaceAll(' ', 'T');
      return DateTime.parse(cleaned);
    } catch (_) {
      try {
        final parsed = DateTime.parse(str);
        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
        );
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  String get formattedDate => DateFormat('MMM d, yyyy').format(createdAt);
  String get formattedTime => DateFormat('h:mm a').format(createdAt);
  String get formattedDateTime => '$formattedDate • $formattedTime';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (senderPhotoUrl != null) 'sender_photo_url': senderPhotoUrl,
      'audio_url': audioUrl,
      'duration_seconds': durationSeconds,
      if (title != null) 'title': title,
      'is_listened': isListened,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'couple_id': coupleId,
      'sender_id': senderId,
      if (senderName != null && senderName!.isNotEmpty)
        'sender_name': senderName,
      if (senderPhotoUrl != null && senderPhotoUrl!.isNotEmpty)
        'sender_photo_url': senderPhotoUrl,
      'audio_url': audioUrl,
      'duration_seconds': durationSeconds,
      if (title != null && title!.isNotEmpty) 'title': title,
      'is_listened': isListened,
      'created_at': createdAt.toIso8601String(),
    };
  }

  VoiceNoteModel copyWith({
    String? id,
    String? coupleId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? audioUrl,
    int? durationSeconds,
    String? title,
    bool? isListened,
    DateTime? createdAt,
  }) {
    return VoiceNoteModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      title: title ?? this.title,
      isListened: isListened ?? this.isListened,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
