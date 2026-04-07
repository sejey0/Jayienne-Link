import 'package:flutter_test/flutter_test.dart';
import 'package:jayienne_link/services/supabase_location_sync_service.dart';

void main() {
  group('SyncResult', () {
    test('creates successful result', () {
      final result = SyncResult(
        success: true,
        message: 'Synced 5 locations',
        syncedCount: 5,
      );

      expect(result.success, true);
      expect(result.message, 'Synced 5 locations');
      expect(result.syncedCount, 5);
      expect(result.failedCount, 0);
    });

    test('creates failed result', () {
      final result = SyncResult(
        success: false,
        message: 'No internet connection',
        syncedCount: 0,
        failedCount: 3,
      );

      expect(result.success, false);
      expect(result.message, 'No internet connection');
      expect(result.syncedCount, 0);
      expect(result.failedCount, 3);
    });

    test('toString returns readable format', () {
      final result = SyncResult(
        success: true,
        message: 'Done',
        syncedCount: 10,
      );

      expect(result.toString(), contains('success: true'));
      expect(result.toString(), contains('synced: 10'));
    });
  });

  group('Sync Logic Scenarios', () {
    test('offline scenario - locations should queue', () {
      // Simulating: User hikes in mountains (no signal)
      // Expected: Locations save to SQLite, marked as unsynced

      final locations = <Map<String, dynamic>>[];

      // Simulate capturing 5 locations while offline
      for (int i = 0; i < 5; i++) {
        locations.add({
          'latitude': 14.5995 + (i * 0.001),
          'longitude': 120.9842 + (i * 0.001),
          'accuracy': 10.0,
          'timestamp': DateTime.now().subtract(Duration(minutes: i * 5)),
          'is_synced': false, // Offline - not synced
        });
      }

      // All locations should be unsynced
      expect(locations.every((loc) => loc['is_synced'] == false), true);
      expect(locations.length, 5);
    });

    test('coming online scenario - batch sync should work', () {
      // Simulating: User returns to town (signal restored)
      // Expected: All queued locations sync in batch

      final unsyncedLocations = List.generate(
          10,
          (i) => {
                'id': i,
                'is_synced': false,
              });

      // Simulate batch sync
      final syncedIds = <int>[];
      const batchSize = 5;

      for (var i = 0; i < unsyncedLocations.length; i += batchSize) {
        final batch = unsyncedLocations.skip(i).take(batchSize);
        for (final loc in batch) {
          syncedIds.add(loc['id'] as int);
        }
      }

      // All locations should be synced
      expect(syncedIds.length, 10);
      expect(syncedIds, containsAll([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
    });

    test('partner offline scenario - should show cached location', () {
      // Simulating: Partner checks app while you're offline
      // Expected: Shows last known location from cache

      final cachedPartnerLocation = {
        'latitude': 14.5995,
        'longitude': 120.9842,
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'source': 'partner',
      };

      // Cache exists
      expect(cachedPartnerLocation['latitude'], isNotNull);

      // Calculate time since last update
      final lastUpdate = cachedPartnerLocation['timestamp'] as DateTime;
      final timeSince = DateTime.now().difference(lastUpdate);

      // Should show "(offline)" indicator for old timestamps
      expect(timeSince.inHours, greaterThanOrEqualTo(1));
    });

    test('conflict resolution - latest timestamp wins', () {
      // Simulating: Same location synced from two devices
      // Expected: The more recent timestamp is kept

      final location1 = {
        'latitude': 14.5995,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 10)),
      };

      final location2 = {
        'latitude': 14.5996,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      };

      // Location2 is more recent, should win
      final winner = (location1['timestamp'] as DateTime)
              .isAfter(location2['timestamp'] as DateTime)
          ? location1
          : location2;

      expect(winner['latitude'], 14.5996);
    });

    test('retention policy - old locations should be cleaned up', () {
      // Simulating: Cleanup of locations older than 7 days

      const retentionDays = 7;
      final cutoff =
          DateTime.now().subtract(const Duration(days: retentionDays));

      final locations = [
        {
          'timestamp': DateTime.now().subtract(const Duration(days: 3)),
          'is_synced': true
        },
        {
          'timestamp': DateTime.now().subtract(const Duration(days: 5)),
          'is_synced': true
        },
        {
          'timestamp': DateTime.now().subtract(const Duration(days: 8)),
          'is_synced': true
        }, // Should be deleted
        {
          'timestamp': DateTime.now().subtract(const Duration(days: 10)),
          'is_synced': true
        }, // Should be deleted
        {
          'timestamp': DateTime.now().subtract(const Duration(days: 8)),
          'is_synced': false
        }, // Keep - not synced
      ];

      // Filter locations to keep (recent OR not synced yet)
      final locationsToKeep = locations.where((loc) {
        final timestamp = loc['timestamp'] as DateTime;
        final isSynced = loc['is_synced'] as bool;
        return timestamp.isAfter(cutoff) || !isSynced;
      }).toList();

      // Should keep 3 locations (2 recent + 1 unsynced old one)
      expect(locationsToKeep.length, 3);
    });

    test('exponential backoff on retry', () {
      // Simulating: Retry delays for failed sync attempts

      const baseDelay = Duration(seconds: 5);
      const maxRetries = 3;

      final delays = <Duration>[];
      for (var attempt = 0; attempt < maxRetries; attempt++) {
        // Exponential backoff: 5s, 10s, 20s
        final delay = baseDelay * (1 << attempt);
        delays.add(delay);
      }

      expect(delays[0].inSeconds, 5);
      expect(delays[1].inSeconds, 10);
      expect(delays[2].inSeconds, 20);
    });
  });
}
