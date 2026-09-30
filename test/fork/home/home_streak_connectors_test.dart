/// The home série block and its skeleton draw the same connectors as Profil.
library;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/game/streak_dots.dart';
import 'package:birdnet_live/fork/home/home_widgets.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: BirdyTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

void main() {
  final now = DateTime(2026, 9, 27, 12);
  final streak = computeStreak({
    for (var d = 24; d <= 27; d++) DateTime(2026, 9, d),
  }, now);

  testWidgets('home StreakBlock shows the 6 connectors', (tester) async {
    await tester.pumpWidget(_app(StreakBlock(streak: streak)));
    expect(find.byType(StreakDots), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('streak-connector-$i')), findsOneWidget);
    }
  });

  testWidgets('the loading skeleton has them too', (tester) async {
    await tester.pumpWidget(
      _app(StreakDotsSkeleton(days: lastSevenDays(streak), localeName: 'fr')),
    );
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('streak-connector-$i')), findsOneWidget);
    }
    await tester.pump(const Duration(seconds: 2));
  });
}
