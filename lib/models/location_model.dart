import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a location point captured from the device GPS.
/// Designed for offline-first storage with sync status tracking.
class LocationModel {
  final int? id; // SQLite auto-increment ID (null for Firestore entries)
  final String ownerId; // User ID who owns this location
  final double latitude;
  final double longitude;
  final double accuracy; // GPS accuracy in meters
  final DateTime timestamp;
  final bool isSynced; // Whether synced to Firestore
  final String? firestoreId; // Firestore document ID after sync
  final String? partnerId; // Partner's ID (for received locations)
  final LocationSource source; // Where this location came from

  LocationModel({
    this.id,
    required this.ownerId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.isSynced = false,
    this.firestoreId,
    this.partnerId,
    this.source = LocationSource.local,
  });

  /// Create from SQLite row
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'] as int?,
      ownerId: map['owner_id'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      accuracy: map['accuracy'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isSynced: (map['is_synced'] as int) == 1,
      firestoreId: map['firestore_id'] as String?,
      partnerId: map['partner_id'] as String?,
      source: LocationSource.values[map['source'] as int? ?? 0],
    );
  }

  /// Convert to SQLite row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'owner_id': ownerId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
      'firestore_id': firestoreId,
      'partner_id': partnerId,
      'source': source.index,
    };
  }

  /// Create from Firestore document
  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      firestoreId: doc.id,
      ownerId: data['owner_id'] as String,
      latitude: data['latitude'] as double,
      longitude: data['longitude'] as double,
      accuracy: (data['accuracy'] as num).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isSynced: true,
      partnerId: data['partner_id'] as String?,
      source: LocationSource.partner,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'owner_id': ownerId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': Timestamp.fromDate(timestamp),
      'partner_id': partnerId,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with updated fields
  LocationModel copyWith({
    int? id,
    String? ownerId,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    bool? isSynced,
    String? firestoreId,
    String? partnerId,
    LocationSource? source,
  }) {
    return LocationModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      firestoreId: firestoreId ?? this.firestoreId,
      partnerId: partnerId ?? this.partnerId,
      source: source ?? this.source,
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
  final DateTime? lastUpdated;

  LocationSharingSettings({
    this.sharingEnabled = false,
    this.backgroundSharingEnabled = false,
    this.updateIntervalMinutes = 15,
    this.lastUpdated,
  });

  factory LocationSharingSettings.fromMap(Map<String, dynamic> map) {
    return LocationSharingSettings(
      // SQLite stores booleans as integers (0/1)
      sharingEnabled: (map['sharing_enabled'] == 1 || map['sharing_enabled'] == true),
      backgroundSharingEnabled:
          (map['background_sharing_enabled'] == 1 || map['background_sharing_enabled'] == true),
      updateIntervalMinutes: map['update_interval_minutes'] as int? ?? 15,
      lastUpdated: map['last_updated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // SQLite doesn't support bool - use 0/1 integers
      'sharing_enabled': sharingEnabled ? 1 : 0,
      'background_sharing_enabled': backgroundSharingEnabled ? 1 : 0,
      'update_interval_minutes': updateIntervalMinutes,
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
    };
  }

  LocationSharingSettings copyWith({
    bool? sharingEnabled,
    bool? backgroundSharingEnabled,
    int? updateIntervalMinutes,
    DateTime? lastUpdated,
  }) {
    return LocationSharingSettings(
      sharingEnabled: sharingEnabled ?? this.sharingEnabled,
      backgroundSharingEnabled:
          backgroundSharingEnabled ?? this.backgroundSharingEnabled,
      updateIntervalMinutes:
          updateIntervalMinutes ?? this.updateIntervalMinutes,
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
