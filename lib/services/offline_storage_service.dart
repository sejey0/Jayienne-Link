import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/location_model.dart';

/// SQLite-based offline storage for location data.
/// Provides offline-first storage with sync status tracking.
class OfflineStorageService {
  static const String _databaseName = 'jayienne_link_locations.db';
  static const int _databaseVersion = 1;
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
    _database ??= await _initDatabase();
    return _database!;
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
        owner_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        firestore_id TEXT,
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
        last_updated INTEGER
      )
    ''');
  }

  /// Handle database migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Add migration logic here for future schema changes
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $_locationsTable ADD COLUMN new_field TEXT');
    // }
  }

  // =====================
  // LOCATION OPERATIONS
  // =====================

  /// Insert a new location (always saves locally first)
  Future<int> insertLocation(LocationModel location) async {
    final db = await database;
    return await db.insert(
      _locationsTable,
      location.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple locations in a batch (for efficiency)
  Future<void> insertLocationsBatch(List<LocationModel> locations) async {
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
  }

  /// Get all unsynced locations for upload
  Future<List<LocationModel>> getUnsyncedLocations(String ownerId) async {
    final db = await database;
    final maps = await db.query(
      _locationsTable,
      where: 'owner_id = ? AND is_synced = 0 AND source = 0',
      whereArgs: [ownerId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => LocationModel.fromMap(map)).toList();
  }

  /// Get count of unsynced locations
  Future<int> getUnsyncedCount(String ownerId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_locationsTable WHERE owner_id = ? AND is_synced = 0 AND source = 0',
      [ownerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark a location as synced
  Future<void> markAsSynced(int localId, String firestoreId) async {
    final db = await database;
    await db.update(
      _locationsTable,
      {'is_synced': 1, 'firestore_id': firestoreId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Mark multiple locations as synced (batch operation)
  Future<void> markBatchAsSynced(Map<int, String> localToFirestoreIds) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in localToFirestoreIds.entries) {
      batch.update(
        _locationsTable,
        {'is_synced': 1, 'firestore_id': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get user's last known location
  Future<LocationModel?> getLastKnownLocation(String ownerId) async {
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

  /// Get all locations for a specific day
  Future<List<LocationModel>> getLocationsForDay(
    String ownerId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getLocationHistory(
      ownerId,
      startDate: startOfDay,
      endDate: endOfDay,
      limit: 1000, // Get all locations for the day
    );
  }

  /// Store partner's locations received from Firestore
  Future<void> storePartnerLocations(List<LocationModel> locations) async {
    final db = await database;
    final batch = db.batch();
    for (final location in locations) {
      // Check if we already have this location
      final existing = await db.query(
        _locationsTable,
        where: 'firestore_id = ?',
        whereArgs: [location.firestoreId],
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

  /// Clean up old locations (retention policy: 7 days)
  Future<int> cleanupOldLocations({int retentionDays = 7}) async {
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
    final db = await database;
    return await db.delete(
      _locationsTable,
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
  }

  /// Delete partner's cached locations
  Future<int> deletePartnerLocations(String partnerId) async {
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
  Future<void> saveSettings(String userId, LocationSharingSettings settings) async {
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
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Reset database (for testing/logout)
  Future<void> reset() async {
    final db = await database;
    await db.delete(_locationsTable);
    await db.delete(_settingsTable);
  }
}
