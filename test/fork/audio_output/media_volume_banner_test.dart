import 'package:birdnet_live/fork/audio_output/media_volume.dart';
import 'package:birdnet_live/fork/audio_output/media_volume_config.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/live/media_volume_banner.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVolume extends MediaVolume {
  _FakeVolume(this.value);
  double? value;
  final List<double> set = [];

  @override
  Future<double?> level() async => value;

  @override
  Future<void> setLevel(double level) async => set.add(level);

  @override
  Stream<double?> get changes => Stream<double?>.value(value);
}

Future<_FakeVolume> _pump(WidgetTester tester, double? level) async {
  final fake = _FakeVolume(level);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mediaVolumeProvider.overrideWithValue(fake)],
      child: MaterialApp(
        theme: BirdyTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('fr')],
        locale: const Locale('fr'),
        home: const Scaffold(body: MediaVolumeBanner()),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

void main() {
  test('state from level', () {
    expect(MediaVolumeState.of(null), isNull);
    expect(MediaVolumeState.of(0), MediaVolumeState.muted);
    expect(MediaVolumeState.of(MediaVolumeConfig.lowBelow - 0.01),
        MediaVolumeState.low);
    expect(MediaVolumeState.of(MediaVolumeConfig.lowBelow), isNull);
    expect(MediaVolumeState.of(1), isNull);
  });

  testWidgets('muted shows the banner', (tester) async {
    await _pump(tester, 0);
    expect(find.text('Volume coupé'), findsOneWidget);
    expect(find.text('Monter le son'), findsOneWidget);
  });

  testWidgets('low shows the banner', (tester) async {
    await _pump(tester, 0.1);
    expect(find.text('Volume bas'), findsOneWidget);
  });

  testWidgets('ok and unknown hide it', (tester) async {
    await _pump(tester, 0.5);
    expect(find.text('Monter le son'), findsNothing);
    await _pump(tester, null);
    expect(find.text('Monter le son'), findsNothing);
  });

  testWidgets('button sets the configured level', (tester) async {
    final fake = await _pump(tester, 0);
    await tester.tap(find.text('Monter le son'));
    await tester.pump();
    expect(fake.set, [MediaVolumeConfig.comfortable]);
  });
}
