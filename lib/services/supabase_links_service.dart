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
    List<SocialLinkModel> remoteLinks = [];

    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false);

      remoteLinks = (response as List)
          .map((item) => SocialLinkModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Update local cache
      await _cacheLocally(coupleId, remoteLinks);
      return remoteLinks;
    } catch (e) {
      debugPrint('[SupabaseLinksService] Remote fetch error ($e), falling back to local cache.');
      return await getCachedLinks(coupleId);
    }
  }

  /// Add a new social link
  Future<SocialLinkModel> addLink(SocialLinkModel link) async {
    try {
      final payload = link.toInsertJson();
      final currentAuthUser = _client.auth.currentUser;
      if (currentAuthUser != null && payload['user_id'] == '') {
        payload['user_id'] = currentAuthUser.id;
      }

      final response = await _client
          .from(_tableName)
          .insert(payload)
          .select()
          .single();

      final createdLink = SocialLinkModel.fromJson(response);
      await _saveSingleToCache(link.coupleId, createdLink);
      return createdLink;
    } catch (e) {
      debugPrint('[SupabaseLinksService] Remote insert error: $e. Storing in local cache.');
      // Local fallback with provided ID
      await _saveSingleToCache(link.coupleId, link);
      return link;
    }
  }

  /// Update an existing social link
  Future<SocialLinkModel> updateLink(SocialLinkModel link) async {
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
      await _updateSingleInCache(link.coupleId, link);
      return link;
    }
  }

  /// Delete a social link
  Future<bool> deleteLink(String linkId, String coupleId) async {
    try {
      await _client
          .from(_tableName)
          .delete()
          .eq('id', linkId);

      await _deleteFromCache(coupleId, linkId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseLinksService] Remote delete error: $e. Deleting from local cache.');
      await _deleteFromCache(coupleId, linkId);
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
