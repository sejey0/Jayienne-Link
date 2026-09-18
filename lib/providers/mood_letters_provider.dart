import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mood_letter_model.dart';
import '../services/supabase_mood_letter_service.dart';

class MoodLettersProvider extends ChangeNotifier {
  final SupabaseMoodLetterService _service;

  List<MoodLetterModel> _allLetters = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  String _selectedCategory = 'All';

  // Dev-Mode POV Simulation State
  bool _isPartnerPov = false;
  String? _coupleId;
  String? _myUserId;
  String? _partnerUserId;

  MoodLettersProvider({SupabaseMoodLetterService? service})
      : _service = service ?? SupabaseMoodLetterService();

  // Getters
  List<MoodLetterModel> get allLetters => _allLetters;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;

  bool get isPartnerPov => _isPartnerPov;
  String? get myUserId => _myUserId;
  String? get partnerUserId => _partnerUserId;
  String? get coupleId => _coupleId;

  String? get effectiveUserId => _isPartnerPov ? _partnerUserId : _myUserId;
  String? get effectivePartnerId => _isPartnerPov ? _myUserId : _partnerUserId;

  List<MoodLetterModel> get receivedLetters {
    final activeViewerId = effectiveUserId;
    if (activeViewerId == null || activeViewerId.isEmpty) {
      return _allLetters;
    }
    return _allLetters.where((l) {
      if (_isPartnerPov) {
        // Partner POV: Partner is viewer. Show letters where receiver is partner OR sender is not partner
        return l.receiverId == activeViewerId ||
            (_myUserId != null && _myUserId!.isNotEmpty && l.senderId == _myUserId) ||
            l.senderId != activeViewerId;
      }
      // My POV: Me is viewer. Show letters where receiver is Me OR sender is Partner OR sender is not Me
      return l.receiverId == activeViewerId ||
          (_partnerUserId != null && _partnerUserId!.isNotEmpty && l.senderId == _partnerUserId) ||
          l.senderId != activeViewerId;
    }).toList();
  }

  List<MoodLetterModel> get sentLetters {
    final activeViewerId = effectiveUserId;
    if (activeViewerId == null || activeViewerId.isEmpty) {
      return _allLetters;
    }
    return _allLetters.where((l) {
      if (_isPartnerPov) {
        // Partner POV: Partner is viewer. Show letters where sender is partner
        return l.senderId == activeViewerId ||
            (_myUserId != null && _myUserId!.isNotEmpty && l.receiverId == _myUserId && l.senderId != _myUserId);
      }
      // My POV: Me is viewer. Show letters where sender is Me
      return l.senderId == activeViewerId ||
          (_partnerUserId != null && _partnerUserId!.isNotEmpty && l.receiverId == _partnerUserId && l.senderId != _partnerUserId);
    }).toList();
  }

  int get unreadCount => receivedLetters.where((l) => !l.isRead).length;

  List<MoodLetterModel> get filteredReceivedLetters {
    final list = receivedLetters;
    if (_selectedCategory == 'All' || _selectedCategory.isEmpty) {
      return list;
    }
    return list.where((l) => l.category == _selectedCategory).toList();
  }

  void syncContext({required String coupleId, required String myUserId, required String partnerUserId}) {
    bool changed = false;
    if (coupleId.isNotEmpty && _coupleId != coupleId) {
      _coupleId = coupleId;
      changed = true;
    }
    if (myUserId.isNotEmpty && _myUserId != myUserId) {
      _myUserId = myUserId;
      changed = true;
    }
    if (partnerUserId.isNotEmpty && _partnerUserId != partnerUserId) {
      _partnerUserId = partnerUserId;
      changed = true;
    }
    if (changed) {
      if (_allLetters.isEmpty) {
        loadAll(coupleId: _coupleId, myUserId: _myUserId, partnerUserId: _partnerUserId);
      } else {
        notifyListeners();
      }
    }
  }

  void setPartnerPov(bool value, {required String myUserId, required String partnerUserId}) {
    _myUserId = myUserId;
    _partnerUserId = partnerUserId;
    _isPartnerPov = value;
    notifyListeners();
  }

