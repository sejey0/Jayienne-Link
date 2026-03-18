import 'package:flutter_test/flutter_test.dart';
import 'package:jayienne_link/models/location_model.dart';

void main() {
  group('LocationModel', () {
    test('creates location with required fields', () {
      final location = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );

      expect(location.ownerId, 'user123');
      expect(location.latitude, 14.5995);
      expect(location.longitude, 120.9842);
      expect(location.accuracy, 10.0);
      expect(location.isSynced, false);
      expect(location.source, LocationSource.local);
    });

    test('converts to and from map correctly', () {
      final now = DateTime.now();
      final location = LocationModel(
        id: 1,
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: now,
        isSynced: true,
        firestoreId: 'firestore123',
        partnerId: 'partner456',
        source: LocationSource.background,
      );

      final map = location.toMap();
      final restored = LocationModel.fromMap(map);

      expect(restored.id, location.id);
      expect(restored.ownerId, location.ownerId);
      expect(restored.latitude, location.latitude);
      expect(restored.longitude, location.longitude);
      expect(restored.accuracy, location.accuracy);
      expect(restored.isSynced, location.isSynced);
      expect(restored.firestoreId, location.firestoreId);
      expect(restored.partnerId, location.partnerId);
      expect(restored.source, location.source);
    });

    test('isRecent returns true for recent timestamps', () {
      final recentLocation = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      expect(recentLocation.isRecent(), true);
    });

    test('isRecent returns false for old timestamps', () {
      final oldLocation = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      expect(oldLocation.isRecent(), false);
    });

    test('timeAgo returns correct string for different durations', () {
      // Just now
      final justNow = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );
      expect(justNow.timeAgo, 'Just now');

      // Minutes ago
      final minutesAgo = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      expect(minutesAgo.timeAgo, '30 min ago');

      // Hours ago
      final hoursAgo = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      );
      expect(hoursAgo.timeAgo, '5 hours ago');

      // Days ago
      final daysAgo = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(daysAgo.timeAgo, '3 days ago');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: DateTime.now(),
        isSynced: false,
      );

      final updated = original.copyWith(
        isSynced: true,
        firestoreId: 'firestore123',
      );

      expect(updated.isSynced, true);
      expect(updated.firestoreId, 'firestore123');
      expect(updated.latitude, original.latitude);
      expect(updated.ownerId, original.ownerId);
    });

    test('equality works correctly', () {
      final now = DateTime.now();
      final location1 = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: now,
      );

      final location2 = LocationModel(
        ownerId: 'user123',
        latitude: 14.5995,
        longitude: 120.9842,
        accuracy: 10.0,
        timestamp: now,
      );

      expect(location1, equals(location2));
    });
  });

  group('LocationSharingSettings', () {
    test('creates with default values', () {
      final settings = LocationSharingSettings();

      expect(settings.sharingEnabled, false);
      expect(settings.backgroundSharingEnabled, false);
      expect(settings.updateIntervalMinutes, 15);
    });

    test('converts to and from map correctly', () {
      final settings = LocationSharingSettings(
        sharingEnabled: true,
        backgroundSharingEnabled: true,
        updateIntervalMinutes: 30,
        lastUpdated: DateTime.now(),
      );

      final map = settings.toMap();
      final restored = LocationSharingSettings.fromMap(map);

      expect(restored.sharingEnabled, settings.sharingEnabled);
      expect(
          restored.backgroundSharingEnabled, settings.backgroundSharingEnabled);
      expect(restored.updateIntervalMinutes, settings.updateIntervalMinutes);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = LocationSharingSettings();

      final updated = original.copyWith(
        sharingEnabled: true,
        updateIntervalMinutes: 30,
      );

      expect(updated.sharingEnabled, true);
      expect(updated.updateIntervalMinutes, 30);
      expect(
          updated.backgroundSharingEnabled, original.backgroundSharingEnabled);
    });
  });

  group('SyncStatus', () {
    test('all sync statuses are defined', () {
      expect(SyncStatus.values.length, 5);
      expect(SyncStatus.values.contains(SyncStatus.synced), true);
      expect(SyncStatus.values.contains(SyncStatus.pending), true);
      expect(SyncStatus.values.contains(SyncStatus.syncing), true);
      expect(SyncStatus.values.contains(SyncStatus.offline), true);
      expect(SyncStatus.values.contains(SyncStatus.error), true);
    });
  });

  group('LocationSource', () {
    test('all location sources are defined', () {
      expect(LocationSource.values.length, 3);
      expect(LocationSource.values.contains(LocationSource.local), true);
      expect(LocationSource.values.contains(LocationSource.partner), true);
      expect(LocationSource.values.contains(LocationSource.background), true);
    });
  });
}
