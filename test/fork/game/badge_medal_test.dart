import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + .05) / (lo + .05);
}

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  theme: BirdyTheme.light(),
  darkTheme: BirdyTheme.dark(),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('bronze, silver, gold: the glyph reads on the metal (3:1)', () {
    expect(GameConfig.badgeMedals, hasLength(3));
    for (final metal in GameConfig.badgeMedals) {
      for (final face in [metal.base, metal.highlight]) {
        expect(_contrast(metal.ink, face), greaterThanOrEqualTo(3));
      }
    }
  });

  for (final dark in [false, true]) {
    testWidgets('every tier builds (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var tier = 0; tier <= 3; tier++)
                BadgeMedal(tier: tier, icon: AppIcons.star),
            ],
          ),
          dark: dark,
        ),
      );
      expect(find.byType(BadgeMedal), findsNWidgets(4));
      expect(tester.takeException(), isNull);

      // A locked medal takes the theme text color, an earned one its metal.
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      final c = dark ? BirdyColors.dark : BirdyColors.light;
      expect(icons.first.color, c.text2);
      expect(icons.last.color, GameConfig.badgeMedals.last.ink);
    });
  }
}
