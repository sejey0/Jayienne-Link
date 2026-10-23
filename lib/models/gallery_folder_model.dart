class GalleryFolderModel {
  final String id;
  final String coupleId;
  final String name;
  final String? description;
  final String? coverImageUrl;
  final String createdById;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int imageCount;

  const GalleryFolderModel({
    required this.id,
    required this.coupleId,
    required this.name,
    this.description,
    this.coverImageUrl,
    required this.createdById,
    required this.createdAt,
    required this.updatedAt,
    this.imageCount = 0,
  });

  factory GalleryFolderModel.fromJson(Map<String, dynamic> json) {
    // Handle media/image count whether aggregate was returned or raw
    int count = 0;
    if (json['media_aggregate'] != null &&
        json['media_aggregate']['aggregate'] != null) {
      count = json['media_aggregate']['aggregate']['count'] as int? ?? 0;
    } else if (json['images_aggregate'] != null &&
        json['images_aggregate']['aggregate'] != null) {
      count = json['images_aggregate']['aggregate']['count'] as int? ?? 0;
    } else if (json['image_count'] != null) {
      count = (json['image_count'] as num).toInt();
    }

    return GalleryFolderModel(
      id: json['id'] as String? ?? '',
      coupleId: json['couple_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Album',
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      createdById: json['created_by_id'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      imageCount: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'name': name,
      if (description != null) 'description': description,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      'created_by_id': createdById,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  GalleryFolderModel copyWith({
    String? id,
    String? coupleId,
    String? name,
    String? description,
    String? coverImageUrl,
    String? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? imageCount,
  }) {
    return GalleryFolderModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageCount: imageCount ?? this.imageCount,
    );
  }
}
