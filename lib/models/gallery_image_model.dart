class GalleryImageModel {
  final String id;
  final String folderId;
  final String coupleId;
  final String uploadedById;
  final String imageUrl;
  final String? fileId;
  final String? caption;
  final DateTime? takenAt;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const GalleryImageModel({
    required this.id,
    required this.folderId,
    required this.coupleId,
    required this.uploadedById,
    required this.imageUrl,
    this.fileId,
    this.caption,
    this.takenAt,
    required this.createdAt,
    this.deletedAt,
  });

  factory GalleryImageModel.fromJson(Map<String, dynamic> json) {
    return GalleryImageModel(
      id: json['id'] as String? ?? '',
      folderId: json['folder_id'] as String? ?? '',
      coupleId: json['couple_id'] as String? ?? '',
      uploadedById: json['uploaded_by_id'] as String? ?? '',
      imageUrl: (json['image_url'] as String? ?? '').trim(),
      fileId: json['file_id'] as String?,
      caption: json['caption'] as String?,
      takenAt: json['taken_at'] != null
          ? DateTime.tryParse(json['taken_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folder_id': folderId,
      'couple_id': coupleId,
      'uploaded_by_id': uploadedById,
      'image_url': imageUrl,
      if (fileId != null) 'file_id': fileId,
      if (caption != null && caption!.trim().isNotEmpty)
        'caption': caption!.trim(),
      if (takenAt != null) 'taken_at': takenAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
    };
  }

  GalleryImageModel copyWith({
    String? id,
    String? folderId,
    String? coupleId,
    String? uploadedById,
    String? imageUrl,
    String? fileId,
    String? caption,
    DateTime? takenAt,
    DateTime? createdAt,
    DateTime? deletedAt,
    bool clearTakenAt = false,
  }) {
    return GalleryImageModel(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      coupleId: coupleId ?? this.coupleId,
      uploadedById: uploadedById ?? this.uploadedById,
      imageUrl: imageUrl ?? this.imageUrl,
      fileId: fileId ?? this.fileId,
      caption: caption ?? this.caption,
      takenAt: clearTakenAt ? null : (takenAt ?? this.takenAt),
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
