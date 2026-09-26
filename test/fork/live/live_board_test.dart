import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/entrance.dart';
import 'package:birdnet_live/fork/live/live_board.dart';
import 'package:birdnet_live/fork/live/live_board_model.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 9, 26, 7);

LiveBoardEntry _entry(String name, {int count = 1, int second = 0}) =>
    LiveBoardEntry(
      scientificName: name,
      commonName: name,
      sessionCount: count,
      total: count + 10,
      level: ReliabilityLevel.sure,
      unexpected: false,
      lastHeard: _t0.add(Duration(seconds: second)),
      singing: false,
    );

Widget _app(
  List<LiveBoardEntry> entries, {
  bool reduceMotion = false,
  double textScale = 1,
  bool compact = false,
}) => MaterialApp(
  theme: BirdyTheme.dark(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(body: LiveBoard(entries: entries, compact: compact)),
  ),
);

double _top(WidgetTester tester, String name) =>
    tester.getTopLeft(find.text(name)).dy;

RenderLiveBoard _render(WidgetTester tester) =>
    tester.renderObject<RenderLiveBoard>(find.byType(LiveBoardLayout));

void main() {
  testWidgets('a species heard again glides to the top in 250 ms', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_entry('Merle'), _entry('Pinson'), _entry('Pie')]),
    );
    await tester.pumpAndSettle();
    final top = _top(tester, 'Merle');
    final pieBefore = _top(tester, 'Pie');
    expect(pieBefore, greaterThan(top));

    await tester.pumpWidget(
      _app([
        _entry('Pie', count: 2, second: 9),
        _entry('Merle'),
        _entry('Pinson'),
      ]),
    );
    // First frame: still at its old place (no flicker).
    expect(_top(tester, 'Pie'), closeTo(pieBefore, 0.5));
    expect(_render(tester).isMoving, isTrue);

    await tester.pump(BirdyMotion.reorder ~/ 2);
    final mid = _top(tester, 'Pie');
    expect(mid, lessThan(pieBefore));
    expect(mid, greaterThan(top));

    await tester.pump(
      BirdyMotion.reorder ~/ 2 + const Duration(milliseconds: 1),
    );
    expect(_top(tester, 'Pie'), closeTo(top, 0.5));
    expect(_render(tester).isMoving, isFalse);
  });

  testWidgets('the ×N of a species heard again bumps', (tester) async {
    await tester.pumpWidget(_app([_entry('Merle')]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app([_entry('Merle', count: 2, second: 5)]));
    await tester.pump(const Duration(milliseconds: 60));
    final scale = tester.widget<ScaleTransition>(
      find.ancestor(
        of: find.text('×2'),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(scale.scale.value, greaterThan(1));
    await tester.pumpAndSettle();
    expect(scale.scale.value, 1);
  });

  testWidgets('a new species enters at the top, rows already shown do not', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_entry('Merle')]));
    // Rows present when the screen opens are shown at once.
    expect(
      tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Merle'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value,
      1,
    );

    await tester.pumpWidget(
      _app([_entry('Pinson', second: 3), _entry('Merle')]),
    );
    final entrance = find.ancestor(
      of: find.text('Pinson'),
      matching: find.byType(BirdyEntrance),
    );
    expect(entrance, findsOneWidget);
    expect(_top(tester, 'Pinson'), lessThan(_top(tester, 'Merle')));
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(of: entrance, matching: find.byType(FadeTransition))
          .first,
    );
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
  });

  testWidgets('reduced motion: rows jump, no glide', (tester) async {
    await tester.pumpWidget(
      _app([_entry('Merle'), _entry('Pie')], reduceMotion: true),
    );
    await tester.pumpAndSettle();
    final top = _top(tester, 'Merle');
    await tester.pumpWidget(
      _app([
        _entry('Pie', count: 2, second: 9),
        _entry('Merle'),
      ], reduceMotion: true),
    );
    expect(_top(tester, 'Pie'), closeTo(top, 0.5));
    expect(_render(tester).isMoving, isFalse);
  });

  testWidgets('taps reach the row at its painted place', (tester) async {
    LiveBoardEntry? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LiveBoard(
            entries: [_entry('Merle'), _entry('Pie')],
            onTap: (e) => tapped = e,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pie'));
    expect(tapped?.scientificName, 'Pie');
  });

  testWidgets('text at 130 % and compact rows: no overflow', (tester) async {
    final entries = [
      for (var i = 0; i < 12; i++)
        _entry('Martin-pêcheur d\'Europe $i', count: i + 1, second: i),
    ];
    await tester.pumpWidget(_app(entries, textScale: 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(entries, textScale: 1.3, compact: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
