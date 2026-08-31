import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social_link_model.dart';
import 'supabase_data_service.dart';

class SupabaseLinksService {
  static const String _tableName = 'couple_links';
  static const String _localCachePrefix = 'couple_links_';

  final SupabaseClient _client = SupabaseDataService.client;

  /// Fetch all social links for a given couple
  Future<List<SocialLinkModel>> getCoupleLinks(String coupleId) async {
    final cachedLinks = await getCachedLinks(coupleId);

    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false);

      final remoteLinks = (response as List)
          .map((item) => SocialLinkModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Merge remote links with any locally added unsynced links
      final Map<String, SocialLinkModel> mergedMap = {};
      for (final r in remoteLinks) {
        mergedMap[r.id] = r;
      }
      for (final c in cachedLinks) {
        if (!mergedMap.containsKey(c.id)) {
          mergedMap[c.id] = c;
        }
      }

      final mergedList = mergedMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Persist merged set into local storage
      await _cacheLocally(coupleId, mergedList);
      return mergedList;
    } catch (e) {
      debugPrint('[SupabaseLinksService] Remote fetch error ($e), falling back to local cache.');
      return cachedLinks;
    }
  }

  /// Add a new social link
  Future<SocialLinkModel> addLink(SocialLinkModel link) async {
    // 1. Immediately persist to local cache first so it is never lost
    await _saveSingleToCache(link.coupleId, link);

    try {
      final payload = link.toInsertJson();
      final currentAuthUser = _client.auth.currentUser;
      if (currentAuthUser != null && (payload['user_id'] == null || payload['user_id'] == '')) {
        payload['user_id'] = currentAuthUser.id;
      }

      final response = await _client
          .from(_tableName)
          .insert(payload)
          .select()
          .single();

      final createdLink = SocialLinkModel.fromJson(response);
      // Replace temporary id in local cache with the authoritative one from Supabase
      final cached = await getCachedLinks(link.coupleId);
      cached.removeWhere((l) => l.id == link.id || l.id == createdLink.id);
      cached.insert(0, createdLink);
      await _cacheLocally(link.coupleId, cached);

      return createdLink;
    } catch (e) {
      debugPrint('[SupabaseLinksService] Remote insert error: $e. Saved safely in local cache.');
      return link;
    }
  }

  /// Update an existing social link
  Future<SocialLinkModel> updateLink(SocialLinkModel link) async {
    await _updateSingleInCache(link.coupleId, link);

    try {
      final payload = link.toJson();
      payload['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from(_tableName)
          .update(payload)
          .eq('id', link.id)
          .select()
          .single();

      final updated = SocialLinkModel.fromJson(response);
      await _updateSingleInCache(link.coupleId, updated);
      return updated;
    } catch (e) {
      debugPrint('[SupabaseLinksService] Remote update error: $e. Updating local cache.');
      return link;
    }
  }

  /// Delete a social link
  Future<bool> deleteLink(String linkId, String coupleId) async {
    await _deleteFromCache(coupleId, linkId);

    try {
      await _client
          .from(_tableName)
          .delete()
          .eq('id', linkId);

      return true;
    } catch (e) {
      debugPrint('[SupabaseLinksService] Remote delete error: $e. Deleted from local cache.');
      return true;
    }
  }

  /// Local SharedPreferences Cache Helpers
  Future<List<SocialLinkModel>> getCachedLinks(String coupleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localCachePrefix$coupleId';
      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List decoded = jsonDecode(jsonString) as List;
      return decoded
          .map((item) => SocialLinkModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseLinksService] Error reading cache: $e');
      return [];
    }
  }

  Future<void> _cacheLocally(String coupleId, List<SocialLinkModel> links) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localCachePrefix$coupleId';
      final jsonString = jsonEncode(links.map((l) => l.toJson()).toList());
      await prefs.setString(key, jsonString);
    } catch (e) {
      debugPrint('[SupabaseLinksService] Error saving cache: $e');
    }
  }

  Future<void> _saveSingleToCache(String coupleId, SocialLinkModel link) async {
    final existing = await getCachedLinks(coupleId);
    existing.removeWhere((l) => l.id == link.id);
    existing.insert(0, link);
    await _cacheLocally(coupleId, existing);
  }

  Future<void> _updateSingleInCache(String coupleId, SocialLinkModel link) async {
    final existing = await getCachedLinks(coupleId);
    final index = existing.indexWhere((l) => l.id == link.id);
    if (index >= 0) {
      existing[index] = link;
    } else {
      existing.insert(0, link);
    }
    await _cacheLocally(coupleId, existing);
  }

  Future<void> _deleteFromCache(String coupleId, String linkId) async {
    final existing = await getCachedLinks(coupleId);
    existing.removeWhere((l) => l.id == linkId);
    await _cacheLocally(coupleId, existing);
  }
}
