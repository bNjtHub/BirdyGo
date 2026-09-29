/// Thin wrapper over flutter_local_notifications for the « new species »
/// notifications (J6h), so the logic can be tested with a fake.
///
/// iOS: the same code path works once the notification permission is asked
/// (see fork/PLAN.md, Phase iOS); the channel settings are Android only.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_images.dart';

/// Android channel of the « new species » notifications.
const String kNewSpeciesChannelId = 'birdygo_new_species';

/// What the notifier needs from the notification system.
abstract class NotificationsGateway {
  /// Asks for the notification permission; true when granted.
  Future<bool> requestPermission();

  /// Posts one species notification, grouped under [groupKey], with its
  /// [images] when they could be prepared in time.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
    NotificationImages? images,
  });

  /// Posts (or updates) the group summary.
  Future<void> showSummary({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
  });

  /// Removes the notifications with these ids. Never `cancelAll`: that would
  /// also remove the foreground-service notification.
  Future<void> cancel(Iterable<int> ids);
}

/// Details of a species notification (or of the group summary). With
/// [images]: photo as large icon, expanding shows the big picture.
NotificationDetails speciesNotificationDetails({
  required String groupKey,
  required String channelName,
  required String channelDescription,
  required bool summary,
  NotificationImages? images,
}) {
  final icon = images?.largeIcon;
  final big = images?.bigPicture;
  return NotificationDetails(
    android: AndroidNotificationDetails(
      kNewSpeciesChannelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      groupKey: groupKey,
      setAsGroupSummary: summary,
      // The summary stays quiet: only the species make a sound.
      groupAlertBehavior:
          summary ? GroupAlertBehavior.children : GroupAlertBehavior.all,
      largeIcon: icon == null ? null : ByteArrayAndroidBitmap(icon),
      styleInformation:
          big == null
              ? null
              : BigPictureStyleInformation(
                ByteArrayAndroidBitmap(big),
                hideExpandedLargeIcon: true,
              ),
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: groupKey),
  );
}

/// Real implementation on flutter_local_notifications.
class LocalNotificationsGateway implements NotificationsGateway {
  LocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<bool> _init() async {
    if (_initialized) return true;
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[LocalNotificationsGateway] init failed: $e');
    }
    return _initialized;
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      if (Platform.isAndroid) {
        final android =
            _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios =
          _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('[LocalNotificationsGateway] permission failed: $e');
      return false;
    }
  }

  Future<void> _post(
    int id,
    String title,
    String body,
    NotificationDetails details,
  ) async {
    if (!await _init()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      // Permission denied or platform unavailable: never disturb listening.
      debugPrint('[LocalNotificationsGateway] show failed: $e');
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
    NotificationImages? images,
  }) => _post(
    id,
    title,
    body,
    speciesNotificationDetails(
      groupKey: groupKey,
      channelName: channelName,
      channelDescription: channelDescription,
      summary: false,
      images: images,
    ),
  );

  @override
  Future<void> showSummary({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
  }) => _post(
    id,
    title,
    body,
    speciesNotificationDetails(
      groupKey: groupKey,
      channelName: channelName,
      channelDescription: channelDescription,
      summary: true,
    ),
  );

  @override
  Future<void> cancel(Iterable<int> ids) async {
    if (!await _init()) return;
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (e) {
        debugPrint('[LocalNotificationsGateway] cancel failed: $e');
      }
    }
  }
}
