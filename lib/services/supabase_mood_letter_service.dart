import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mood_letter_model.dart';
import 'letter_offline_sync_manager.dart';

class SupabaseMoodLetterService {
  static final SupabaseMoodLetterService _instance = SupabaseMoodLetterService._internal();
  factory SupabaseMoodLetterService({SupabaseClient? client}) {
    if (client != null) _instance._supabase = client;
    return _instance;
  }

  late SupabaseClient _supabase;
  final LetterOfflineSyncManager _offlineSync = LetterOfflineSyncManager();

  // In-memory debounce cache: letterId -> last opened timestamp
  final Map<String, DateTime> _clientDebounceMap = {};

  SupabaseMoodLetterService._internal() {
    _supabase = Supabase.instance.client;
    // Connect offline sync queue runner
    _offlineSync.registerFlushCallback((letterId) async {
      await _executeRpcOpen(letterId);
    });
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// 1. sendLetter(sender_id, receiver_id, category, title, content)
  Future<MoodLetterModel> sendLetter({
    required String coupleId,
    required String receiverId,
    required String category,
    required String title,
    required String content,
    String? senderIdOverride,
  }) async {
    final senderId = senderIdOverride ?? currentUserId;
    if (senderId == null) throw Exception('User not authenticated');

    final payload = {
      'couple_id': coupleId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'category': category.trim(),
      'title': title.trim(),
      'content': content.trim(),
      'status': 'UNREAD',
      'read_count': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _supabase
        .from('letters')
        .insert(payload)
        .select()
        .single();

    final letter = MoodLetterModel.fromJson(response);
    await _offlineSync.cacheLetter(letter);
    return letter;
  }

  /// 2. getReceivedInbox(user_id) with optional category filter
  Future<List<MoodLetterModel>> getReceivedInbox({
    String? categoryFilter,
    String? viewingUserId,
  }) async {
    final userId = viewingUserId ?? currentUserId;
    if (userId == null) return [];

    try {
      var query = _supabase
          .from('letters')
          .select()
          .eq('receiver_id', userId);

      if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'All') {
        query = query.eq('category', categoryFilter);
      }

      final response = await query.order('created_at', ascending: false);
      final letters = (response as List)
          .map((row) => MoodLetterModel.fromJson(row as Map<String, dynamic>))
          .toList();

      await _offlineSync.cacheAll(letters);
      return letters;
    } catch (e) {
      debugPrint('Failed to query online received inbox, falling back to cache: $e');
      return _offlineSync.getCachedReceivedLetters(userId, category: categoryFilter);
    }
  }

  /// 3. getSentInbox(user_id)
  Future<List<MoodLetterModel>> getSentInbox({String? viewingUserId}) async {
    final userId = viewingUserId ?? currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('letters')
          .select()
          .eq('sender_id', userId)
          .order('created_at', ascending: false);

      final letters = (response as List)
          .map((row) => MoodLetterModel.fromJson(row as Map<String, dynamic>))
          .toList();

      await _offlineSync.cacheAll(letters);
      return letters;
    } catch (e) {
      debugPrint('Failed to query online sent inbox, falling back to cache: $e');
      return _offlineSync.getCachedSentLetters(userId);
    }
  }

  /// 4. openLetter(letter_id, user_id)
  /// Increments read_count atomically, updates status and timestamps, debounces rapid opens
  Future<Map<String, dynamic>> openLetter(String letterId, {String? viewingUserId}) async {
    final userId = viewingUserId ?? currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();

    // Client-side debounce check (15s cooldown)
    if (_clientDebounceMap.containsKey(letterId)) {
      final lastOpen = _clientDebounceMap[letterId]!;
      if (now.difference(lastOpen).inSeconds < 15) {
        debugPrint('Letter $letterId open request debounced on client');
        return {'success': true, 'debounced': true};
      }
    }
    _clientDebounceMap[letterId] = now;

    try {
      final result = await _executeRpcOpen(letterId, viewingUserId: userId);
      return result;
    } catch (e) {
      debugPrint('Network error while opening letter. Queueing offline read: $e');
      await _offlineSync.queuePendingRead(letterId: letterId, openedAt: now);
      return {'success': true, 'offline': true};
    }
  }

  Future<Map<String, dynamic>> _executeRpcOpen(String letterId, {String? viewingUserId}) async {
    final userId = viewingUserId ?? currentUserId;
    if (userId == null) return {'success': false, 'reason': 'unauthenticated'};

    final response = await _supabase.rpc('open_letter', params: {
      'p_letter_id': letterId,
      'p_user_id': userId,
      'p_cooldown_seconds': 30,
    });

    final map = Map<String, dynamic>.from(response as Map);
    debugPrint('open_letter RPC executed successfully for letter: $letterId. Result: $map');
    return map;
  }

  /// 5. Fetch all letters belonging to a couple (used for robust offline & multi-POV caching)
  Future<List<MoodLetterModel>> getAllCoupleLetters(String coupleId) async {
    if (coupleId.isEmpty) return [];

    try {
      final response = await _supabase
          .from('letters')
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false);

      final letters = (response as List)
          .map((row) => MoodLetterModel.fromJson(row as Map<String, dynamic>))
          .toList();

      if (letters.isNotEmpty) {
        await _offlineSync.cacheAll(letters);
        return letters;
      }

      // If remote returned empty, check offline cache before concluding empty
      final cached = await _offlineSync.getCachedCoupleLetters(coupleId);
      return cached;
    } catch (e) {
      debugPrint('[SupabaseMoodLetterService] Failed to fetch couple letters, falling back to cache: $e');
      return _offlineSync.getCachedCoupleLetters(coupleId);
    }
  }

  Future<List<MoodLetterModel>> getCachedCoupleLetters(String coupleId) async {
    return _offlineSync.getCachedCoupleLetters(coupleId);
  }

  RealtimeChannel? _realtimeSubscription;

  /// Subscribe to realtime PostgreSQL changes for a couple's letters
  void subscribeToCoupleLetters(String coupleId, {required VoidCallback onUpdate}) {
    unsubscribe();
    if (coupleId.isEmpty) return;

    try {
      _realtimeSubscription = _supabase
          .channel('public:letters:$coupleId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'letters',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'couple_id',
              value: coupleId,
            ),
            callback: (payload) {
              debugPrint('[SupabaseMoodLetterService] Realtime letters event: ${payload.eventType}');
              onUpdate();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[SupabaseMoodLetterService] Realtime subscription error: $e');
    }
  }

  void unsubscribe() {
    if (_realtimeSubscription != null) {
      try {
        _supabase.removeChannel(_realtimeSubscription!);
      } catch (_) {}
      _realtimeSubscription = null;
    }
  }

  /// Fallback Realtime Streams
  Stream<List<MoodLetterModel>> streamSentLetters({String? viewingUserId}) {
    final userId = viewingUserId ?? currentUserId;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('letters')
        .stream(primaryKey: ['id'])
        .eq('sender_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => MoodLetterModel.fromJson(r)).toList());
  }

  Stream<List<MoodLetterModel>> streamReceivedLetters({String? viewingUserId}) {
    final userId = viewingUserId ?? currentUserId;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('letters')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => MoodLetterModel.fromJson(r)).toList());
  }
}
