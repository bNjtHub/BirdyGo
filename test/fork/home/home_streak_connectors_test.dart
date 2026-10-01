/// The home série block and its skeleton draw visible connectors, in the
/// half-width cell of the home grid (where there is little room) as well.
library;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/game/streak_dots.dart';
import 'package:birdnet_live/fork/home/home_widgets.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {ThemeData? theme, double width = 360}) =>
    MaterialApp(
      theme: theme ?? BirdyTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(BirdySpace.page),
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

/// The block as the home shows it: right column of the half-width grid,
/// inside the IntrinsicHeight row.
Widget _homeGrid(Streak streak) => HomeGrid(
  goal: const SizedBox(height: 120),
  streak: StreakBlock(streak: streak),
);

/// Width of a connector half that stays inside its clipping cell.
double _visible(WidgetTester tester, String half, int cell) {
  final rect = tester.getRect(find.byKey(ValueKey('streak-connector-$half')));
  final clip = tester.getRect(
    find.byKey(ValueKey('streak-connector-cell-$cell')),
  );
  return rect.intersect(clip).width;
}

double _visibleLength(WidgetTester tester, int i) =>
    _visible(tester, '$i-end', i) + _visible(tester, '$i-start', i + 1);

void main() {
  final now = DateTime(2026, 9, 27, 12);
  final threeDays = computeStreak({
    for (var d = 25; d <= 27; d++) DateTime(2026, 9, d),
  }, now);
  final oneDay = computeStreak({DateTime(2026, 9, 27)}, now);

  for (final (name, streak) in [('3 days', threeDays), ('1 day', oneDay)]) {
    // Phones from 360 dp up; below that the dots nearly touch anyway.
    for (final width in [360.0, 412.0]) {
      testWidgets('home grid, $name, $width dp: 6 visible connectors', (
        tester,
      ) async {
        await tester.pumpWidget(_app(_homeGrid(streak), width: width - 32));
        expect(find.byType(StreakDots), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 6; i++) {
          expect(_visibleLength(tester, i), greaterThan(BirdySpace.xs));
        }
        final line = tester.getSize(
          find.byKey(const ValueKey('streak-connector-0-end')),
        );
        expect(line.height, closeTo(BirdyStroke.regular, 0.01));
      });
    }
  }

  testWidgets('connectors keep 3:1 on the block, 4 themes x light/dark', (
    tester,
  ) async {
    for (final bird in BirdyBird.values) {
      for (final brightness in Brightness.values) {
        final c = BirdyColors.forBird(bird, brightness);
        // orioleContainer is translucent in the dark themes: blend it over
        // the page like the block does.
        final block = Color.alphaBlend(c.orioleContainer, c.background);
        expect(
          contrastRatio(c.orioleText, block),
          greaterThanOrEqualTo(3),
          reason: '${bird.name} ${brightness.name}',
        );
      }
    }
  });

  testWidgets('at 200% text the lines stay centered on the dots', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(BirdySpace.page),
            child: SizedBox(width: 300, child: _homeGrid(threeDays)),
          ),
        ),
      ),
    );
    final dot = tester.getCenter(find.byKey(const ValueKey('day-today')));
    // The last cell holds today's dot: its start half is the line next to it.
    final line = tester.getCenter(
      find.byKey(const ValueKey('streak-connector-5-start')),
    );
    expect((line.dy - dot.dy).abs(), lessThanOrEqualTo(1));
    final other = tester.getCenter(
      find.byKey(const ValueKey('day-missed')).first,
    );
    final line2 = tester.getCenter(
      find.byKey(const ValueKey('streak-connector-0-end')),
    );
    expect((line2.dy - other.dy).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('the loading skeleton has them too', (tester) async {
    await tester.pumpWidget(
      _app(StreakDotsSkeleton(days: lastSevenDays(threeDays), localeName: 'fr')),
    );
    for (var i = 0; i < 6; i++) {
      expect(_visibleLength(tester, i), greaterThan(BirdySpace.xs));
    }
    await tester.pump(const Duration(seconds: 2));
  });
}
