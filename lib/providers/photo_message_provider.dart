import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/photo_message_model.dart';
import '../services/supabase_photo_message_service.dart';
import '../services/supabase_storage_service.dart';

class PhotoMessageProvider extends ChangeNotifier {
  final SupabasePhotoMessageService _service;
  final SupabaseStorageService _storageService;

  PhotoMessageProvider(this._service, this._storageService);

  final List<PhotoMessageModel> _messages = [];
  StreamSubscription<List<PhotoMessageModel>>? _messageSubscription;
  Timer? _pollingTimer;
  bool _isRefreshing = false;

  String? _userId;
  String? _coupleId;
  String? _partnerId;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<PhotoMessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get canSend =>
      _partnerId != null && _coupleId != null && _userId != null;

  Future<void> initialize({
    required String userId,
    required String coupleId,
    required String partnerId,
  }) async {
    final needsRefresh = _userId != userId || _coupleId != coupleId;
    _userId = userId;
    _coupleId = coupleId;
    _partnerId = partnerId;

    if (!needsRefresh) return;

    await _loadInitial();
    _subscribeToStream();
  }

  Future<void> _loadInitial() async {
    if (_coupleId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _service.getPhotoMessages(_coupleId!);
      _messages
        ..clear()
        ..addAll(results);
    } catch (e) {
      _error = 'Failed to load photos: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshSilently() async {
    if (_coupleId == null || _isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();

    try {
      final results = await _service.getPhotoMessages(_coupleId!);
      _messages
        ..clear()
        ..addAll(results);
      notifyListeners();
    } catch (e) {
      _error = 'Live refresh failed: $e';
      notifyListeners();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshNow() async {
    _error = null;
    await _refreshSilently();
  }

  void _startPolling() {
    if (_pollingTimer != null) return;
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _refreshSilently(),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _subscribeToStream() {
    _messageSubscription?.cancel();
    if (_coupleId == null) return;

    _messageSubscription =
        _service.streamPhotoMessages(_coupleId!).listen((events) {
      _messages
        ..clear()
        ..addAll(events);
      notifyListeners();
    }, onError: (error) {
      _error = 'Live updates unavailable: $error';
      notifyListeners();
      _startPolling();
    });

    _startPolling();
  }

  Future<bool> sendPhotoMessage({
    required File imageFile,
    String? caption,
  }) async {
    if (!canSend) {
      _error = 'Link your partner to send photos.';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final imageUrl = await _storageService.uploadChatPhoto(
        _userId!,
        imageFile,
      );
      final trimmedCaption = caption?.trim();
      final result = await _service.sendPhotoMessage(
        coupleId: _coupleId!,
        senderId: _userId!,
        receiverId: _partnerId!,
        imageUrl: imageUrl,
        caption: trimmedCaption?.isNotEmpty == true ? trimmedCaption : null,
      );
      _messages.insert(0, result);
      await _refreshSilently();
      return true;
    } catch (e) {
      _error = 'Failed to send photo: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> updateCaption({
    required String messageId,
    String? caption,
  }) async {
    if (_userId == null) {
      _error = 'Sign in to edit captions.';
      notifyListeners();
      return false;
    }

    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) return false;
    if (_messages[index].senderId != _userId) {
      _error = 'You can only edit your own photos.';
      notifyListeners();
      return false;
    }

    try {
      final updated = await _service.updatePhotoCaption(
        messageId: messageId,
        caption: caption,
      );
      if (updated == null) {
        _error = 'Caption update failed. Please try again.';
        notifyListeners();
        return false;
      }
      _messages[index] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update caption: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    if (_userId == null) {
      _error = 'Sign in to delete photos.';
      notifyListeners();
      return false;
    }

    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) return false;
    if (_messages[index].senderId != _userId) {
      _error = 'You can only delete your own photos.';
      notifyListeners();
      return false;
    }

    try {
      final message = _messages[index];
      final deleted = await _service.deletePhotoMessage(messageId);
      if (!deleted) {
        _error = 'Delete blocked. Please check your permissions.';
        notifyListeners();
        return false;
      }

      _messages.removeAt(index);
      notifyListeners();

      try {
        await _storageService.deleteChatPhotoByUrl(message.imageUrl);
      } catch (e) {
        _error = 'Photo deleted, but storage cleanup failed: $e';
        debugPrint(_error);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to delete photo: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _stopPolling();
    _messages.clear();
    _userId = null;
    _coupleId = null;
    _partnerId = null;
    _error = null;
    _isLoading = false;
    _isRefreshing = false;
    _isSending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _stopPolling();
    super.dispose();
  }
}
