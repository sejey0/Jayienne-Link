import 'dart:math';

/// Supabase LocationModel for PostgreSQL database
/// Designed for offline-first storage with sync status tracking
class LocationModel {
  final String? id; // Supabase UUID
  final int? localId; // SQLite auto-increment ID (for offline storage)
  final String coupleId; // References couples table
  final String ownerId; // User ID who owns this location
  final String? partnerId; // Partner's ID (for received locations)
  final double latitude;
  final double longitude;
  final double accuracy; // GPS accuracy in meters
  final DateTime timestamp;
  final DateTime? createdAt; // When record was created in database
  final bool isSynced; // Whether synced to Supabase
  final LocationSource source; // Where this location came from

  LocationModel({
    this.id,
    this.localId,
    required this.coupleId,
    required this.ownerId,
    this.partnerId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.createdAt,
    this.isSynced = false,
    this.source = LocationSource.local,
  });

  /// Create from SQLite row (offline storage)
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      localId: map['id'] as int?,
      id: map['supabase_id'] as String?,
      coupleId: map['couple_id'] as String,
      ownerId: map['owner_id'] as String,
      partnerId: map['partner_id'] as String?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      accuracy: map['accuracy'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      isSynced: (map['is_synced'] as int) == 1,
      source: LocationSource.values[map['source'] as int? ?? 0],
    );
  }

  /// Convert to SQLite row (offline storage)
  Map<String, dynamic> toMap() {
    return {
      if (localId != null) 'id': localId,
      'supabase_id': id,
      'couple_id': coupleId,
      'owner_id': ownerId,
      'partner_id': partnerId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
      'source': source.index,
    };
  }

  /// Create from Supabase JSON response
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as String?,
      coupleId: json['couple_id'] as String,
      ownerId: json['owner_id'] as String,
      partnerId: json['partner_id'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 15.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isSynced: true, // Data from Supabase is always synced
      source: LocationSource.partner, // Assume partner data from server
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson({bool dataSaver = false}) {
    if (dataSaver) {
      // Data saver mode: reduce precision to save bandwidth
      // 4 decimal places = ~11m accuracy (good enough for location sharing)
      return {
        'couple_id': coupleId,
        'owner_id': ownerId,
        'latitude': double.parse(latitude.toStringAsFixed(4)),
        'longitude': double.parse(longitude.toStringAsFixed(4)),
        'timestamp': timestamp.toIso8601String(),
        // Skip accuracy, partner_id, created_at to save data
      };
    }

    return {
      if (id != null) 'id': id,
      'couple_id': coupleId,
      'owner_id': ownerId,
      'partner_id': partnerId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Convert to JSON for database insertion (excludes auto-generated fields)
  Map<String, dynamic> toInsertJson({bool dataSaver = false}) {
    final json = toJson(dataSaver: dataSaver);
    json.remove('id'); // Let database generate UUID
    json.remove('created_at'); // Let database set default
    return json;
  }

  /// Convert to JSON for database updates (excludes immutable fields)
  Map<String, dynamic> toUpdateJson() {
    final json = toJson();
    json.remove('id');
    json.remove('couple_id'); // Usually immutable
    json.remove('owner_id'); // Immutable
    json.remove('timestamp'); // Usually immutable
    json.remove('created_at'); // Immutable
    return json;
  }

  /// Create a copy with updated fields
  LocationModel copyWith({
    String? id,
    int? localId,
    String? coupleId,
    String? ownerId,
    String? partnerId,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    DateTime? createdAt,
    bool? isSynced,
    LocationSource? source,
  }) {
    return LocationModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      coupleId: coupleId ?? this.coupleId,
      ownerId: ownerId ?? this.ownerId,
      partnerId: partnerId ?? this.partnerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      source: source ?? this.source,
    );
  }

  /// Mark as synced to Supabase
  LocationModel markSynced(String supabaseId) {
    return copyWith(
      id: supabaseId,
      isSynced: true,
    );
  }

  /// Check if location is recent (within threshold)
  bool isRecent({Duration threshold = const Duration(minutes: 5)}) {
    return DateTime.now().difference(timestamp) < threshold;
  }

  /// Get human-readable time ago string
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  /// Get formatted timestamp string
  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Get formatted date string
  String get formattedDate {
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '$month/$day/${timestamp.year}';
  }

  /// Calculate distance from another location in meters
  double distanceFrom(LocationModel other) {
    const double earthRadius = 6371000; // Earth radius in meters

    final lat1Rad = latitude * (pi / 180);
    final lat2Rad = other.latitude * (pi / 180);
    final deltaLatRad = (other.latitude - latitude) * (pi / 180);
    final deltaLngRad = (other.longitude - longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  @override
  String toString() {
    return 'LocationModel(lat: $latitude, lng: $longitude, synced: $isSynced)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationModel &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp &&
        other.ownerId == ownerId;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
        longitude.hashCode ^
        timestamp.hashCode ^
        ownerId.hashCode;
  }
}

/// Source of the location data
enum LocationSource {
  local, // Captured from this device
  partner, // Received from partner's device
  background, // Captured in background mode
}

/// Location sharing settings for a user
class LocationSharingSettings {
  final bool sharingEnabled;
  final bool backgroundSharingEnabled;
  final int updateIntervalMinutes;
  final bool dataSaverEnabled; // Reduces data usage on slow connections
  final DateTime? lastUpdated;

  LocationSharingSettings({
    this.sharingEnabled = false,
    this.backgroundSharingEnabled = false,
    this.updateIntervalMinutes = 15,
    this.dataSaverEnabled = false,
    this.lastUpdated,
  });

  factory LocationSharingSettings.fromMap(Map<String, dynamic> map) {
    return LocationSharingSettings(
      // SQLite stores booleans as integers (0/1)
      sharingEnabled:
          (map['sharing_enabled'] == 1 || map['sharing_enabled'] == true),
      backgroundSharingEnabled: (map['background_sharing_enabled'] == 1 ||
          map['background_sharing_enabled'] == true),
      updateIntervalMinutes: map['update_interval_minutes'] as int? ?? 15,
      dataSaverEnabled:
          (map['data_saver_enabled'] == 1 || map['data_saver_enabled'] == true),
      lastUpdated: map['last_updated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int)
          : null,
    );
  }

  /// Convert to JSON for Supabase (stored as JSONB in user profile)
  Map<String, dynamic> toJson() {
    return {
      'sharing_enabled': sharingEnabled,
      'background_sharing_enabled': backgroundSharingEnabled,
      'update_interval_minutes': updateIntervalMinutes,
      'data_saver_enabled': dataSaverEnabled,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  /// Create from Supabase JSON
  factory LocationSharingSettings.fromJson(Map<String, dynamic> json) {
    return LocationSharingSettings(
      sharingEnabled: json['sharing_enabled'] as bool? ?? false,
      backgroundSharingEnabled:
          json['background_sharing_enabled'] as bool? ?? false,
      updateIntervalMinutes: json['update_interval_minutes'] as int? ?? 15,
      dataSaverEnabled: json['data_saver_enabled'] as bool? ?? false,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // SQLite doesn't support bool - use 0/1 integers
      'sharing_enabled': sharingEnabled ? 1 : 0,
      'background_sharing_enabled': backgroundSharingEnabled ? 1 : 0,
      'update_interval_minutes': updateIntervalMinutes,
      'data_saver_enabled': dataSaverEnabled ? 1 : 0,
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
    };
  }

  LocationSharingSettings copyWith({
    bool? sharingEnabled,
    bool? backgroundSharingEnabled,
    int? updateIntervalMinutes,
    bool? dataSaverEnabled,
    DateTime? lastUpdated,
  }) {
    return LocationSharingSettings(
      sharingEnabled: sharingEnabled ?? this.sharingEnabled,
      backgroundSharingEnabled:
          backgroundSharingEnabled ?? this.backgroundSharingEnabled,
      updateIntervalMinutes:
          updateIntervalMinutes ?? this.updateIntervalMinutes,
      dataSaverEnabled: dataSaverEnabled ?? this.dataSaverEnabled,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Sync status for UI display
enum SyncStatus {
  synced, // All locations uploaded
  pending, // Has unsynced locations
  syncing, // Currently syncing
  offline, // No internet connection
  error, // Sync failed
}
