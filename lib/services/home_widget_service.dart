import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../features/home/widgets/couple_hero_card.dart';
import '../providers/anniversary_provider.dart';
import '../providers/couple_provider.dart';
import '../providers/debug_provider.dart';
import '../providers/location_provider.dart';
import '../providers/user_provider.dart';

class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const MethodChannel _channel = MethodChannel(
    'com.jayiennelink.jayienne_link/home_widget',
  );

  String? _cachedUserPhotoUrl;
  String? _cachedUserAvatarPath;
  String? _cachedPartnerPhotoUrl;
  String? _cachedPartnerAvatarPath;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Downloads and caches avatar image into persistent app support storage so the widget works 100% offline.
  Future<String?> _resolveLocalAvatarPath(
    String? photoUrl, {
    required bool isUser,
  }) async {
    final fileName =
        isUser ? 'user_widget_avatar.png' : 'partner_widget_avatar.png';
    final dir = await getApplicationSupportDirectory();
    final persistentFile = File('${dir.path}/$fileName');

    if (photoUrl == null || photoUrl.trim().isEmpty) {
      return persistentFile.existsSync() ? persistentFile.path : null;
    }

    if (isUser &&
        photoUrl == _cachedUserPhotoUrl &&
        persistentFile.existsSync()) {
      return persistentFile.path;
    }
    if (!isUser &&
        photoUrl == _cachedPartnerPhotoUrl &&
        persistentFile.existsSync()) {
      return persistentFile.path;
    }

    try {
      final cachedFile = await DefaultCacheManager().getSingleFile(photoUrl);
      if (await cachedFile.exists()) {
        await cachedFile.copy(persistentFile.path);
        if (isUser) {
          _cachedUserPhotoUrl = photoUrl;
          _cachedUserAvatarPath = persistentFile.path;
        } else {
          _cachedPartnerPhotoUrl = photoUrl;
          _cachedPartnerAvatarPath = persistentFile.path;
        }
        return persistentFile.path;
      }
    } catch (_) {
      try {
        final response = await http
            .get(Uri.parse(photoUrl))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await persistentFile.writeAsBytes(response.bodyBytes, flush: true);
          if (isUser) {
            _cachedUserPhotoUrl = photoUrl;
            _cachedUserAvatarPath = persistentFile.path;
          } else {
            _cachedPartnerPhotoUrl = photoUrl;
            _cachedPartnerAvatarPath = persistentFile.path;
          }
          return persistentFile.path;
        }
      } catch (_) {}
    }

    if (persistentFile.existsSync()) {
      return persistentFile.path;
    }
    return isUser ? _cachedUserAvatarPath : _cachedPartnerAvatarPath;
  }

  /// Syncs live and offline couple data from providers to the Android Home Widget.
  Future<void> syncFromContext(
    BuildContext context, {
    bool? overrideExpanded,
    bool forceCapture = false,
  }) async {
    if (!Platform.isAndroid || _isSyncing) return;

    final now = DateTime.now();
    if (!forceCapture &&
        overrideExpanded == null &&
        _lastSyncTime != null &&
        now.difference(_lastSyncTime!).inSeconds < 12) {
      return;
    }

    _isSyncing = true;

    try {
      final userProvider = context.read<UserProvider>();
      final coupleProvider = context.read<CoupleProvider>();
      final anniversaryProvider = context.read<AnniversaryProvider>();
      final locationProvider = context.read<LocationProvider>();
      final debugProvider = context.read<DebugProvider?>();

      final user = userProvider.user;
      final partner = coupleProvider.partner;
      final anniversaryDate = anniversaryProvider.anniversaryDate;
      final outgoingAnniversary = coupleProvider.outgoingAnniversaryRequests;
      final pendingAnniversary =
          outgoingAnniversary.isNotEmpty ? outgoingAnniversary.first : null;

      final partnerLoc = locationProvider.partnerLocation;
      final isAppOnline = locationProvider.isOnline;
      final isPartnerOnline = debugProvider?.simulatedPartnerOnlineStatus ??
          (locationProvider.isPartnerOnline() ||
              (partner != null &&
                  isAppOnline &&
                  partnerLoc != null &&
                  partnerLoc.isRecent(threshold: const Duration(minutes: 3))));
      final partnerLastSeen =
          locationProvider.partnerLastSeen ?? partner?.updatedAt;

      String distanceString = '';
      final distanceMeters = locationProvider.distanceInMeters;
      if (distanceMeters != null &&
          locationProvider.myLatLng != null &&
          locationProvider.partnerLatLng != null) {
        final km = distanceMeters / 1000.0;
        if (km < 0.05) {
          distanceString = 'Together';
        } else if (km < 1.0) {
          distanceString = '${distanceMeters.toStringAsFixed(0)}m apart';
        } else {
          distanceString = '${km.toStringAsFixed(1)} km apart';
        }
      }

      final statusText = CoupleHeroCard.formatPartnerStatusText(
        isPartnerOnline: isPartnerOnline,
        partnerLastSeen: partnerLastSeen,
        short: true,
      );

      final userAvatarPath = await _resolveLocalAvatarPath(
        user?.photoUrl,
        isUser: true,
      );
      final partnerAvatarPath = await _resolveLocalAvatarPath(
        partner?.photoUrl,
        isUser: false,
      );

      _lastSyncTime = DateTime.now();

      final payload = <String, dynamic>{
        'has_date': anniversaryProvider.hasAnniversaryDate,
        'anniversary_epoch_ms': anniversaryDate?.millisecondsSinceEpoch ?? 0,
        'user_name': user?.displayName ?? 'You',
        'partner_name': partner?.displayName ?? 'Partner',
        'user_zodiac': user?.zodiacSign ?? '',
        'partner_zodiac': partner?.zodiacSign ?? '',
        'is_linked': partner != null || coupleProvider.isLinked,
        'is_partner_online': isPartnerOnline,
        'partner_last_seen_ms': partnerLastSeen?.millisecondsSinceEpoch ?? 0,
        'partner_status_text': statusText,
        'distance_string':
            distanceString.isNotEmpty ? distanceString : 'Location active',
        'my_battery_level': locationProvider.batteryLevel,
        'my_is_charging': locationProvider.isMyCharging,
        'partner_battery_level': locationProvider.partnerBatteryLevel ?? -1,
        'partner_is_charging': locationProvider.isPartnerCharging,
        'pending_anniversary_text': pendingAnniversary != null
            ? 'Anniversary request pending: ${DateFormat('MMMM d, yyyy').format(pendingAnniversary.proposedDate)}'
            : '',
        'user_avatar_path': userAvatarPath ?? '',
        'partner_avatar_path': partnerAvatarPath ?? '',
        if (overrideExpanded != null) 'is_expanded': overrideExpanded,
      };

      await _channel.invokeMethod('syncWidgetData', payload);
    } catch (_) {
      // Ignore platform channel errors
    } finally {
      _isSyncing = false;
    }
  }

  /// Sets whether the home screen widget displays Expanded (Unhidden) or Compact (Hidden).
  Future<void> setWidgetExpanded(bool isExpanded) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setWidgetExpanded', {
        'is_expanded': isExpanded,
      });
    } catch (_) {}
  }

  /// Gets the current Expanded / Compact state of the home screen widget.
  Future<bool> getWidgetExpanded() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('getWidgetExpanded');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns how many instances of the Couple Card widget are currently pinned.
  Future<int> getPinnedWidgetCount() async {
    if (!Platform.isAndroid) return 0;
    try {
      final count = await _channel.invokeMethod<int>('getPinnedCount');
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Syncs data and triggers Android's native Pin App Widget dialog.
  Future<bool> requestPinWidget(
    BuildContext context, {
    required bool isExpanded,
  }) async {
    if (!Platform.isAndroid) return false;
    await syncFromContext(
      context,
      overrideExpanded: isExpanded,
      forceCapture: true,
    );
    try {
      final result = await _channel.invokeMethod<bool>('requestPinWidget', {
        'is_expanded': isExpanded,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
