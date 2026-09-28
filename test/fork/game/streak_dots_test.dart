/// J6f-b: the 7-day dot strip shared by the home and Profil série blocks.
library;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/game/streak_dots.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sunday 27 September 2026 at noon.
final _now = DateTime(2026, 9, 27, 12);

DateTime _d(int day, [int month = 9]) => DateTime(2026, month, day);

Set<DateTime> _days(Iterable<int> days) => {for (final d in days) _d(d)};

void main() {
  group('lastSevenDays', () {
    test('the 7 days ending today, today last', () {
      final streak = computeStreak(_days([24, 25, 26, 27]), _now);
      final week = lastSevenDays(streak);
      expect(week, hasLength(7));
      expect(week.last.date, _d(27));
      expect(week.last.isToday, isTrue);
      expect(week.first.date, _d(21));
    });

    test('falls back to the calendar week when today is missing', () {
      const streak = Streak(current: 0, record: 0, calendar: []);
      expect(lastSevenDays(streak), isEmpty);
    });
  });

  Widget app(Widget child) => MaterialApp(
    theme: BirdyTheme.light(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 300, child: child)),
  );

  testWidgets('a listened day is filled, an open day is only outlined', (
    tester,
  ) async {
    final streak = computeStreak(_days([21, 22, 23, 24, 25, 26]), _now);
    final week = lastSevenDays(streak);
    await tester.pumpWidget(
      app(StreakDots(days: week, localeName: 'fr')),
    );
    // 6 listened, today (27) still open.
    final containers = tester.widgetList<Container>(find.byType(Container));
    final listened = containers.where((c) => c.key == const ValueKey('day-listened'));
    final open = containers.where((c) => c.key == const ValueKey('day-open'));
    expect(listened, hasLength(6));
    expect(open, hasLength(1));
  });

  testWidgets('dayLabel wraps each dot in its own semantics, else silent', (
    tester,
  ) async {
    final streak = computeStreak(_days([27]), _now);
    final week = lastSevenDays(streak);

    await tester.pumpWidget(app(StreakDots(days: week, localeName: 'fr')));
    expect(find.bySemanticsLabel('today'), findsNothing);

    await tester.pumpWidget(
      app(
        StreakDots(
          days: week,
          localeName: 'fr',
          dayLabel: (day) => day.isToday ? 'today' : 'other',
        ),
      ),
    );
    expect(find.bySemanticsLabel('today'), findsOneWidget);
  });
}
