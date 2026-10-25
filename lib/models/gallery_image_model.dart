class GalleryImageModel {
  final String id;
  final String folderId;
  final String coupleId;
  final String uploadedById;
  final String imageUrl;
  final String? fileId;
  final String? caption;
  final String mediaType; // 'image' or 'video'
  final DateTime? takenAt;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final String section;

  const GalleryImageModel({
    required this.id,
    required this.folderId,
    required this.coupleId,
    required this.uploadedById,
    required this.imageUrl,
    this.fileId,
    this.caption,
    this.mediaType = 'image',
    this.takenAt,
    required this.createdAt,
    this.deletedAt,
    this.section = 'us',
  });

  bool get isVideo {
    if (mediaType.toLowerCase() == 'video') return true;
    final lower = imageUrl.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.mkv') ||
        lower.contains('.webm') ||
        lower.contains('.m4v');
  }

  static bool _isUrlVideo(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.mkv') ||
        lower.contains('.webm') ||
        lower.contains('.m4v');
  }

  static String parseSection(String? rawSection, String? cap) {
    if (rawSection != null && rawSection.trim().isNotEmpty) {
      return rawSection.trim().toLowerCase();
    }
    if (cap != null) {
      if (cap.contains('[section:my_pictures]')) return 'my_pictures';
      if (cap.contains('[section:partner]')) return 'partner';
      if (cap.contains('[section:us]')) return 'us';
    }
    return 'us'; // Existing photos default to 'us'
  }

  String get cleanCaption {
    if (caption == null) return '';
    return caption!
        .replaceAll(RegExp(r'\[section:(us|my_pictures|partner)\]'), '')
        .trim();
  }

  /// Returns the section from the perspective of [currentUserId].
  /// Images uploaded by the partner in 'my_pictures' appear in this user's 'partner' section, and vice versa.
  String effectiveSection(String currentUserId) {
    if (section == 'us') return 'us';
    if (currentUserId.isEmpty || uploadedById.isEmpty) return section;
    if (uploadedById == currentUserId) {
      return section;
    } else {
      if (section == 'my_pictures') return 'partner';
      if (section == 'partner') return 'my_pictures';
      return section;
    }
  }

  factory GalleryImageModel.fromJson(Map<String, dynamic> json) {
    final url = (json['image_url'] as String? ?? '').trim();
    final type = (json['media_type'] as String?) ?? (_isUrlVideo(url) ? 'video' : 'image');

    return GalleryImageModel(
      id: json['id'] as String? ?? '',
      folderId: json['folder_id'] as String? ?? '',
      coupleId: json['couple_id'] as String? ?? '',
      uploadedById: json['uploaded_by_id'] as String? ?? '',
      imageUrl: url,
      fileId: json['file_id'] as String?,
      caption: json['caption'] as String?,
      mediaType: type,
      takenAt: json['taken_at'] != null
          ? DateTime.tryParse(json['taken_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      section: parseSection(json['section'] as String?, json['caption'] as String?),
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
      'media_type': mediaType,
      if (takenAt != null) 'taken_at': takenAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      'section': section,
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
    String? mediaType,
    DateTime? takenAt,
    DateTime? createdAt,
    DateTime? deletedAt,
    String? section,
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
      mediaType: mediaType ?? this.mediaType,
      takenAt: clearTakenAt ? null : (takenAt ?? this.takenAt),
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      section: section ?? this.section,
    );
  }
}
