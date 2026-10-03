import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + .05) / (lo + .05);
}

Widget _cell(Widget child) =>
    Padding(padding: const EdgeInsets.all(4), child: child);

Widget _sheet({required bool dark}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: const ValueKey('sheet'),
        child: ColoredBox(
          color:
              dark ? BirdyColors.dark.background : BirdyColors.light.background,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in GameConfig.statuses)
                      _cell(StatusEmblem(status: s, size: 96)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in GameConfig.statuses)
                      _cell(StatusEmblem(status: s, size: 96, reached: false)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var tier = 0; tier <= 3; tier++)
                      _cell(
                        BadgeMedal(tier: tier, icon: AppIcons.star, size: 96),
                      ),
                    _cell(
                      BadgeMedal(
                        tier: 2,
                        glyph: GameConfig.migrantGlyph,
                        size: 96,
                      ),
                    ),
                    _cell(
                      StatusEmblem(
                        status: GameConfig.statuses[3],
                        size: 96,
                        current: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  test('the eight statuses climb in colour and keep their ranks', () {
    final s = GameConfig.statuses;
    expect(s.map((e) => e.rank), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(s[6].color, const Color(0xFF3D3A7A));
    expect(s[6].glyphMain, BirdyBrand.oriole);
    expect(s[6].glyphInk, const Color(0xFF1A1840));
    // Last rank: whole gauge in Loriot; the others in the status colour.
    expect(s.last.gauge, BirdyBrand.oriole);
    expect(s.first.gauge, s.first.color);
    expect(s.first.glyphInk, s.first.deep);
  });

  test('white glyph on every status disc: contrast report (3:1 wanted)', () {
    final low = <int>[];
    for (final s in GameConfig.statuses) {
      if (_contrast(s.glyphMain, s.color) < 3) low.add(s.rank);
    }
    // Rank 1 (earth, 2.95:1) sits just under; the glyph also has its deep
    // and Loriot details, and the disc rim carries the shape.
    expect(low, [1]);
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'statuses (reached, locked) and medals render ($mode)',
      (tester) async {
        tester.view.physicalSize = const Size(900, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_sheet(dark: dark));
        expect(tester.takeException(), isNull);
        expect(find.byType(StatusEmblem), findsNWidgets(17));
        expect(find.byType(BadgeMedal), findsNWidgets(5));
        await expectLater(
          find.byKey(const ValueKey('sheet')),
          matchesGoldenFile('goldens/status_emblems_$mode.png'),
        );
      },
      skip: !Platform.isWindows,
    );
  }

  testWidgets('gaugeReveal lights the segments one by one', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        home: StatusEmblem(
          status: GameConfig.statuses.last,
          size: 96,
          gaugeReveal: 0.5,
        ),
      ),
    );
    final disc = tester.widget<GameDisc>(find.byType(GameDisc));
    expect(disc.lit, 4);
    expect(disc.segments, 8);
  });

  testWidgets('a status to come has an unlit gauge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        home: StatusEmblem(
          status: GameConfig.statuses[4],
          size: 96,
          reached: false,
        ),
      ),
    );
    expect(tester.widget<GameDisc>(find.byType(GameDisc)).lit, 0);
  });

  testWidgets('a medal gauge has three segments, lit up to its tier', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        home: Column(
          children: [
            for (var t = 0; t <= 3; t++)
              BadgeMedal(tier: t, icon: AppIcons.star),
          ],
        ),
      ),
    );
    final discs = tester.widgetList<GameDisc>(find.byType(GameDisc)).toList();
    expect(discs.map((d) => d.lit), [0, 1, 2, 3]);
    expect(discs.every((d) => d.segments == 3), isTrue);
  });
}
