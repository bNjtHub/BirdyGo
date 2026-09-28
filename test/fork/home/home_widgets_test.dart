import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/home/home_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _d(int day, [int month = 9]) => DateTime(2026, month, day);

void main() {
  group('lastSevenDays', () {
    test(
      'a rolling window ending today, not the calendar week (Monday bug)',
      () {
        // Monday 21 September 2026, noon: a 2-day série (Sunday + Monday).
        final now = DateTime(2026, 9, 21, 12);
        final streak = computeStreak({_d(20), _d(21)}, now);
        // Sanity: computeStreak sees the running 2-day série.
        expect(streak.current, 2);

        final week = lastSevenDays(streak);
        expect(week, hasLength(7));
        // Today (Monday) is last, and both listened days show up: a
        // calendar-week slice (Monday to Sunday) would hide Sunday, the
        // previous week's last day.
        expect(week.last.date, _d(21));
        expect(week.last.isToday, isTrue);
        final listened =
            week.where((d) => d.state == StreakDayState.listened).toList();
        expect(listened.map((d) => d.date), [_d(20), _d(21)]);
      },
    );

    test('today at the end of the week: same as the calendar week', () {
      // Sunday 27 September 2026: the rolling window and the calendar week
      // agree when today is the last day of the ISO week.
      final now = DateTime(2026, 9, 27, 12);
      final streak = computeStreak({
        _d(21),
        _d(22),
        _d(23),
        _d(24),
        _d(25),
        _d(26),
      }, now);
      final week = lastSevenDays(streak);
      expect(week.map((d) => d.date), [
        for (var day = 21; day <= 27; day++) _d(day),
      ]);
      expect(week.last.isToday, isTrue);
    });

    test('today missing from the calendar: falls back to the last 7 days', () {
      final streak = Streak(
        current: 0,
        record: 0,
        calendar: [
          StreakDay(
            date: _d(1, 1),
            state: StreakDayState.missed,
            isToday: false,
          ),
        ],
      );
      final week = lastSevenDays(streak);
      expect(week, hasLength(1));
    });
  });
}
