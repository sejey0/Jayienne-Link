import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/secret_media_model.dart';
import '../services/supabase_secret_media_service.dart';

class SecretMediaProvider extends ChangeNotifier {
  final SupabaseSecretMediaService _service;

  SecretMediaProvider(this._service);

  final List<SecretMediaModel> _allMedia = [];
  final List<SecretMediaModel> _hiddenMedia = [];
  StreamSubscription<List<SecretMediaModel>>? _mediaSubscription;

  String? _userId;
  String? _coupleId;

  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  bool _showHiddenVault = false;

  // Getters
  List<SecretMediaModel> get allMedia => List.unmodifiable(_allMedia);
  List<SecretMediaModel> get hiddenMedia => List.unmodifiable(_hiddenMedia);
  List<SecretMediaModel> get displayedMedia =>
      _showHiddenVault ? hiddenMedia : allMedia;

  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  bool get showHiddenVault => _showHiddenVault;

  int get totalMediaCount => _allMedia.length + _hiddenMedia.length;
  int get sharedMediaCount => _allMedia.length;
  int get hiddenMediaCount => _hiddenMedia.length;

  Future<void> initialize({
    required String userId,
    required String coupleId,
  }) async {
    final needsRefresh = _userId != userId || _coupleId != coupleId;
    _userId = userId;
    _coupleId = coupleId;

    if (!needsRefresh) return;

    await _loadInitial();
  }

  Future<void> refresh() async {
    if (_userId == null || _coupleId == null) return;
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_coupleId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allMedia = await _service.getSecretMedia(_coupleId!);
      final hiddenMedia = await _service.getHiddenSecretMedia(_coupleId!);

      _allMedia
        ..clear()
        ..addAll(allMedia);
      _hiddenMedia
        ..clear()
        ..addAll(hiddenMedia);
    } catch (e) {
      _error = 'Failed to load secret media: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
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
        _hiddenMedia.add(media);
      } else {
        _allMedia.add(media);
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
      final index = _allMedia.indexWhere((m) => m.id == mediaId);
      if (index != -1) {
        _allMedia[index] = updatedMedia;
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
      _allMedia.removeWhere((m) => m.id == mediaId);
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

  /// Delete secret media
  Future<bool> deleteSecretMedia(String mediaId) async {
    try {
      await _service.deleteSecretMedia(mediaId);
      _allMedia.removeWhere((m) => m.id == mediaId);
      _hiddenMedia.removeWhere((m) => m.id == mediaId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete media: $e';
      debugPrint(_error);
      return false;
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
    _allMedia.clear();
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

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    super.dispose();
  }
}
