import 'package:birdnet_live/fork/audio_output/media_volume.dart';
import 'package:birdnet_live/fork/audio_output/media_volume_config.dart';
import 'package:birdnet_live/fork/audio_output/media_volume_state.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/live/media_volume_banner.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVolume extends MediaVolume {
  FakeVolume(this.value);
  double? value;
  final List<double> set = [];

  @override
  Future<double?> level() async => value;

  @override
  Future<void> setLevel(double level) async => set.add(level);

  @override
  Stream<double?> get changes => Stream<double?>.value(value);
}

Widget _app(FakeVolume fake, ThemeData theme, {Widget? child}) {
  return ProviderScope(
    overrides: [mediaVolumeProvider.overrideWithValue(fake)],
    child: MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('fr')],
      locale: const Locale('fr'),
      home: Scaffold(body: child ?? const MediaVolumeBanner()),
    ),
  );
}

Future<FakeVolume> _pump(
  WidgetTester tester,
  double? level, {
  ThemeData? theme,
}) async {
  final fake = FakeVolume(level);
  await tester.pumpWidget(_app(fake, theme ?? BirdyTheme.light()));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  test('state from level', () {
    expect(MediaVolumeState.of(null), isNull);
    expect(MediaVolumeState.of(0), MediaVolumeState.muted);
    expect(
      MediaVolumeState.of(MediaVolumeConfig.lowBelow - 0.01),
      MediaVolumeState.low,
    );
    expect(MediaVolumeState.of(MediaVolumeConfig.lowBelow), isNull);
    expect(MediaVolumeState.of(1), isNull);
  });

  test('comfortable level is 40 %', () {
    expect(MediaVolumeConfig.comfortable, 0.4);
  });

  testWidgets('muted shows the banner', (tester) async {
    await _pump(tester, 0);
    expect(find.text('Son coupé'), findsOneWidget);
    expect(find.text('Monter le son'), findsOneWidget);
  });

  testWidgets('low shows the banner in the dark theme too', (tester) async {
    await _pump(tester, 0.1, theme: BirdyTheme.dark());
    expect(find.text('Son faible'), findsOneWidget);
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

  testWidgets('appears and folds away without throwing', (tester) async {
    final fake = FakeVolume(0.5);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaVolumeProvider.overrideWithValue(fake),
          mediaVolumeLevelProvider.overrideWith(
            (ref) => Stream<double?>.fromIterable(const [0.5, 0.0, 0.5]),
          ),
        ],
        child: MaterialApp(
          theme: BirdyTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('fr')],
          locale: const Locale('fr'),
          home: const Scaffold(body: MediaVolumeBanner()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
