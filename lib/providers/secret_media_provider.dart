import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/secret_media_model.dart';
import '../services/supabase_secret_media_service.dart';

class SecretMediaProvider extends ChangeNotifier {
  final SupabaseSecretMediaService _service;
  bool _disposed = false;
  bool _isVaultHiddenFromFeatures = false;

  SecretMediaProvider(this._service) {
    loadVaultSettings();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  List<SecretMediaModel> _sharedMedia = [];
  List<SecretMediaModel> _hiddenMedia = [];
  StreamSubscription<List<SecretMediaModel>>? _mediaSubscription;

  String? _userId;
  String? _coupleId;

  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  bool _showHiddenVault = false;
  bool _isVaultUnlockedSession = false;

  // Getters
  List<SecretMediaModel> get sharedMedia => List.unmodifiable(_sharedMedia);
  List<SecretMediaModel> get allMedia => List.unmodifiable(_sharedMedia);
  List<SecretMediaModel> get hiddenMedia => List.unmodifiable(_hiddenMedia);
  List<SecretMediaModel> get displayedMedia =>
      _showHiddenVault ? hiddenMedia : sharedMedia;

  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  bool get showHiddenVault => _showHiddenVault;
  bool get isVaultUnlockedSession => _isVaultUnlockedSession;
  bool get isVaultHiddenFromFeatures => _isVaultHiddenFromFeatures;
  String? get userId => _userId;

  String _getVaultPrefKey([String? uid]) {
    final targetUid = (uid != null && uid.isNotEmpty) ? uid : _userId;
    if (targetUid != null && targetUid.isNotEmpty) {
      return 'is_vault_hidden_from_features_$targetUid';
    }
    return 'is_vault_hidden_from_features';
  }

  Future<void> loadVaultSettings([String? userId]) async {
    try {
      if (userId != null && userId.isNotEmpty) {
        _userId = userId;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = _getVaultPrefKey(userId);
      if (prefs.containsKey(key)) {
        _isVaultHiddenFromFeatures = prefs.getBool(key) ?? false;
      } else if (prefs.containsKey('is_vault_hidden_from_features')) {
        _isVaultHiddenFromFeatures =
            prefs.getBool('is_vault_hidden_from_features') ?? false;
      } else {
        _isVaultHiddenFromFeatures = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading vault settings: $e');
    }
  }

  Future<void> setVaultHiddenFromFeatures(bool hidden, {String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      _userId = userId;
    }
    _isVaultHiddenFromFeatures = hidden;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getVaultPrefKey(userId);
      await prefs.setBool(key, hidden);
    } catch (e) {
      debugPrint('Error saving vault settings: $e');
    }
  }

  void unlockVaultSession() {
    _isVaultUnlockedSession = true;
    notifyListeners();
  }

  void lockVaultSession() {
    _isVaultUnlockedSession = false;
    notifyListeners();
  }

  int get totalMediaCount => _sharedMedia.length + _hiddenMedia.length;
  int get sharedMediaCount => _sharedMedia.length;
  int get hiddenMediaCount => _hiddenMedia.length;

  /// Safely resolves the display/stream URL for a given media item (fallback for plain storage URLs)
  String resolveMediaUrl(SecretMediaModel media) {
    final url = media.mediaUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return media.displayUrl;
  }

  /// Evicts removed or deleted media URLs and thumbnails from Flutter image cache so no traces remain
  void _evictRemovedMediaFromCache(List<SecretMediaModel> currentActiveMedia) {
    try {
      final activeUrls = currentActiveMedia
          .map((m) => m.displayUrl)
          .where((u) => u.isNotEmpty)
          .toSet();
      final activeThumbnails = currentActiveMedia
          .map((m) => m.thumbnail ?? '')
          .where((u) => u.isNotEmpty)
          .toSet();

      for (final old in [..._sharedMedia, ..._hiddenMedia]) {
        if (old.displayUrl.isNotEmpty && !activeUrls.contains(old.displayUrl)) {
          PaintingBinding.instance.imageCache.evict(NetworkImage(old.displayUrl));
        }
        if (old.thumbnail != null &&
            old.thumbnail!.isNotEmpty &&
            !activeThumbnails.contains(old.thumbnail)) {
          PaintingBinding.instance.imageCache.evict(NetworkImage(old.thumbnail!));
        }
      }
    } catch (e) {
      debugPrint('Error evicting image cache: $e');
    }
  }

  /// Sets up real-time stream subscription to automatically sync deletions and additions from database
  void _setupRealtimeSubscription() {
    _mediaSubscription?.cancel();
    if (_coupleId == null || _coupleId!.isEmpty) return;

    try {
      _mediaSubscription = _service.streamSecretMedia(_coupleId!).listen(
        (allData) {
          debugPrint('SecretMediaProvider: Realtime stream update received (${allData.length} total rows)');
          const corruptedIds = {
            '68123b89-c301-4d47-980f-e7e69c1f825c',
            '517c69a3-79c3-4b46-9786-e046431fe008',
          };
          // Only active records where deleted_at is null and mediaUrl is valid
          final activeMedia = allData.where((m) {
            if (m.id != null && corruptedIds.contains(m.id)) return false;
            final url = m.mediaUrl.trim();
            return m.deletedAt == null &&
                url.isNotEmpty &&
                url != 'null' &&
                url != 'undefined' &&
                (url.startsWith('http://') || url.startsWith('https://'));
          }).toList();
          final newShared = activeMedia.where((m) => !m.isHidden).toList();
          final newHidden = activeMedia.where((m) => m.isHidden).toList();

          newShared.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
          newHidden.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

          // Evict any database-deleted cards from image memory cache
          _evictRemovedMediaFromCache(activeMedia);

          _sharedMedia = newShared;
          _hiddenMedia = newHidden;
          _isLoading = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('SecretMediaProvider: Realtime stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('SecretMediaProvider: Error starting stream: $e');
    }
  }

  Future<void> initialize({
    required String userId,
    required String coupleId,
  }) async {
    final needsRefresh =
        _userId != userId || _coupleId != coupleId || _sharedMedia.isEmpty;
    final userChanged = _userId != userId || _coupleId != coupleId;
    _userId = userId;
    _coupleId = coupleId;

    if (userChanged) {
      await loadVaultSettings(userId);
      _setupRealtimeSubscription();
    } else if (_mediaSubscription == null) {
      _setupRealtimeSubscription();
    }

    if (!needsRefresh) return;

    await _loadInitial();
  }

  Future<void> refresh() async {
    if (_userId == null || _coupleId == null) return;
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_coupleId == null) {
      debugPrint(
          'SecretMediaProvider: _loadInitial skipped because coupleId is null');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
          'SecretMediaProvider: Loading secret media for coupleId=$_coupleId');
      final allMedia = await _service.getSecretMedia(_coupleId!);
      final hiddenMedia = await _service.getHiddenSecretMedia(_coupleId!);

      final activeCombined = [...allMedia, ...hiddenMedia];
      _evictRemovedMediaFromCache(activeCombined);

      _sharedMedia = List<SecretMediaModel>.from(allMedia);
      _hiddenMedia = List<SecretMediaModel>.from(hiddenMedia);

      debugPrint(
          'SecretMediaProvider: Loaded ${_sharedMedia.length} shared media, ${_hiddenMedia.length} hidden media');
    } catch (e) {
      _error = 'Failed to load secret media: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners(); // MUST trigger re-render
    }
  }

  /// Add secret media (image or video)
  Future<SecretMediaModel?> addSecretMedia({
    required String mediaType, // 'image' or 'video'
    required String mediaUrl,
    String? thumbnail,
    String? caption,
    bool isHidden = false,
  }) async {
    if (_userId == null || _coupleId == null) {
      _error = 'User or couple not initialized';
      notifyListeners();
      return null;
    }

    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final media = await _service.addSecretMedia(
        coupleId: _coupleId!,
        uploadedById: _userId!,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        thumbnail: thumbnail,
        caption: caption,
        isEncrypted: true,
        isHidden: isHidden,
      );

      if (isHidden) {
        _hiddenMedia.insert(0, media);
        _hiddenMedia.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      } else {
        _sharedMedia.insert(0, media);
        _sharedMedia.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      }

      return media;
    } catch (e) {
      _error = 'Failed to add secret media: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Update secret media caption
  Future<bool> updateCaption(String mediaId, String caption) async {
    try {
      final updatedMedia =
          await _service.updateSecretMedia(mediaId: mediaId, caption: caption);

      // Update in the appropriate list
      final index = _sharedMedia.indexWhere((m) => m.id == mediaId);
      if (index != -1) {
        _sharedMedia[index] = updatedMedia;
      }

      final hiddenIndex = _hiddenMedia.indexWhere((m) => m.id == mediaId);
      if (hiddenIndex != -1) {
        _hiddenMedia[hiddenIndex] = updatedMedia;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update caption: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Move media to hidden vault
  Future<bool> moveToHiddenVault(String mediaId) async {
    try {
      await _service.toggleHidden(mediaId, true);
      _sharedMedia.removeWhere((m) => m.id == mediaId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to move to hidden vault: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Move media from hidden vault to shared
  Future<bool> moveToShared(String mediaId) async {
    try {
      await _service.toggleHidden(mediaId, false);
      _hiddenMedia.removeWhere((m) => m.id == mediaId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to move to shared: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Delete secret media (soft delete - preserves admin dashboard recovery)
  Future<bool> deleteSecretMedia(String mediaId) async {
    try {
      // Evict image cache before removing
      for (final m in [..._sharedMedia, ..._hiddenMedia]) {
        if (m.id == mediaId) {
          if (m.displayUrl.isNotEmpty) {
            try {
              PaintingBinding.instance.imageCache.evict(NetworkImage(m.displayUrl));
            } catch (_) {}
          }
          if (m.thumbnail != null && m.thumbnail!.isNotEmpty) {
            try {
              PaintingBinding.instance.imageCache.evict(NetworkImage(m.thumbnail!));
            } catch (_) {}
          }
          break;
        }
      }

      await _service.deleteSecretMedia(mediaId);
      _sharedMedia.removeWhere((m) => m.id == mediaId);
      _hiddenMedia.removeWhere((m) => m.id == mediaId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete media: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Restore deleted media for Hidden Vault only (Admin recovery - restores all user & partner media in hidden vault)
  Future<int> restoreHiddenVaultMedia({String? targetCoupleId}) async {
    final coupleIdToUse = targetCoupleId ?? _coupleId;
    if (coupleIdToUse != null && coupleIdToUse.isNotEmpty) {
      _coupleId = coupleIdToUse;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final restoredCount =
          await _service.restoreHiddenVaultMedia(coupleId: coupleIdToUse);
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
      if (_coupleId != null) {
        await _loadInitial();
      }
      return restoredCount;
    } catch (e) {
      _error = 'Failed to restore hidden vault media: $e';
      debugPrint(_error);
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore all deleted media (Admin recovery - restores all user & partner media including hidden vault)
  Future<int> restoreAllDeletedMedia({String? targetCoupleId}) async {
    final coupleIdToUse = targetCoupleId ?? _coupleId;
    if (coupleIdToUse != null && coupleIdToUse.isNotEmpty) {
      _coupleId = coupleIdToUse;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final restoredCount =
          await _service.restoreAllDeletedMedia(coupleId: coupleIdToUse);
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
      if (_coupleId != null) {
        await _loadInitial();
      }
      return restoredCount;
    } catch (e) {
      _error = 'Failed to restore deleted media: $e';
      debugPrint(_error);
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle between showing shared and hidden media
  void toggleHiddenVault() {
    _showHiddenVault = !_showHiddenVault;
    _error = null;
    notifyListeners();
  }

  /// Show hidden vault (requires this method to be called)
  void showHidden() {
    _showHiddenVault = true;
    notifyListeners();
  }

  /// Hide the vault view
  void hideVault() {
    _showHiddenVault = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _sharedMedia.clear();
    _hiddenMedia.clear();
    _mediaSubscription?.cancel();
    _mediaSubscription = null;
    _userId = null;
    _coupleId = null;
    _isLoading = false;
    _isUploading = false;
    _error = null;
    _showHiddenVault = false;
    notifyListeners();
  }

  /// Recover deleted secret media from URL
  Future<bool> recoverDeletedMedia({
    required String mediaUrl,
    required String mediaType,
    String? caption,
    bool isHidden = false,
  }) async {
    if (_coupleId == null || _userId == null) {
      _error = 'Couple or user ID not initialized';
      return false;
    }

    try {
      await _service.addSecretMedia(
        coupleId: _coupleId!,
        uploadedById: _userId!,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        caption: caption,
        isEncrypted: true,
        isHidden: isHidden,
      );
      _error = null;
      await _loadInitial();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to recover media: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Get deleted/trash media
  Future<List<SecretMediaModel>> getTrashMedia() async {
    if (_coupleId == null) {
      _error = 'Couple ID not initialized';
      return [];
    }

    try {
      return await _service.getDeletedSecretMedia(_coupleId!);
    } catch (e) {
      _error = 'Failed to fetch trash: $e';
      debugPrint(_error);
      return [];
    }
  }

  /// Restore media from trash (preserves is_hidden placement)
  Future<bool> restoreFromTrash(String mediaId) async {
    try {
      final restoredItem = await _service.restoreSecretMedia(mediaId);
      _error = null;

      // Update local array buffers according to isHidden
      if (restoredItem.isHidden) {
        if (!_hiddenMedia.any((m) => m.id == restoredItem.id)) {
          _hiddenMedia.insert(0, restoredItem);
        }
        _sharedMedia.removeWhere((m) => m.id == restoredItem.id);
      } else {
        if (!_sharedMedia.any((m) => m.id == restoredItem.id)) {
          _sharedMedia.insert(0, restoredItem);
        }
        _hiddenMedia.removeWhere((m) => m.id == restoredItem.id);
      }

      await _loadInitial();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to restore media: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Permanently delete media
  Future<bool> permanentlyDelete(String mediaId) async {
    try {
      await _service.permanentlyDeleteSecretMedia(mediaId);
      _error = null;
      await _loadInitial();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to permanently delete media: $e';
      debugPrint(_error);
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _mediaSubscription?.cancel();
    super.dispose();
  }
}
