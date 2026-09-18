import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/mood_letter_model.dart';

/// Manages offline SQLite caching for Mood Letters and stores pending read receipts
/// that auto-sync when network connectivity is restored.
class LetterOfflineSyncManager {
  static final LetterOfflineSyncManager _instance = LetterOfflineSyncManager._internal();
  factory LetterOfflineSyncManager() => _instance;
  LetterOfflineSyncManager._internal() {
    _initConnectivityListener();
  }

  Database? _db;
  StreamSubscription? _connectivitySub;
  Future<void> Function(String letterId)? _onFlushReadCallback;

  void registerFlushCallback(Future<void> Function(String letterId) callback) {
    _onFlushReadCallback = callback;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'mood_letters_cache.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_letters (
            id TEXT PRIMARY KEY,
            couple_id TEXT,
            sender_id TEXT,
            receiver_id TEXT,
            category TEXT,
            title TEXT,
            content TEXT,
            status TEXT,
            read_count INTEGER,
            created_at TEXT,
            first_read_at TEXT,
            last_read_at TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE pending_reads (
            letter_id TEXT PRIMARY KEY,
            opened_at TEXT
          );
        ''');
      },
    );
    return _db!;
  }

  void _initConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((dynamic event) {
      bool isOnline = false;
      if (event is List) {
        isOnline = event.any((r) => r != ConnectivityResult.none);
      } else if (event is ConnectivityResult) {
        isOnline = event != ConnectivityResult.none;
      }

      if (isOnline) {
        debugPrint('[LetterOfflineSyncManager] Network restored: Flushing pending Mood Letter read receipts');
        flushPendingReads();
      }
    });
  }

  Future<void> cacheLetter(MoodLetterModel letter) async {
    try {
      final db = await database;
      await db.insert(
        'cached_letters',
        letter.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LetterOfflineSyncManager] Error caching letter offline: $e');
    }
  }

  Future<void> cacheAll(List<MoodLetterModel> letters) async {
    try {
      final db = await database;
      final batch = db.batch();
      for (final l in letters) {
        batch.insert(
          'cached_letters',
          l.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[LetterOfflineSyncManager] Error batch caching letters: $e');
    }
  }

  Future<List<MoodLetterModel>> getCachedReceivedLetters(String receiverId, {String? category}) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> rows;
      if (category != null && category.isNotEmpty && category != 'All') {
        rows = await db.query(
          'cached_letters',
          where: 'receiver_id = ? AND category = ?',
          whereArgs: [receiverId, category],
          orderBy: 'created_at DESC',
        );
      } else {
        rows = await db.query(
          'cached_letters',
          where: 'receiver_id = ?',
          whereArgs: [receiverId],
          orderBy: 'created_at DESC',
        );
      }
      return rows.map((r) => MoodLetterModel.fromJson(r)).toList();
    } catch (e) {
      debugPrint('[LetterOfflineSyncManager] Error querying cached received letters: $e');
      return [];
    }
  }

  Future<List<MoodLetterModel>> getCachedCoupleLetters(String coupleId) async {
    try {
      final db = await database;
      final rows = await db.query(
        'cached_letters',
        where: 'couple_id = ?',
        whereArgs: [coupleId],
        orderBy: 'created_at DESC',
      );
      return rows.map((r) => MoodLetterModel.fromJson(r)).toList();
    } catch (e) {
      debugPrint('[LetterOfflineSyncManager] Error querying cached couple letters: $e');
      return [];
    }
  }

  Future<List<MoodLetterModel>> getCachedSentLetters(String senderId) async {
    try {
      final db = await database;
      final rows = await db.query(
        'cached_letters',
        where: 'sender_id = ?',
        whereArgs: [senderId],
        orderBy: 'created_at DESC',
      );
      return rows.map((r) => MoodLetterModel.fromJson(r)).toList();
    } catch (e) {
      debugPrint('[LetterOfflineSyncManager] Error querying cached sent letters: $e');
      return [];
    }
  }

  Future<void> queuePendingRead({required String letterId, required DateTime openedAt}) async {
    try {
      final db = await database;
      await db.insert(
        'pending_reads',
        {
          'letter_id': letterId,
          'opened_at': openedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      debugPrint('[LetterOfflineSyncManager] Queued offline read receipt for letter: $letterId');
    } catch (e) {
      debugPrint('[LetterOfflineSyncManager] Error queueing pending read: $e');
    }
  }

  Future<void> flushPendingReads() async {
    if (_onFlushReadCallback == null) return;

    try {
      final db = await database;
      final pending = await db.query('pending_reads');
      if (pending.isEmpty) return;

      debugPrint('[LetterOfflineSyncManager] Synchronizing ${pending.length} pending letter read receipts...');
      for (final item in pending) {
        final letterId = item['letter_id'] as String;
        try {
          await _onFlushReadCallback!(letterId);
          await db.delete('pending_reads', where: 'letter_id = ?', whereArgs: [letterId]);
          debugPrint('[LetterOfflineSyncManager] Flushed pending read for letter: $letterId');
        } catch (err) {
          debugPrint('[LetterOfflineSyncManager] Flush retry will occur next online event for $letterId: $err');
        }
      }
    } catch (e) {
      debugPrint('[LetterOfflineSyncManager] Error flushing pending reads: $e');
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
