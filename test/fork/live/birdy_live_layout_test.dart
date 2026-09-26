import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/live/birdy_live_layout.dart';
import 'package:birdnet_live/fork/live/live_board.dart';
import 'package:birdnet_live/fork/live/live_board_model.dart';
import 'package:birdnet_live/fork/live/live_spectrum.dart';
import 'package:birdnet_live/fork/live/spectrum_marks.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 26, 7);

LiveBoardEntry _entry(String name) => LiveBoardEntry(
  scientificName: name,
  commonName: name,
  sessionCount: 1,
  total: 3,
  level: ReliabilityLevel.probable,
  unexpected: false,
  lastHeard: _now,
  singing: true,
);

Widget _app({
  required bool running,
  List<LiveBoardEntry> entries = const [],
  bool capturing = true,
}) => MaterialApp(
  theme: BirdyTheme.dark(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: BirdyLiveLayout(
      statusBar: const SizedBox(height: 48, child: Text('status')),
      spectrogram: const ColoredBox(
        key: ValueKey('spectrogram'),
        color: Colors.black,
      ),
      isCapturing: capturing,
      displaySeconds: 10,
      marks: [
        SpectrumMark(
          start: _now.subtract(const Duration(seconds: 4)),
          color: Colors.orange,
        ),
      ],
      sessionRunning: running,
      elapsed: () => const Duration(minutes: 12, seconds: 47),
      entries: entries,
      contacts: entries.length,
      idleBody: const Text('tips'),
      emptyBody: const LiveEmptyState(text: 'empty'),
      controlBar: const SizedBox(height: 88, child: Text('bar')),
    ),
  ),
);

/// The marks tick every frame while capturing: pump a fixed time instead
/// of settling.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

double _spectrumHeight(WidgetTester tester) =>
    tester.getSize(find.byType(LiveSpectrum)).height;

void main() {
  testWidgets('one tap enlarges the spectrogram, a second one shrinks it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(running: true, entries: [_entry('Merle')]));
    await _settle(tester);
    expect(_spectrumHeight(tester), BirdySizes.spectrumNormal);
    expect(find.text('12:47'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('spectrogram')));
    await _settle(tester);
    expect(_spectrumHeight(tester), greaterThan(BirdySizes.spectrumNormal * 2));
    // Counters fold into one line, rows become compact.
    expect(find.textContaining('12:47 · 1 espèce'), findsOneWidget);
    expect(tester.widget<LiveBoard>(find.byType(LiveBoard)).compact, isTrue);

    await tester.tap(find.byTooltip('Réduire le spectre'));
    await _settle(tester);
    expect(_spectrumHeight(tester), BirdySizes.spectrumNormal);
  });

  testWidgets('the spectrogram sits in its own repaint boundary', (
    tester,
  ) async {
    await tester.pumpWidget(_app(running: true));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('spectrogram')),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('marks are drawn while capturing', (tester) async {
    await tester.pumpWidget(_app(running: true));
    final painters =
        tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(LiveSpectrum),
                matching: find.byType(CustomPaint),
              ),
            )
            .map((p) => p.painter)
            .whereType<SpectrumMarksPainter>();
    expect(painters, hasLength(1));
  });

  testWidgets('idle shows the tips, listening without birds a calm line', (
    tester,
  ) async {
    await tester.pumpWidget(_app(running: false));
    expect(find.text('tips'), findsOneWidget);
    expect(find.text('12:47'), findsNothing);

    await tester.pumpWidget(_app(running: true));
    expect(find.text('empty'), findsOneWidget);
  });
}
