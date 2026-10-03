import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: BirdyTheme.light(), home: Center(child: child));

GameDisc _disc(WidgetTester tester) =>
    tester.widget<GameDisc>(find.byType(GameDisc));

void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  testWidgets('the gauge shows from gaugeMinSize up, emblem and medal', (
    tester,
  ) async {
    final status = GameConfig.statuses[3];
    for (final (size, gauged) in [
      (BirdyGlyph.disc40, false),
      (BirdyGlyph.disc48, false),
      (BirdyGlyph.disc56, false),
      (BirdyGlyph.gaugeMinSize, true),
      (BirdyGlyph.disc96, true),
      (BirdyGlyph.disc136, true),
    ]) {
      await tester.pumpWidget(_host(StatusEmblem(status: status, size: size)));
      expect(_disc(tester).gauged, gauged, reason: 'emblem $size');
      await tester.pumpWidget(
        _host(BadgeMedal(tier: 2, icon: AppIcons.star, size: size)),
      );
      expect(_disc(tester).gauged, gauged, reason: 'medal $size');
    }
  });

  testWidgets('a small emblem has no gauge even with a progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        StatusEmblem(status: GameConfig.statuses[3], size: 48, progress: 0.4),
      ),
    );
    expect(_disc(tester).gauged, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a large emblem keeps its progress and its gauge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        StatusEmblem(status: GameConfig.statuses[3], size: 96, progress: 0.4),
      ),
    );
    expect(_disc(tester).gauged, isTrue);
    expect(_disc(tester).partial, 0.4);
  });

  testWidgets('showGauge overrides the size rule', (tester) async {
    await tester.pumpWidget(
      _host(
        const GameDisc(
          size: 48,
          color: Colors.red,
          deep: Colors.black,
          segments: 8,
          lit: 2,
          gaugeOn: Colors.red,
          showGauge: true,
        ),
      ),
    );
    expect(_disc(tester).gauged, isTrue);
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'small and large discs, reached and locked ($mode)',
      (tester) async {
        tester.view.physicalSize = const Size(900, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Widget row(List<Widget> children) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in children)
              Padding(padding: const EdgeInsets.all(4), child: c),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey('sheet'),
                  child: ColoredBox(
                    color:
                        dark
                            ? BirdyColors.dark.background
                            : BirdyColors.light.background,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          row([
                            for (final s in GameConfig.statuses)
                              StatusEmblem(status: s, size: BirdyGlyph.disc40),
                          ]),
                          row([
                            for (final s in GameConfig.statuses)
                              StatusEmblem(
                                status: s,
                                size: BirdyGlyph.disc40,
                                reached: false,
                              ),
                          ]),
                          row([
                            for (final s in GameConfig.statuses.take(4))
                              StatusEmblem(
                                status: s,
                                size: BirdyGlyph.gaugeMinSize,
                                progress: 0.4,
                              ),
                            for (var t = 0; t <= 3; t++)
                              BadgeMedal(
                                tier: t,
                                icon: AppIcons.star,
                                size: BirdyGlyph.disc56,
                              ),
                          ]),
                          row([
                            for (var t = 0; t <= 3; t++)
                              BadgeMedal(
                                tier: t,
                                icon: AppIcons.star,
                                size: BirdyGlyph.disc72,
                              ),
                            StatusEmblem(
                              status: GameConfig.statuses[5],
                              size: BirdyGlyph.disc136,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('sheet')),
          matchesGoldenFile('goldens/game_disc_gauge_$mode.png'),
        );
      },
      skip: !Platform.isWindows,
    );
  }
}