  void togglePartnerPov({required String myUserId, required String partnerUserId}) {
    _myUserId = myUserId;
    _partnerUserId = partnerUserId;
    _isPartnerPov = !_isPartnerPov;
    notifyListeners();
  }

  void selectCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  Future<void> loadAll({String? coupleId, String? myUserId, String? partnerUserId}) async {
    if (coupleId != null && coupleId.isNotEmpty) _coupleId = coupleId;
    if (myUserId != null && myUserId.isNotEmpty) _myUserId = myUserId;
    if (partnerUserId != null && partnerUserId.isNotEmpty) _partnerUserId = partnerUserId;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<MoodLetterModel> letters = [];
      if (_coupleId != null && _coupleId!.isNotEmpty) {
        letters = await _service.getAllCoupleLetters(_coupleId!);
      }

      if (letters.isEmpty && _coupleId != null && _coupleId!.isNotEmpty) {
        // Fallback to local SQLite cache
        final cached = await _service.getCachedCoupleLetters(_coupleId!);
        if (cached.isNotEmpty) {
          letters = cached;
        }
      }

      if (letters.isEmpty) {
        // Fallback to inbox queries
        final activeUserId = effectiveUserId;
        final results = await Future.wait([
          _service.getReceivedInbox(viewingUserId: activeUserId),
          _service.getSentInbox(viewingUserId: activeUserId),
        ]);
        final combined = [...results[0], ...results[1]];
        final map = <String, MoodLetterModel>{};
        for (final l in combined) {
          map[l.id] = l;
        }
        letters = map.values.toList();
      }

      // Authoritative list from database replaces in-memory state so deletions propagate
      _allLetters = letters
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (_coupleId != null && _coupleId!.isNotEmpty) {
        _service.subscribeToCoupleLetters(_coupleId!, onUpdate: () {
          _silentReload();
        });
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading Mood Letters: $e');
      if (_coupleId != null && _coupleId!.isNotEmpty && _allLetters.isEmpty) {
        final cached = await _service.getCachedCoupleLetters(_coupleId!);
        if (cached.isNotEmpty) {
          _allLetters = cached;
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _silentReload() async {
    if (_coupleId == null || _coupleId!.isEmpty) return;
    try {
      final letters = await _service.getAllCoupleLetters(_coupleId!);
      _allLetters = letters
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> deleteLetter(String letterId) async {
    final success = await _service.deleteLetter(letterId);
    if (success) {
      _allLetters.removeWhere((l) => l.id == letterId);
      notifyListeners();
    }
    return success;
  }

  Future<void> refreshReceivedLetters() async {
    await loadAll(coupleId: _coupleId, myUserId: _myUserId, partnerUserId: _partnerUserId);
  }

  Future<void> refreshSentLetters() async {
    await loadAll(coupleId: _coupleId, myUserId: _myUserId, partnerUserId: _partnerUserId);
  }

  Future<bool> sendLetter({
    required String coupleId,
    required String receiverId,
    required String category,
    required String title,
    required String content,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final senderId = effectiveUserId;
      final targetReceiverId = effectivePartnerId ?? receiverId;

      final newLetter = await _service.sendLetter(
        coupleId: coupleId,
        receiverId: targetReceiverId,
        category: category,
        title: title,
        content: content,
        senderIdOverride: senderId,
      );

      _allLetters.removeWhere((l) => l.id == newLetter.id);
      _allLetters.insert(0, newLetter);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error sending letter: $e');
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> openLetter(String letterId) async {
    final result = await _service.openLetter(letterId, viewingUserId: effectiveUserId);

    final index = _allLetters.indexWhere((l) => l.id == letterId);
    if (index != -1) {
      final current = _allLetters[index];
      final newCount = result['read_count'] is int
          ? (result['read_count'] as int)
          : (result['debounced'] == true ? current.readCount : current.readCount + 1);

      final updated = current.copyWith(
        status: MoodLetterStatus.read,
        readCount: newCount,
        firstReadAt: current.firstReadAt ?? DateTime.now(),
        lastReadAt: DateTime.now(),
      );
      _allLetters[index] = updated;
      await _service.cacheLetter(updated);
      notifyListeners();
    }

    return result;
  }

  @override
  void dispose() {
    _service.unsubscribe();
    super.dispose();
  }
}
