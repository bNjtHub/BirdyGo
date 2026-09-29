import 'package:birdnet_live/fork/audio_output/media_volume.dart';
import 'package:birdnet_live/fork/audio_output/media_volume_config.dart';
import 'package:birdnet_live/fork/audio_output/volume_alert_block.dart';
import 'package:birdnet_live/fork/audio_output/volume_guard.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'media_volume_banner_test.dart' show FakeVolume;

late WidgetRef _ref;
late BuildContext _context;

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _ref = ref;
    _context = context;
    return const SizedBox.expand();
  }
}

Future<void> _pump(
  WidgetTester tester,
  FakeVolume fake,
  VolumePromptThrottle throttle, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaVolumeProvider.overrideWithValue(fake),
        volumePromptThrottleProvider.overrideWithValue(throttle),
      ],
      child: MaterialApp(
        theme: theme ?? BirdyTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('fr')],
        locale: const Locale('fr'),
        home: const Scaffold(body: _Host()),
      ),
    ),
  );
}

Future<bool> _check(WidgetTester tester) async {
  final result = (await tester.runAsync(() => checkAudible(_context, _ref)))!;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return result;
}

void main() {
  testWidgets('prompts when muted, and Monter le son sets 40 %', (tester) async {
    final fake = FakeVolume(0);
    await _pump(tester, fake, VolumePromptThrottle());
    expect(await _check(tester), isTrue);
    expect(find.text('Son coupé'), findsOneWidget);
    await tester.tap(find.text('Monter le son'));
    await tester.pump();
    expect(fake.set, [0.4]);
    await tester.pumpAndSettle();
    expect(find.text('Son coupé'), findsNothing);
  });

  testWidgets('prompts when low, in the dark theme too', (tester) async {
    await _pump(
      tester,
      FakeVolume(0.1),
      VolumePromptThrottle(),
      theme: BirdyTheme.dark(),
    );
    expect(await _check(tester), isTrue);
    expect(find.text('Son faible'), findsOneWidget);
    await tester.pump(MediaVolumeConfig.promptDuration);
    await tester.pumpAndSettle();
    expect(find.text('Son faible'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('floating toast is blurred and opaque (dark: $dark)', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeVolume(0),
        VolumePromptThrottle(),
        theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
      );
      expect(await _check(tester), isTrue);
      final block = find.byType(VolumeAlertBlock);
      expect(
        find.descendant(of: block, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(of: block, matching: find.byType(DecoratedBox))
            .first,
      );
      final color = (box.decoration as BoxDecoration).color!;
      expect(color.a, 1.0);
      final c = dark ? BirdyColors.dark : BirdyColors.light;
      expect(color, Color.alphaBlend(c.orioleContainer, c.surface1));
      await tester.pump(MediaVolumeConfig.promptDuration);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('silent when the volume is fine or unknown', (tester) async {
    await _pump(tester, FakeVolume(0.5), VolumePromptThrottle());
    expect(await _check(tester), isFalse);
    expect(find.text('Monter le son'), findsNothing);
    await _pump(tester, FakeVolume(null), VolumePromptThrottle());
    expect(await _check(tester), isFalse);
    expect(find.text('Monter le son'), findsNothing);
  });

  testWidgets('throttled: once per cooldown', (tester) async {
    var now = DateTime(2026, 9, 29, 10);
    final throttle = VolumePromptThrottle(clock: () => now);
    await _pump(tester, FakeVolume(0), throttle);
    expect(await _check(tester), isTrue);
    now = now.add(MediaVolumeConfig.promptCooldown ~/ 2);
    expect(await _check(tester), isFalse);
    now = now.add(MediaVolumeConfig.promptCooldown);
    expect(await _check(tester), isTrue);
    await tester.pump(MediaVolumeConfig.promptDuration);
    await tester.pumpAndSettle();
  });
}
