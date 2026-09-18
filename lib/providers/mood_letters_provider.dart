import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mood_letter_model.dart';
import '../services/supabase_mood_letter_service.dart';

class MoodLettersProvider extends ChangeNotifier {
  final SupabaseMoodLetterService _service;

  List<MoodLetterModel> _receivedLetters = [];
  List<MoodLetterModel> _sentLetters = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  String _selectedCategory = 'All';

  StreamSubscription? _receivedSubscription;
  StreamSubscription? _sentSubscription;

  MoodLettersProvider({SupabaseMoodLetterService? service})
      : _service = service ?? SupabaseMoodLetterService();

  // Getters
  List<MoodLetterModel> get receivedLetters => _receivedLetters;
  List<MoodLetterModel> get sentLetters => _sentLetters;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;

  int get unreadCount => _receivedLetters.where((l) => !l.isRead).length;

  List<MoodLetterModel> get filteredReceivedLetters {
    if (_selectedCategory == 'All' || _selectedCategory.isEmpty) {
      return _receivedLetters;
    }
    return _receivedLetters.where((l) => l.category == _selectedCategory).toList();
  }

  void selectCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getReceivedInbox(),
        _service.getSentInbox(),
      ]);

      _receivedLetters = results[0];
      _sentLetters = results[1];
      _initRealtime();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading Mood Letters: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReceivedLetters() async {
    try {
      final letters = await _service.getReceivedInbox(
        categoryFilter: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      _receivedLetters = letters;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing received letters: $e');
    }
  }

  Future<void> refreshSentLetters() async {
    try {
      final letters = await _service.getSentInbox();
      _sentLetters = letters;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing sent letters: $e');
    }
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
      final newLetter = await _service.sendLetter(
        coupleId: coupleId,
        receiverId: receiverId,
        category: category,
        title: title,
        content: content,
      );

      _sentLetters.insert(0, newLetter);
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
    final result = await _service.openLetter(letterId);

    // Optimistically update local received letter state
    final index = _receivedLetters.indexWhere((l) => l.id == letterId);
    if (index != -1) {
      final current = _receivedLetters[index];
      final newCount = result['read_count'] is int
          ? result['read_count'] as int
          : current.readCount + 1;

      _receivedLetters[index] = current.copyWith(
        status: MoodLetterStatus.read,
        readCount: newCount,
        firstReadAt: current.firstReadAt ?? DateTime.now(),
        lastReadAt: DateTime.now(),
      );
      notifyListeners();
    }

    return result;
  }

  void _initRealtime() {
    _receivedSubscription?.cancel();
    _sentSubscription?.cancel();

    _receivedSubscription = _service.streamReceivedLetters().listen((letters) {
      _receivedLetters = letters;
      notifyListeners();
    });

    _sentSubscription = _service.streamSentLetters().listen((letters) {
      _sentLetters = letters;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _receivedSubscription?.cancel();
    _sentSubscription?.cancel();
    super.dispose();
  }
}
