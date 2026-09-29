/// Launcher icon per bird theme (J6i). Common interface: Android goes
/// through a method channel to `AppIconChannel.kt` (activity-aliases, applied
/// when the app goes to the background); other platforms do nothing for now
/// (iOS: see fork/PLAN.md, iOS section).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/birdy_theme_choice.dart';
import '../settings/fork_prefs.dart';

abstract class AppIcon {
  /// Asks for [bird]'s launcher icon. The switch itself may happen later.
  Future<void> set(BirdyBird bird);
}

class AndroidAppIcon extends AppIcon {
  static const MethodChannel channel = MethodChannel(
    'fr.justcodeit.birdygo/app_icon',
  );

  @override
  Future<void> set(BirdyBird bird) async {
    try {
      await channel.invokeMethod<void>('setIcon', bird.name);
    } on PlatformException {
      // The icon stays as it was.
    } on MissingPluginException {
      // Same (tests, other engines).
    }
  }
}

class NoopAppIcon extends AppIcon {
  @override
  Future<void> set(BirdyBird bird) async {}
}

final appIconProvider = Provider<AppIcon>(
  (ref) =>
      defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? AndroidAppIcon()
          : NoopAppIcon(),
);

/// Keeps the launcher icon in line with the chosen bird: once at start (the
/// native side ignores it when the icon already matches), then on each
/// change. Watched from the app root.
final appIconSyncProvider = Provider<void>((ref) {
  final icon = ref.read(appIconProvider);
  ref.listen<BirdyBird>(
    birdyBirdProvider,
    (_, bird) => icon.set(bird),
    fireImmediately: true,
  );
});
