import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/location_model.dart';

/// SQLite-based offline storage for location data.
/// Provides offline-first storage with sync status tracking.
class OfflineStorageService {
  static const String _databaseName = 'jayienne_link_locations.db';
  static const int _databaseVersion = 5; // Added heading migration
  static const String _locationsTable = 'locations';
  static const String _settingsTable = 'location_settings';

  static OfflineStorageService? _instance;
  static Database? _database;

  OfflineStorageService._();

  static OfflineStorageService get instance {
    _instance ??= OfflineStorageService._();
    return _instance!;
  }

  /// Get database instance, creating if needed
  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite offline storage is not supported on Web.');
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Ensure database is initialized (for background tasks)
  Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    _database ??= await _initDatabase();
  }

  /// Initialize SQLite database with schema
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Locations table for storing GPS coordinates
    await db.execute('''
      CREATE TABLE $_locationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supabase_id TEXT,
        couple_id TEXT NOT NULL DEFAULT '',
        owner_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL NOT NULL,
        speed REAL DEFAULT 0.0,
        heading REAL DEFAULT 0.0,
        battery_level INTEGER,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        partner_id TEXT,
        source INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    // Indexes for fast queries
    await db.execute('''
      CREATE INDEX idx_locations_timestamp ON $_locationsTable(timestamp DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_locations_owner ON $_locationsTable(owner_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_locations_synced ON $_locationsTable(is_synced)
    ''');
    await db.execute('''
      CREATE INDEX idx_locations_partner ON $_locationsTable(partner_id)
    ''');

    // Settings table for user preferences
    await db.execute('''
      CREATE TABLE $_settingsTable (
        user_id TEXT PRIMARY KEY,
        sharing_enabled INTEGER NOT NULL DEFAULT 0,
        background_sharing_enabled INTEGER NOT NULL DEFAULT 0,
        update_interval_minutes INTEGER NOT NULL DEFAULT 15,
        data_saver_enabled INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER
      )
    ''');
  }

  /// Handle database migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        '[OfflineStorageService] Upgrading database from v$oldVersion to v$newVersion...');

    // Migration: Add data_saver_enabled column
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        _settingsTable,
        'data_saver_enabled',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }

    // Migration: align locations table with current LocationModel map keys
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        _locationsTable,
        'supabase_id',
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        _locationsTable,
        'couple_id',
        "TEXT NOT NULL DEFAULT ''",
      );
    }

    // Migration: Add speed and battery_level columns
    if (oldVersion < 4) {
      await _addColumnIfMissing(
        db,
        _locationsTable,
        'speed',
        'REAL DEFAULT 0.0',
      );
      await _addColumnIfMissing(
        db,
        _locationsTable,
        'battery_level',
        'INTEGER',
      );
    }

    // Migration: Add heading column
    if (oldVersion < 5) {
      await _addColumnIfMissing(
        db,
        _locationsTable,
        'heading',
        'REAL DEFAULT 0.0',
      );
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnName,
    String definition,
  ) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      final hasColumn = result.any((row) => row['name'] == columnName);
      if (!hasColumn) {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN $columnName $definition',
        );
        debugPrint(
            '[OfflineStorageService] Added missing column "$columnName" to "$tableName".');
      }
    } catch (e) {
      debugPrint(
          '[OfflineStorageService] Error checking/adding column "$columnName": $e');
    }
  }

  // =====================
  // LOCATION OPERATIONS
  // =====================

  /// Insert a new location (always saves locally first)
  Future<int> insertLocation(LocationModel location) async {
    if (kIsWeb) return 0;
    try {
      final db = await database;
      return await db.insert(
        _locationsTable,
        location.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[OfflineStorageService] insertLocation fallback: $e');
      try {
        final db = await database;
        await _addColumnIfMissing(
            db, _locationsTable, 'speed', 'REAL DEFAULT 0.0');
        await _addColumnIfMissing(
            db, _locationsTable, 'battery_level', 'INTEGER');
        return await db.insert(
          _locationsTable,
          location.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e2) {
        debugPrint('[OfflineStorageService] insertLocation failed: $e2');
        return 0;
      }
    }
  }

  /// Insert multiple locations in a batch (for efficiency)
  Future<void> insertLocationsBatch(List<LocationModel> locations) async {
    if (kIsWeb) return;
    try {
      final db = await database;
      final batch = db.batch();
      for (final location in locations) {
        batch.insert(
          _locationsTable,
          location.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[OfflineStorageService] insertLocationsBatch error: $e');
    }
  }

  /// Get all unsynced locations for upload (includes background captures)
  Future<List<LocationModel>> getUnsyncedLocations(String ownerId) async {
    if (kIsWeb) return [];
    final db = await database;
    final maps = await db.query(
      _locationsTable,
      where:
          'owner_id = ? AND is_synced = 0 AND source IN (0, 2)', // local and background
      whereArgs: [ownerId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => LocationModel.fromMap(map)).toList();
  }

  /// Get count of unsynced locations (includes background captures)
  Future<int> getUnsyncedCount(String ownerId) async {
    if (kIsWeb) return 0;
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_locationsTable WHERE owner_id = ? AND is_synced = 0 AND source IN (0, 2)',
      [ownerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total location count for a user
  Future<int> getLocationCount(String ownerId) async {
    if (kIsWeb) return 0;
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_locationsTable WHERE owner_id = ?',
      [ownerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark a location as synced
  Future<void> markAsSynced(int localId, String supabaseId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      _locationsTable,
      {'is_synced': 1, 'supabase_id': supabaseId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Mark all locations for a user as synced
  Future<void> markAllAsSynced(String ownerId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      _locationsTable,
      {'is_synced': 1},
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
  }

  /// Mark multiple locations as synced (batch operation)
  Future<void> markBatchAsSynced(Map<int, String> localToSupabaseIds) async {
    if (kIsWeb) return;
    final db = await database;
    final batch = db.batch();
    for (final entry in localToSupabaseIds.entries) {
      batch.update(
        _locationsTable,
        {'is_synced': 1, 'supabase_id': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get user's last known location
  Future<LocationModel?> getLastKnownLocation(String ownerId) async {
    if (kIsWeb) return null;
    final db = await database;
    final maps = await db.query(
      _locationsTable,
      where: 'owner_id = ? AND source IN (0, 2)', // local or background
      whereArgs: [ownerId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocationModel.fromMap(maps.first);
  }

  /// Get partner's last known location
  Future<LocationModel?> getPartnerLastLocation(String partnerId) async {
    if (kIsWeb) return null;
    final db = await database;
    final maps = await db.query(
      _locationsTable,
      where: 'owner_id = ? AND source = 1', // partner source
      whereArgs: [partnerId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocationModel.fromMap(maps.first);
  }

  /// Get location history for a user (paginated)
  Future<List<LocationModel>> getLocationHistory(
    String ownerId, {
    int limit = 100,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (kIsWeb) return [];
    final db = await database;
    String where = 'owner_id = ?';
    List<dynamic> whereArgs = [ownerId];

    if (startDate != null) {
      where += ' AND timestamp >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      where += ' AND timestamp <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final maps = await db.query(
      _locationsTable,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => LocationModel.fromMap(map)).toList();
  }

  /// Get all locations for a specific date sorted chronologically (ASC) with downsampling for playback
  Future<List<LocationModel>> getLocationsByDate(
    String ownerId,
    DateTime date,
  ) async {
    if (kIsWeb) return [];
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final maps = await db.query(
      _locationsTable,
      where: 'owner_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        ownerId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp ASC',
    );
    final raw = maps.map((map) => LocationModel.fromMap(map)).toList();
    return _downsampleLocations(raw);
  }

  /// Downsamples a list of locations to eliminate clustered/redundant points (<10m or <10s)
  /// and limits points to a maximum of 300 per day while preserving start & end waypoints.
  List<LocationModel> _downsampleLocations(
    List<LocationModel> raw, {
    int maxPoints = 300,
    double minDistanceMeters = 10.0,
    int minIntervalSeconds = 10,
  }) {
    if (raw.length <= 2) return raw;

    final List<LocationModel> filtered = [raw.first];

    for (int i = 1; i < raw.length - 1; i++) {
      final current = raw[i];
      final last = filtered.last;

      final elapsed = current.timestamp.difference(last.timestamp).inSeconds.abs();
      final distance = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        current.latitude,
        current.longitude,
      );

      // Skip if closer than 10m or within 10s of last kept point
      if (distance < minDistanceMeters || elapsed < minIntervalSeconds) {
        continue;
      }

      filtered.add(current);
    }

    // Always include the latest point
    filtered.add(raw.last);

    // If still exceeds maxPoints, uniform stride decimation
    if (filtered.length > maxPoints) {
      final List<LocationModel> decimated = [filtered.first];
      final double step = (filtered.length - 1) / (maxPoints - 1);
      for (int i = 1; i < maxPoints - 1; i++) {
        final index = (i * step).round();
        if (index > 0 && index < filtered.length - 1) {
          decimated.add(filtered[index]);
        }
      }
      decimated.add(filtered.last);
      return decimated;
    }

    return filtered;
  }

  /// Get all locations for a specific day
  Future<List<LocationModel>> getLocationsForDay(
    String ownerId,
    DateTime date,
  ) async {
    if (kIsWeb) return [];
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getLocationHistory(
      ownerId,
      startDate: startOfDay,
      endDate: endOfDay,
      limit: 1000, // Get all locations for the day
    );
  }

  /// Store locations received from Supabase (avoids duplicates)
  Future<void> storeRemoteLocations(List<LocationModel> locations) async {
    if (kIsWeb || locations.isEmpty) return;

    final db = await database;
    final batch = db.batch();
    for (final location in locations) {
      if (location.id == null) {
        continue;
      }
      // Check if we already have this location by Supabase ID
      final existing = await db.query(
        _locationsTable,
        where: 'supabase_id = ?',
        whereArgs: [location.id],
        limit: 1,
      );

      if (existing.isEmpty) {
        batch.insert(
          _locationsTable,
          location.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Store partner's locations received from Supabase
  Future<void> storePartnerLocations(List<LocationModel> locations) async {
    if (kIsWeb) return;
    await storeRemoteLocations(locations);
  }

  /// Clean up old locations (retention policy: 7 days)
  Future<int> cleanupOldLocations({int retentionDays = 7}) async {
    if (kIsWeb) return 0;
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;

    return await db.delete(
      _locationsTable,
      where: 'timestamp < ? AND is_synced = 1',
      whereArgs: [cutoff],
    );
  }

  /// Delete all location data for a user (privacy feature)
  Future<int> deleteAllUserLocations(String ownerId) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.delete(
      _locationsTable,
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
  }

  /// Delete partner's cached locations
  Future<int> deletePartnerLocations(String partnerId) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.delete(
      _locationsTable,
      where: 'owner_id = ? AND source = 1',
      whereArgs: [partnerId],
    );
  }

  // =====================
  // SETTINGS OPERATIONS
  // =====================

  /// Get user's location settings
  Future<LocationSharingSettings?> getSettings(String userId) async {
    if (kIsWeb) return null;
    final db = await database;
    final maps = await db.query(
      _settingsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocationSharingSettings.fromMap(maps.first);
  }

  /// Save user's location settings
  Future<void> saveSettings(
      String userId, LocationSharingSettings settings) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      _settingsTable,
      {
        'user_id': userId,
        ...settings.toMap(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update sharing enabled status
  Future<void> setSharingEnabled(String userId, bool enabled) async {
    if (kIsWeb) return;
    final settings = await getSettings(userId) ?? LocationSharingSettings();
    await saveSettings(
      userId,
      settings.copyWith(
        sharingEnabled: enabled,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Update background sharing status
  Future<void> setBackgroundSharingEnabled(String userId, bool enabled) async {
    if (kIsWeb) return;
    final settings = await getSettings(userId) ?? LocationSharingSettings();
    await saveSettings(
      userId,
      settings.copyWith(
        backgroundSharingEnabled: enabled,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  // =====================
  // UTILITY METHODS
  // =====================

  /// Get database statistics for debugging
  Future<Map<String, dynamic>> getStats(String ownerId) async {
    if (kIsWeb) {
      return {
        'total_locations': 0,
        'unsynced_locations': 0,
        'partner_locations': 0,
      };
    }
    final db = await database;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_locationsTable WHERE owner_id = ?',
      [ownerId],
    );
    final unsyncedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_locationsTable WHERE owner_id = ? AND is_synced = 0',
      [ownerId],
    );
    final partnerResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_locationsTable WHERE source = 1',
    );

    return {
      'total_locations': Sqflite.firstIntValue(totalResult) ?? 0,
      'unsynced_locations': Sqflite.firstIntValue(unsyncedResult) ?? 0,
      'partner_locations': Sqflite.firstIntValue(partnerResult) ?? 0,
    };
  }

  /// Close database connection
  Future<void> close() async {
    if (kIsWeb) return;
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Reset database (for testing/logout)
  Future<void> reset() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(_locationsTable);
    await db.delete(_settingsTable);
  }
}
