class SecretMediaModel {
  final String? id;
  final String coupleId;
  final String uploadedById;
  final String mediaType; // 'image' or 'video'
  final String mediaUrl;
  final String? thumbnail; // For videos
  final String? caption;
  final DateTime uploadedAt;
  final bool isEncrypted;
  final bool isHidden; // For completely private media
  final DateTime? deletedAt; // Soft delete timestamp

  SecretMediaModel({
    this.id,
    required this.coupleId,
    required this.uploadedById,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnail,
    this.caption,
    required this.uploadedAt,
    this.isEncrypted = true,
    this.isHidden = false,
    this.deletedAt,
  });

  factory SecretMediaModel.fromJson(Map<String, dynamic> json) {
    final uploadedAtValue = json['uploaded_at'] ?? json['created_at'];
    final deletedAtValue = json['deleted_at'];
    return SecretMediaModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      uploadedById: json['uploaded_by_id'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'image',
      mediaUrl: json['media_url'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      caption: json['caption'] as String?,
      uploadedAt: uploadedAtValue != null
          ? DateTime.parse(uploadedAtValue as String)
          : DateTime.now(),
      isEncrypted: json['is_encrypted'] as bool? ?? true,
      isHidden: json['is_hidden'] as bool? ?? false,
      deletedAt: deletedAtValue != null
          ? DateTime.parse(deletedAtValue as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'couple_id': coupleId,
      'uploaded_by_id': uploadedById,
      'media_type': mediaType,
      'media_url': mediaUrl,
      if (thumbnail != null && thumbnail!.trim().isNotEmpty)
        'thumbnail': thumbnail!.trim(),
      if (caption != null && caption!.trim().isNotEmpty)
        'caption': caption!.trim(),
      'uploaded_at': uploadedAt.toIso8601String(),
      'is_encrypted': isEncrypted,
      'is_hidden': isHidden,
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
    };
  }

  SecretMediaModel copyWith({
    String? id,
    String? coupleId,
    String? uploadedById,
    String? mediaType,
    String? mediaUrl,
    String? thumbnail,
    String? caption,
    DateTime? uploadedAt,
    bool? isEncrypted,
    bool? isHidden,
    DateTime? deletedAt,
  }) {
    return SecretMediaModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      uploadedById: uploadedById ?? this.uploadedById,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      caption: caption ?? this.caption,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isHidden: isHidden ?? this.isHidden,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
