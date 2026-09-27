/// Keeps a Live listening session alive in the background (fork/PLAN.md
/// J2b): an Android foreground service of type microphone, like the Survey
/// and ARU modes, with a quiet notification that opens the app.
///
/// iOS: nothing here yet; the iOS phase needs `UIBackgroundModes: audio`
/// (see fork/PLAN.md, Phase iOS).
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/foreground_service_guard.dart';

/// Service id of the Live foreground service (Survey 256, ARU 512).
const int kLiveForegroundServiceId = 768;

/// Top-level callback required by flutter_foreground_task.
@pragma('vm:entry-point')
void liveTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_LiveTaskHandler());
}

/// The listening itself runs in the main isolate; this handler only opens
/// the app from the notification.
class _LiveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'open') FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}

/// What the Live screen needs from the background service.
abstract class LiveBackground {
  /// True while the foreground service keeps the listening alive.
  bool get isRunning;

  /// Starts the service; returns false when it could not (another mode owns
  /// it, not Android, or Android refused).
  Future<bool> start();

  Future<void> stop();
}

/// Android implementation on flutter_foreground_task.
class AndroidLiveBackground implements LiveBackground {
  bool _running = false;
  int _generation = 0;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> start() async {
    if (!Platform.isAndroid || _running) return _running;
    final generation = ++_generation;
    if (!ForegroundServiceGuard.tryClaim(ForegroundServiceOwner.live)) {
      debugPrint(
        '[LiveBackground] service owned by ${ForegroundServiceGuard.owner}',
      );
      return false;
    }
    try {
      final l10n = await _localizations();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'birdygo_live_fg',
          channelName: l10n.forkBackgroundChannel,
          channelDescription: l10n.forkBackgroundChannel,
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          playSound: false,
          enableVibration: false,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );
      if (await FlutterForegroundTask.checkNotificationPermission() !=
          NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (generation != _generation) return false;
      final result = await FlutterForegroundTask.startService(
        serviceId: kLiveForegroundServiceId,
        notificationTitle: l10n.forkBackgroundTitle,
        notificationText: l10n.forkBackgroundText,
        notificationIcon: const NotificationIcon(
          metaDataName: 'com.birdnet.live.notification_icon',
        ),
        notificationButtons: [
          NotificationButton(id: 'open', text: l10n.notificationOpen),
        ],
        callback: liveTaskCallback,
      ).timeout(const Duration(seconds: 3));
      _running = result is ServiceRequestSuccess;
    } catch (error) {
      debugPrint('[LiveBackground] start failed: $error');
      _running = false;
    }
    if (!_running) ForegroundServiceGuard.release(ForegroundServiceOwner.live);
    return _running;
  }

  @override
  Future<void> stop() async {
    ++_generation;
    if (!_running) {
      ForegroundServiceGuard.release(ForegroundServiceOwner.live);
      return;
    }
    try {
      await FlutterForegroundTask.stopService().timeout(
        const Duration(seconds: 2),
      );
    } catch (error) {
      debugPrint('[LiveBackground] stop failed: $error');
    } finally {
      _running = false;
      ForegroundServiceGuard.release(ForegroundServiceOwner.live);
    }
  }

  static Future<AppLocalizations> _localizations() {
    final device = PlatformDispatcher.instance.locale;
    final locale = AppLocalizations.supportedLocales.firstWhere(
      (l) => l.languageCode == device.languageCode,
      orElse: () => const Locale('en'),
    );
    return AppLocalizations.delegate.load(locale);
  }
}

/// App-wide Live background service.
final liveBackgroundProvider = Provider<LiveBackground>(
  (ref) => AndroidLiveBackground(),
);
