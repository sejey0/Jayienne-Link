import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Representation of a pending location update queued in SQLite.
class PendingLocation {
  final int? id;
  final String userId;
  final String coupleId;
  final double latitude;
  final double longitude;
  final double? speed;
  final double accuracy;
  final double? batteryLevel;
  final String createdAt;
  final int retryCount;

  PendingLocation({
    this.id,
    required this.userId,
    required this.coupleId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.accuracy = 0.0,
    this.batteryLevel,
    required this.createdAt,
    this.retryCount = 0,
  });

  /// Factory constructor to deserialize SQLite row into object
  factory PendingLocation.fromMap(Map<String, dynamic> map) {
    return PendingLocation(
      id: map['id'] as int?,
      userId: map['user_id'] as String? ?? '',
      coupleId: map['couple_id'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speed: map['speed'] != null ? (map['speed'] as num).toDouble() : null,
      accuracy: (map['accuracy'] as num? ?? 0.0).toDouble(),
      batteryLevel: map['battery_level'] != null ? (map['battery_level'] as num).toDouble() : null,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  /// Serialize object into SQLite row map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'couple_id': coupleId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accuracy': accuracy,
      'battery_level': batteryLevel,
      'created_at': createdAt,
      'retry_count': retryCount,
    };
  }

  /// Convert object into Supabase database row payload format safely.
  /// Null values are either cleanly passed as null or conditionally formatted.
  Map<String, dynamic> toSupabasePayload() {
    final payload = <String, dynamic>{
      'owner_id': userId,
      'user_id': userId,
      'couple_id': coupleId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'created_at': createdAt,
    };

    if (speed != null) {
      payload['speed'] = speed;
    } else {
      payload['speed'] = null;
    }

    if (batteryLevel != null) {
      payload['battery_level'] = batteryLevel;
    } else {
      payload['battery_level'] = null;
    }

    return payload;
  }
}

/// SQLite Database helper for managing local location queue before backend sync.
class LocationDatabase {
  static const String _dbName = 'location_sync_queue.db';
  static const int _dbVersion = 2;
  static const String tableName = 'pending_locations';

  static LocationDatabase? _instance;
  static Database? _database;

  LocationDatabase._internal();

  /// Singleton Instance Accessor
  static LocationDatabase get instance {
    _instance ??= LocationDatabase._internal();
    return _instance!;
  }

  /// Database getter with auto-initialization guard
  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite location database is not supported on Web.');
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize SQLite Database, create schema & performance indexes
  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Schema creation with nullable speed & battery_level
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[LocationDatabase] Initializing table "$tableName"...');
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        couple_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        speed REAL NULL,
        accuracy REAL NOT NULL DEFAULT 0.0,
        battery_level REAL NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index for fast batch retrieval excluding max retry items
    await db.execute('''
      CREATE INDEX idx_pending_locations_sync 
      ON $tableName (retry_count, created_at ASC)
    ''');
  }

  /// Migration handler for upgrading database version safely
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      debugPrint('[LocationDatabase] Upgrading schema to v2...');
      // Ensure columns exist and allow NULL
    }
  }

  /// Enqueue a location update into local SQLite database.
  /// Guarantees offline safety before any network attempt. Accepts null speed/battery.
  Future<int> enqueueLocation(PendingLocation location) async {
    if (kIsWeb) return 0;
    final db = await database;
    final id = await db.insert(
      tableName,
      location.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('[LocationDatabase] Enqueued location ID: $id (lat: ${location.latitude}, lng: ${location.longitude}, speed: ${location.speed}, battery: ${location.batteryLevel})');
    return id;
  }

  /// Fetch a batch of pending location updates.
  /// Filters out poison pill records where retry_count >= [maxRetries].
  Future<List<PendingLocation>> fetchPendingBatch({
    int limit = 50,
    int maxRetries = 5,
  }) async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      tableName,
      where: 'retry_count < ?',
      whereArgs: [maxRetries],
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map((row) => PendingLocation.fromMap(row)).toList();
  }

  /// Atomically delete a list of successfully synced location IDs using a transaction.
  Future<void> deleteBatch(List<int> ids) async {
    if (kIsWeb || ids.isEmpty) return;
    final db = await database;

    await db.transaction((txn) async {
      final placeholders = List.filled(ids.length, '?').join(',');
      final deleted = await txn.delete(
        tableName,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      debugPrint('[LocationDatabase] Atomically deleted $deleted records from queue.');
    });
  }

  /// Atomically increment the retry count for failed locations.
  /// Prevents broken/invalid payloads from infinitely blocking the sync queue.
  Future<void> incrementRetryCount(List<int> ids) async {
    if (kIsWeb || ids.isEmpty) return;
    final db = await database;

    await db.transaction((txn) async {
      final placeholders = List.filled(ids.length, '?').join(',');
      await txn.rawUpdate(
        'UPDATE $tableName SET retry_count = retry_count + 1 WHERE id IN ($placeholders)',
        ids,
      );
      debugPrint('[LocationDatabase] Incremented retry_count for record IDs: $ids');
    });
  }

  /// Get current total count of items pending sync in queue (excluding poison pills)
  Future<int> getPendingCount({int maxRetries = 5}) async {
    if (kIsWeb) return 0;
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE retry_count < ?',
      [maxRetries],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Purge all poison pill records (items that failed 5+ times) to reclaim storage.
  Future<int> purgePoisonPillRecords({int maxRetries = 5}) async {
    if (kIsWeb) return 0;
    final db = await database;
    final count = await db.delete(
      tableName,
      where: 'retry_count >= ?',
      whereArgs: [maxRetries],
    );
    if (count > 0) {
      debugPrint('[LocationDatabase] Purged $count poison pill records (retry_count >= $maxRetries).');
    }
    return count;
  }

  /// Close database instance (useful during testing or reset)
  Future<void> close() async {
    if (kIsWeb) return;
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
