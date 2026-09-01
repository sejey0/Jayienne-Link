import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/milestone_model.dart';
import 'offline_storage_service.dart';
import 'supabase_data_service.dart';

/// Database and Storage Service Layer for Couple Milestones & Relationship Analytics
class SupabaseMilestoneService {
  static const String _tableName = 'relationship_milestones';
  static const String _couplesTable = 'couples';
  static const String _heartbeatsTable = 'heartbeats';
  static const String _photosTable = 'photo_messages';
  static const String _storageBucket = 'milestones';

  final SupabaseClient _client = SupabaseDataService.client;

  /// Fetch all relationship milestones for a couple, sorted by eventDate DESC
  Future<List<MilestoneModel>> getMilestones(String coupleId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .order('event_date', ascending: false);

      final list = (response as List)
          .map((data) => MilestoneModel.fromJson(data as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Fetch error on $_tableName, fallback to view: $e');
      try {
        final response = await _client
            .from('milestones')
            .select()
            .eq('couple_id', coupleId)
            .order('event_date', ascending: false);

        return (response as List)
            .map((data) => MilestoneModel.fromJson(data as Map<String, dynamic>))
            .toList();
      } catch (err) {
        debugPrint('[SupabaseMilestoneService] Secondary fetch error: $err');
        return [];
      }
    }
  }

  /// Create a new milestone with optional photo attachment uploaded to Supabase Storage
  Future<MilestoneModel?> addMilestone({
    required MilestoneModel milestone,
    File? imageFile,
  }) async {
    try {
      String? photoUrl;

      // 1. Upload photo if provided
      if (imageFile != null) {
        final fileExt = imageFile.path.split('.').last;
        final fileName =
            '${milestone.coupleId}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        try {
          await _client.storage.from(_storageBucket).upload(
                fileName,
                imageFile,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
              );
          photoUrl = _client.storage.from(_storageBucket).getPublicUrl(fileName);
        } catch (storageError) {
          debugPrint('[SupabaseMilestoneService] Storage upload failed: $storageError');
          throw Exception('Photo upload failed: $storageError');
        }
      }

      final milestoneToInsert = milestone.copyWith(photoUrl: photoUrl);
      
      // 2. Insert into relationship_milestones
      Map<String, dynamic> insertPayload = milestoneToInsert.toInsertJson();
      
      // Fallback: Ensure created_by is explicitly set to authenticated user ID
      final currentAuthUser = _client.auth.currentUser;
      if (currentAuthUser != null) {
        insertPayload['created_by'] = currentAuthUser.id;
      }

      final response = await _client
          .from(_tableName)
          .insert(insertPayload)
          .select()
          .single();

      return MilestoneModel.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Error adding milestone: $e');
      rethrow;
    }
  }

  /// Delete a milestone entry by ID
  Future<bool> deleteMilestone(String milestoneId) async {
    try {
      await _client.from(_tableName).delete().eq('id', milestoneId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Error deleting milestone: $e');
      return false;
    }
  }

  /// Save or update the official anniversary date for a couple
  Future<bool> updateAnniversaryDate(String coupleId, DateTime anniversaryDate) async {
    try {
      await _client.from(_couplesTable).update({
        'anniversary': anniversaryDate.toIso8601String(),
      }).eq('id', coupleId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Error updating anniversary date: $e');
      return false;
    }
  }

  /// Fetch couple's anniversary date from couples table (fallback to created_at)
  Future<DateTime?> fetchAnniversaryDate(String coupleId) async {
    try {
      final response = await _client
          .from(_couplesTable)
          .select('anniversary, created_at')
          .eq('id', coupleId)
          .maybeSingle();

      if (response != null) {
        if (response['anniversary'] != null) {
          return DateTime.parse(response['anniversary'] as String);
        } else if (response['created_at'] != null) {
          return DateTime.parse(response['created_at'] as String);
        }
      }
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Error fetching anniversary date: $e');
    }
    return null;
  }

  /// Calculate cumulative couple relationship analytics statistics
  Future<CoupleStatsModel> fetchCoupleStats(
    String coupleId, {
    String? userId,
    String? partnerId,
  }) async {
    int totalTouches = 0;
    int photosShared = 0;
    int streakDays = 0;
    double distanceTraveledKm = 0.0;

    try {
      // 1. Total touches sent in couple
      final touchCountRes = await _client
          .from(_heartbeatsTable)
          .select('id')
          .eq('couple_id', coupleId)
          .count(CountOption.exact);
      totalTouches = touchCountRes.count;
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Touch count query notice: $e');
    }

    try {
      // 2. Photos shared in couple
      final photoCountRes = await _client
          .from(_photosTable)
          .select('id')
          .eq('couple_id', coupleId)
          .count(CountOption.exact);
      photosShared = photoCountRes.count;
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Photo count query notice: $e');
    }

    try {
      // 3. Distance traveled calculation between location records
      final currentUserId = SupabaseDataService.currentUserId;
      if (currentUserId != null) {
        final locationRecords = await OfflineStorageService.instance.getLocationHistory(
          currentUserId,
          limit: 200,
        );

        if (locationRecords.length >= 2) {
          const distanceCalc = Distance();
          double metersTotal = 0.0;
          for (int i = 0; i < locationRecords.length - 1; i++) {
            final lat1 = locationRecords[i].latitude;
            final lng1 = locationRecords[i].longitude;
            final lat2 = locationRecords[i + 1].latitude;
            final lng2 = locationRecords[i + 1].longitude;

            final d = distanceCalc.as(
              LengthUnit.Meter,
              LatLng(lat1, lng1),
              LatLng(lat2, lng2),
            );
            if (d < 100000) { // filter GPS anomaly jumps (>100km per point)
              metersTotal += d;
            }
          }
          distanceTraveledKm = metersTotal / 1000.0;
        }
      }
    } catch (e) {
      debugPrint('[SupabaseMilestoneService] Distance calc notice: $e');
    }

    // 4. Streak calculation based on recent touch/photo activity
    streakDays = (totalTouches > 0 || photosShared > 0) ? (totalTouches / 5).clamp(1, 999).round() : 0;

    return CoupleStatsModel(
      totalTouches: totalTouches,
      photosShared: photosShared,
      streakDays: streakDays,
      distanceTraveledKm: double.parse(distanceTraveledKm.toStringAsFixed(1)),
    );
  }
}
