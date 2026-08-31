import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social_link_model.dart';
import '../services/supabase_links_service.dart';

class CoupleLinksProvider extends ChangeNotifier {
  final SupabaseLinksService _service;
  RealtimeChannel? _realtimeChannel;
  bool _disposed = false;

  CoupleLinksProvider([SupabaseLinksService? service])
      : _service = service ?? SupabaseLinksService();

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  List<SocialLinkModel> _links = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  String? _coupleId;
  String? _userId;
  String? _partnerId;

  List<SocialLinkModel> get links => List.unmodifiable(_links);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get coupleId => _coupleId;
  String? get userId => _userId;
  String? get partnerId => _partnerId;

  /// Initialize provider with couple and user context
  Future<void> initialize({
    required String coupleId,
    required String userId,
    String? partnerId,
  }) async {
    final hasChanged = _coupleId != coupleId || _userId != userId || _partnerId != partnerId;
    _coupleId = coupleId;
    _userId = userId;
    _partnerId = partnerId;

    // Immediately load from local cache if memory list is empty
    if (_links.isEmpty) {
      final cached = await _service.getCachedLinks(coupleId);
      if (cached.isNotEmpty) {
        _links = cached;
        notifyListeners();
      }
    }

    // Subscribe to live Realtime updates from Supabase
    if (hasChanged || _realtimeChannel == null) {
      _setupRealtimeChannel(coupleId);
    }

    if (hasChanged || _links.isEmpty) {
      await refreshLinks();
    }
  }

  void _setupRealtimeChannel(String coupleId) {
    // Remove any existing channel first
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }

    _realtimeChannel = Supabase.instance.client
        .channel('couple_links:$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'couple_links',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: (payload) {
            debugPrint('[CoupleLinksProvider] Realtime change: ${payload.eventType}');
            // Re-fetch from Supabase to get authoritative sorted list
            refreshLinks();
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[CoupleLinksProvider] Channel status: $status ${error ?? ''}');
        });
  }

  /// Reset / clear state on sign out
  void clear() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    _links = [];
    _isLoading = false;
    _isSaving = false;
    _error = null;
    _coupleId = null;
    _userId = null;
    _partnerId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    super.dispose();
  }

  /// Fetch all links from service
  Future<void> refreshLinks() async {
    final currentCoupleId = _coupleId;
    if (currentCoupleId == null || currentCoupleId.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _service.getCoupleLinks(currentCoupleId);
      _links = fetched;
    } catch (e) {
      _error = 'Failed to load links: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get only current user's links
  List<SocialLinkModel> get myLinks {
    if (_userId == null) return [];
    return _links.where((l) => l.userId == _userId).toList();
  }

  /// Get only partner's links
  List<SocialLinkModel> get partnerLinks {
    if (_userId == null) return [];
    return _links.where((l) => l.userId != _userId).toList();
  }

  /// Filter links by platform
  List<SocialLinkModel> filterByPlatform(SocialPlatform platform) {
    return _links.where((l) => l.socialPlatform == platform).toList();
  }

  /// Add a new social link
  Future<SocialLinkModel?> addLink({
    required SocialPlatform platform,
    required String usernameOrUrl,
    required String title,
    String? userDisplayName,
    String? userPhotoUrl,
  }) async {
    final currentCoupleId = _coupleId;
    final currentUserId = _userId;
    if (currentCoupleId == null || currentUserId == null) {
      _error = 'User or couple information missing.';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final formattedUrl = platform.formatUrl(usernameOrUrl);
      final rawHandle = usernameOrUrl.trim().startsWith('@')
          ? usernameOrUrl.trim().substring(1)
          : usernameOrUrl.trim();

      final newLink = SocialLinkModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        coupleId: currentCoupleId,
        userId: currentUserId,
        userDisplayName: userDisplayName,
        userPhotoUrl: userPhotoUrl,
        platform: platform.id,
        title: title.trim().isNotEmpty ? title.trim() : platform.displayName,
        username: rawHandle,
        url: formattedUrl,
        createdAt: DateTime.now(),
      );

      final created = await _service.addLink(newLink);
      _links.removeWhere((l) => l.id == created.id || l.id == newLink.id);
      _links.insert(0, created);
      _isSaving = false;
      notifyListeners();
      return created;
    } catch (e) {
      _error = 'Failed to add link: $e';
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  /// Update an existing social link
  Future<bool> updateLink({
    required String linkId,
    required SocialPlatform platform,
    required String usernameOrUrl,
    required String title,
  }) async {
    final currentCoupleId = _coupleId;
    if (currentCoupleId == null) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final existingIndex = _links.indexWhere((l) => l.id == linkId);
      if (existingIndex < 0) throw Exception('Link not found');

      final existing = _links[existingIndex];
      final formattedUrl = platform.formatUrl(usernameOrUrl);
      final rawHandle = usernameOrUrl.trim().startsWith('@')
          ? usernameOrUrl.trim().substring(1)
          : usernameOrUrl.trim();

      final updatedLink = existing.copyWith(
        platform: platform.id,
        title: title.trim().isNotEmpty ? title.trim() : platform.displayName,
        username: rawHandle,
        url: formattedUrl,
        updatedAt: DateTime.now(),
      );

      final updated = await _service.updateLink(updatedLink);
      _links[existingIndex] = updated;
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update link: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a social link
  Future<bool> deleteLink(String linkId) async {
    final currentCoupleId = _coupleId;
    if (currentCoupleId == null) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _service.deleteLink(linkId, currentCoupleId);
      if (success) {
        _links.removeWhere((l) => l.id == linkId);
      }
      _isSaving = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to delete link: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
