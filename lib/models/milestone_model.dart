import 'package:flutter/material.dart';

/// Milestone categories for relationship memories
enum MilestoneCategory {
  firstDate,
  anniversary,
  trip,
  specialMoment,
  milestone,
  other;

  String get value {
    switch (this) {
      case MilestoneCategory.firstDate:
        return 'first_date';
      case MilestoneCategory.anniversary:
        return 'anniversary';
      case MilestoneCategory.trip:
        return 'trip';
      case MilestoneCategory.specialMoment:
        return 'special_moment';
      case MilestoneCategory.milestone:
        return 'milestone';
      case MilestoneCategory.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case MilestoneCategory.firstDate:
        return 'First Date';
      case MilestoneCategory.anniversary:
        return 'Anniversary';
      case MilestoneCategory.trip:
        return 'Trip & Travel';
      case MilestoneCategory.specialMoment:
        return 'Special Moment';
      case MilestoneCategory.milestone:
        return 'Milestone';
      case MilestoneCategory.other:
        return 'Memory';
    }
  }

  IconData get icon {
    switch (this) {
      case MilestoneCategory.firstDate:
        return Icons.favorite_rounded;
      case MilestoneCategory.anniversary:
        return Icons.cake_rounded;
      case MilestoneCategory.trip:
        return Icons.flight_takeoff_rounded;
      case MilestoneCategory.specialMoment:
        return Icons.star_rounded;
      case MilestoneCategory.milestone:
        return Icons.emoji_events_rounded;
      case MilestoneCategory.other:
        return Icons.photo_library_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MilestoneCategory.firstDate:
        return const Color(0xFFFF4B72); // Soft Rose / Magenta
      case MilestoneCategory.anniversary:
        return const Color(0xFFFF9F43); // Warm Gold / Amber
      case MilestoneCategory.trip:
        return const Color(0xFF54A0FF); // Sky Blue
      case MilestoneCategory.specialMoment:
        return const Color(0xFF9C88FF); // Lavender / Purple
      case MilestoneCategory.milestone:
        return const Color(0xFF1DD1A1); // Emerald Teal
      case MilestoneCategory.other:
        return const Color(0xFF8395A7); // Slate Grey
    }
  }

  static MilestoneCategory fromString(String? val) {
    switch (val) {
      case 'first_date':
        return MilestoneCategory.firstDate;
      case 'anniversary':
        return MilestoneCategory.anniversary;
      case 'trip':
        return MilestoneCategory.trip;
      case 'special_moment':
        return MilestoneCategory.specialMoment;
      case 'milestone':
        return MilestoneCategory.milestone;
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
  final DateTime eventDate;
  final String? photoUrl;
  final DateTime createdAt;

  MilestoneModel({
    this.id,
    required this.coupleId,
    required this.createdById,
    required this.title,
    this.description,
    this.category = MilestoneCategory.specialMoment,
    required this.eventDate,
    this.photoUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    return MilestoneModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String? ?? '',
      createdById: json['created_by'] as String? ?? json['created_by_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Special Memory',
      description: json['description'] as String?,
      category: MilestoneCategory.fromString(json['category'] as String?),
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : DateTime.now(),
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'couple_id': coupleId,
      'created_by': createdById,
      'created_by_id': createdById,
      'title': title,
      if (description != null) 'description': description,
      'category': category.value,
      'event_date': eventDate.toIso8601String(),
      if (photoUrl != null) 'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'couple_id': coupleId,
      'created_by': createdById,
      'title': title,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'category': category.value,
      'event_date': eventDate.toIso8601String(),
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
