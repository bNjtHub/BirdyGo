import 'dart:io' show Platform;

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/fork/live/live_listening_layout.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/reliability/reliability_badge.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

/// Goldens of the listening screen in the four bird themes, light and dark
/// (J7: it follows the app theme). The layout is fed fixed rows and no
/// microphone, so nothing moves. The references are rasterised on Windows,
/// so the pixel comparison runs only there. Regenerate with
/// `flutter test --update-goldens test/fork/goldens` on Windows.
final _t0 = DateTime(2026, 9, 30, 7, 0);

LiveTableEntry _entry(String name, String common, int second, double score) {
  final record = DetectionRecord(
    scientificName: name,
    commonName: common,
    confidence: score,
    timestamp: _t0.add(Duration(seconds: second)),
  );
  return LiveTableEntry(
    scientificName: name,
    commonName: common,
    sessionCount: 2,
    total: 12,
    lastHeard: _t0.add(Duration(seconds: second)),
    record: record,
    singing: false,
  );
}

Widget _live(BirdyBird bird, bool dark) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? BirdyTheme.dark(bird: bird) : BirdyTheme.light(bird: bird),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: LiveListeningLayout(
      statusText: 'En écoute',
      live: false,
      capturing: false,
      elapsed: () => const Duration(minutes: 3, seconds: 12),
      entries: [
        _entry('Turdus merula', 'Merle noir', 30, 0.92),
        _entry('Erithacus rubecula', 'Rouge-gorge familier', 20, 0.66),
        _entry('Parus major', 'Mésange charbonnière', 10, 0.4),
      ],
      spans: const [],
      displaySeconds: 10,
      spectrogramBuilder: (_) => const SizedBox.expand(),
      phase: LiveControlPhase.active,
      badgeFor:
          (e, {required compact}) => ReliabilityBadge(
            level: reliabilityFor(
              score: e.bestScore,
              presence: const GeoPresence(unexpected: false),
            ),
            compact: compact,
          ),
      onStart: () {},
      onStop: () {},
      onTogglePause: () {},
      onBack: () {},
      onSettings: () {},
      onHelp: () {},
    ),
  ),
);

void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'Live ${bird.name} $mode',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_live(bird, dark));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('live_${bird.name}_$mode.png'),
          );
        },
        tags: ['golden'],
        skip: !Platform.isWindows,
      );
    }
  }
}
