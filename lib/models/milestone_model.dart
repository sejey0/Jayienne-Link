import 'package:flutter/material.dart';

/// Milestone categories for relationship memories
enum MilestoneCategory {
  dateTogether,
  anniversary,
  trip,
  specialMoment,
  milestone,
  custom,
  other;

  String get value {
    switch (this) {
      case MilestoneCategory.dateTogether:
        return 'date_together';
      case MilestoneCategory.anniversary:
        return 'anniversary';
      case MilestoneCategory.trip:
        return 'trip';
      case MilestoneCategory.specialMoment:
        return 'special_moment';
      case MilestoneCategory.milestone:
        return 'milestone';
      case MilestoneCategory.custom:
        return 'custom';
      case MilestoneCategory.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case MilestoneCategory.dateTogether:
        return 'Date Together';
      case MilestoneCategory.anniversary:
        return 'Anniversary';
      case MilestoneCategory.trip:
        return 'Trip & Travel';
      case MilestoneCategory.specialMoment:
        return 'Special Moment';
      case MilestoneCategory.milestone:
        return 'Milestone';
      case MilestoneCategory.custom:
        return 'Custom';
      case MilestoneCategory.other:
        return 'Memory';
    }
  }

  IconData get icon {
    switch (this) {
      case MilestoneCategory.dateTogether:
        return Icons.favorite_rounded;
      case MilestoneCategory.anniversary:
        return Icons.cake_rounded;
      case MilestoneCategory.trip:
        return Icons.flight_takeoff_rounded;
      case MilestoneCategory.specialMoment:
        return Icons.star_rounded;
      case MilestoneCategory.milestone:
        return Icons.emoji_events_rounded;
      case MilestoneCategory.custom:
        return Icons.auto_awesome_rounded;
      case MilestoneCategory.other:
        return Icons.photo_library_rounded;
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case MilestoneCategory.dateTogether:
        return const [Color(0xFFFF5252), Color(0xFFD81B60)];
      case MilestoneCategory.anniversary:
        return const [Color(0xFFFF4081), Color(0xFFAB47BC)];
      case MilestoneCategory.trip:
        return const [Color(0xFF536DFE), Color(0xFF7C4DFF)];
      case MilestoneCategory.specialMoment:
        return const [Color(0xFFEC407A), Color(0xFF8E24AA)];
      case MilestoneCategory.milestone:
        return const [Color(0xFFE91E63), Color(0xFF7B1FA2)];
      case MilestoneCategory.custom:
        return const [Color(0xFFFF758C), Color(0xFFA18CD1)];
      case MilestoneCategory.other:
        return const [Color(0xFFF06292), Color(0xFF9C27B0)];
    }
  }

  Color get color => gradientColors.first;

  static MilestoneCategory fromString(String? val) {
    if (val != null && val.startsWith('custom:')) {
      return MilestoneCategory.custom;
    }
    switch (val) {
      case 'date_together':
      case 'first_date':
        return MilestoneCategory.dateTogether;
      case 'anniversary':
        return MilestoneCategory.anniversary;
      case 'trip':
        return MilestoneCategory.trip;
      case 'special_moment':
        return MilestoneCategory.specialMoment;
      case 'milestone':
        return MilestoneCategory.milestone;
      case 'custom':
        return MilestoneCategory.custom;
      default:
        return MilestoneCategory.other;
    }
  }
}

/// Data model representing a relationship milestone / memory entry
class MilestoneModel {
  final String? id;
  final String coupleId;
  final String createdById;
  final String title;
  final String? description;
  final MilestoneCategory category;
  final String? customCategoryName;
  final DateTime? eventDate;
  final String? photoUrl;
  final DateTime createdAt;

  MilestoneModel({
    this.id,
    required this.coupleId,
    required this.createdById,
    required this.title,
    this.description,
    this.category = MilestoneCategory.specialMoment,
    this.customCategoryName,
    this.eventDate,
    this.photoUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Effective date for timeline ordering and chronological sorting
  DateTime get effectiveDate => eventDate ?? createdAt;

  String get displayCategoryLabel {
    if (category == MilestoneCategory.custom &&
        customCategoryName != null &&
        customCategoryName!.trim().isNotEmpty) {
      return customCategoryName!.trim();
    }
    return category.label;
  }

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'] as String?;
    final isCustom = rawCategory != null && rawCategory.startsWith('custom:');
    final customName = isCustom
        ? rawCategory.substring(7)
        : (json['custom_category'] as String? ?? json['custom_category_name'] as String?);

    return MilestoneModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      createdById: json['created_by'] as String? ?? json['created_by_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Special Memory',
      description: json['description'] as String?,
      category: MilestoneCategory.fromString(rawCategory),
      customCategoryName: customName,
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'] as String)
          : null,
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final categoryStr = category == MilestoneCategory.custom &&
            customCategoryName != null &&
            customCategoryName!.trim().isNotEmpty
        ? 'custom:${customCategoryName!.trim()}'
        : category.value;

    return {
      if (id != null) 'id': id,
      'couple_id': coupleId,
      'created_by': createdById,
      'created_by_id': createdById,
      'title': title,
      if (description != null) 'description': description,
      'category': categoryStr,
      if (customCategoryName != null) 'custom_category': customCategoryName,
      if (eventDate != null) 'event_date': eventDate!.toIso8601String(),
      if (photoUrl != null) 'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    final categoryStr = category == MilestoneCategory.custom &&
            customCategoryName != null &&
            customCategoryName!.trim().isNotEmpty
        ? 'custom:${customCategoryName!.trim()}'
        : category.value;

    return {
      'couple_id': coupleId,
      'created_by': createdById,
      'title': title,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'category': categoryStr,
      'event_date': (eventDate ?? createdAt).toIso8601String(),
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }

  MilestoneModel copyWith({
    String? id,
    String? coupleId,
    String? createdById,
    String? title,
    String? description,
    MilestoneCategory? category,
    String? customCategoryName,
    DateTime? eventDate,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return MilestoneModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      createdById: createdById ?? this.createdById,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      customCategoryName: customCategoryName ?? this.customCategoryName,
      eventDate: eventDate ?? this.eventDate,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Statistics model for couple relationship metrics
class CoupleStatsModel {
  final int totalTouches;
  final int photosShared;
  final int streakDays;
  final double distanceTraveledKm;

  const CoupleStatsModel({
    this.totalTouches = 0,
    this.photosShared = 0,
    this.streakDays = 0,
    this.distanceTraveledKm = 0.0,
  });
}
