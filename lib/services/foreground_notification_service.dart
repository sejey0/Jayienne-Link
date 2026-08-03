import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for managing foreground service notifications.
/// Required on Android to show persistent notification during background tracking.
class ForegroundNotificationService {
  static ForegroundNotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'location_tracking';
  static const String _channelName = 'Location Tracking';
  static const String _channelDescription =
      'Persistent notification while sharing location';
  static const int _notificationId = 8888;

  bool _isShowing = false;

  ForegroundNotificationService._();

  static ForegroundNotificationService get instance {
    _instance ??= ForegroundNotificationService._();
    return _instance!;
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (kIsWeb) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android 8+
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
    }

    debugPrint('ForegroundNotificationService initialized');
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - could open location screen
    debugPrint('Foreground notification tapped');
  }

  /// Show persistent notification for background tracking
  Future<void> showTrackingNotification({
    String title = 'Sharing location',
    String body = 'Your partner can see your location',
  }) async {
    if (kIsWeb || _isShowing) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      title,
      body,
      details,
    );

    _isShowing = true;
    debugPrint('Tracking notification shown');
  }

  /// Update the notification content
  Future<void> updateNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    if (!_isShowing) {
      await showTrackingNotification(title: title, body: body);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      title,
      body,
      details,
    );
  }

  /// Hide the tracking notification
  Future<void> hideTrackingNotification() async {
    if (kIsWeb) return;
    await _notifications.cancel(_notificationId);
    _isShowing = false;
    debugPrint('Tracking notification hidden');
  }

  /// Check if notification is currently showing
  bool get isShowing => _isShowing;

  /// Show sync status notification (temporary)
  Future<void> showSyncNotification({
    required int syncedCount,
    bool isError = false,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'sync_status',
      'Sync Status',
      channelDescription: 'Location sync status notifications',
      importance: Importance.low,
      priority: Priority.low,
      autoCancel: true,
      playSound: false,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId + 1,
      isError ? 'Sync failed' : 'Locations synced',
      isError
          ? 'Will retry when online'
          : '$syncedCount location${syncedCount > 1 ? 's' : ''} uploaded',
      details,
    );
  }
}
