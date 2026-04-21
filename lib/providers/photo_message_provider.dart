import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/photo_message_model.dart';
import '../models/photo_message_read_model.dart';
import '../services/supabase_photo_message_service.dart';
import '../services/supabase_storage_service.dart';

class PhotoMessageProvider extends ChangeNotifier {
  final SupabasePhotoMessageService _service;
  final SupabaseStorageService _storageService;

  PhotoMessageProvider(this._service, this._storageService);

  final List<PhotoMessageModel> _messages = [];
  StreamSubscription<List<PhotoMessageModel>>? _messageSubscription;
  StreamSubscription<List<PhotoMessageReadModel>>? _readSubscription;
  Timer? _pollingTimer;
  Timer? _markReadTimer;
  bool _isRefreshing = false;

  final Map<String, Set<String>> _readsByPhoto = {};

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

  bool isSeenByPartner(String photoMessageId) {
    if (_partnerId == null) return false;
    return _readsByPhoto[photoMessageId]?.contains(_partnerId) ?? false;
  }

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
    _subscribeToReadStream();
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
      await _loadReads();
      _scheduleMarkReads();
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
      await _loadReads();
      _scheduleMarkReads();
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
      _handlePhotoUpdate(events);
    }, onError: (error) {
      _error = 'Live updates unavailable: $error';
      notifyListeners();
      _startPolling();
    });

    _startPolling();
  }

  void _handlePhotoUpdate(List<PhotoMessageModel> events) {
    _messages
      ..clear()
      ..addAll(events);
    notifyListeners();
    _scheduleMarkReads();
  }

  void _subscribeToReadStream() {
    _readSubscription?.cancel();
    if (_coupleId == null) return;

    _readSubscription = _service.streamReads(_coupleId!).listen((reads) {
      _readsByPhoto
        ..clear()
        ..addAll(_groupReadsByPhoto(reads));
      notifyListeners();
      _scheduleMarkReads();
    }, onError: (error) {
      debugPrint('Photo read stream error: $error');
    });
  }

  Map<String, Set<String>> _groupReadsByPhoto(
    List<PhotoMessageReadModel> reads,
  ) {
    final Map<String, Set<String>> grouped = {};
    for (final read in reads) {
      grouped.putIfAbsent(read.photoMessageId, () => <String>{});
      grouped[read.photoMessageId]!.add(read.readerId);
    }
    return grouped;
  }

  Future<void> _loadReads() async {
    if (_coupleId == null) return;
    try {
      final photoIds =
          _messages.map((message) => message.id).whereType<String>().toList();
      final reads = photoIds.isEmpty
          ? await _service.getReads(_coupleId!)
          : await _service.getReadsForPhotoMessages(
              coupleId: _coupleId!,
              photoMessageIds: photoIds,
            );
      _readsByPhoto
        ..clear()
        ..addAll(_groupReadsByPhoto(reads));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load photo reads: $e');
    }
  }

  void _scheduleMarkReads() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(
      const Duration(milliseconds: 300),
      _markUnreadAsRead,
    );
  }

  Future<void> _markUnreadAsRead() async {
    if (_userId == null || _coupleId == null) return;
    final unread = _messages.where((message) {
      final id = message.id;
      return message.receiverId == _userId &&
          id != null &&
          !(_readsByPhoto[id]?.contains(_userId) ?? false);
    }).toList();

    if (unread.isEmpty) return;

    try {
      await Future.wait(unread.map((message) {
        return _service.upsertRead(
          coupleId: _coupleId!,
          photoMessageId: message.id!,
          readerId: _userId!,
        );
      }));
    } catch (e) {
      debugPrint('Failed to mark photo reads: $e');
    }
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
    _readSubscription?.cancel();
    _readSubscription = null;
    _stopPolling();
    _markReadTimer?.cancel();
    _markReadTimer = null;
    _messages.clear();
    _readsByPhoto.clear();
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
    _readSubscription?.cancel();
    _stopPolling();
    _markReadTimer?.cancel();
    super.dispose();
  }
}
