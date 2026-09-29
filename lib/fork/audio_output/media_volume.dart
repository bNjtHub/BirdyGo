/// Phone media volume (STREAM_MUSIC on Android), as a level from 0 to 1.
/// Common interface: Android goes through a method channel, other
/// platforms report « unknown » (null) so no banner shows.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_volume_config.dart';

abstract class MediaVolume {
  /// Current level in 0..1, null when unknown or unsupported.
  Future<double?> level();

  /// Sets the level (0..1) and shows the system volume panel.
  Future<void> setLevel(double level);

  /// Level changes (hardware keys included), sampled while listened to.
  Stream<double?> get changes async* {
    yield await level();
    yield* Stream.periodic(
      MediaVolumeConfig.pollInterval,
    ).asyncMap((_) => level());
  }
}

class AndroidMediaVolume extends MediaVolume {
  static const MethodChannel _channel = MethodChannel(
    'fr.justcodeit.birdygo/media_volume',
  );

  @override
  Future<double?> level() async {
    try {
      return await _channel.invokeMethod<double>('level');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> setLevel(double level) async {
    try {
      await _channel.invokeMethod<void>('setLevel', level);
    } on PlatformException {
      // Nothing to do: the banner stays until the user acts.
    } on MissingPluginException {
      // Same.
    }
  }
}

/// Non-Android platforms (iOS: see fork/PLAN.md, iOS section).
class NoopMediaVolume extends MediaVolume {
  @override
  Future<double?> level() async => null;

  @override
  Future<void> setLevel(double level) async {}

  @override
  Stream<double?> get changes => Stream<double?>.value(null);
}

final mediaVolumeProvider = Provider<MediaVolume>(
  (ref) =>
      defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? AndroidMediaVolume()
          : NoopMediaVolume(),
);

/// Live level while a listener is mounted (polling stops otherwise).
final mediaVolumeLevelProvider = StreamProvider.autoDispose<double?>(
  (ref) => ref.watch(mediaVolumeProvider).changes,
);
