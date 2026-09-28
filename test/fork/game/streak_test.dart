import 'package:birdnet_live/fork/game/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sunday 27 September 2026 at noon.
final _now = DateTime(2026, 9, 27, 12);

DateTime _d(int day, [int month = 9]) => DateTime(2026, month, day);

Set<DateTime> _days(Iterable<int> days) => {for (final d in days) _d(d)};

void main() {
  test('days in a row, today included', () {
    final streak = computeStreak(_days([24, 25, 26, 27]), _now);
    expect(streak.current, 4);
    expect(streak.record, 4);
  });

  test('today not listened yet: the série goes on', () {
    final streak = computeStreak(_days([24, 25, 26]), _now);
    expect(streak.current, 3);
    final today = streak.calendar.last;
    expect(today.isToday, isTrue);
    expect(today.state, StreakDayState.open);
  });

  test('one rest day a week keeps it, and counts', () {
    final streak = computeStreak(_days([21, 22, 24, 25, 26, 27]), _now);
    expect(streak.current, 7);
    final rest = streak.calendar.firstWhere((d) => d.date == _d(23));
    expect(rest.state, StreakDayState.rest);
  });

  test('a second rest day in the same week ends it quietly', () {
    final streak = computeStreak(_days([20, 21, 23, 25, 26, 27]), _now);
    // 20, 21, rest 22, 23; 24 would be a second rest within 7 days.
    expect(streak.current, 3);
    expect(streak.record, 4);
  });

  test('yesterday off, today not over: shown as the rest day', () {
    final streak = computeStreak(_days([24, 25]), _now);
    expect(streak.current, 2);
    expect(
      streak.calendar.firstWhere((d) => d.date == _d(26)).state,
      StreakDayState.rest,
    );
  });

  test('two days off: broken, the record stays', () {
    final streak = computeStreak(
      _days([10, 11, 12, 13, 14, 15, 16, 17, 20, 27]),
      _now,
    );
    expect(streak.current, 1);
    expect(streak.record, 8);
  });

  test('calendar: two weeks, Monday to Sunday', () {
    final streak = computeStreak(const {}, _now);
    expect(streak.calendar, hasLength(14));
    expect(streak.calendar.first.date, _d(14));
    expect(streak.calendar.last.date, _d(27));
    expect(streak.current, 0);
  });

  test('a day counts from 5 minutes of listening', () {
    final days = listenedDays([
      (DateTime(2026, 9, 25, 7), DateTime(2026, 9, 25, 7, 3)),
      (DateTime(2026, 9, 25, 18), DateTime(2026, 9, 25, 18, 2)),
      (DateTime(2026, 9, 26, 7), DateTime(2026, 9, 26, 7, 4)),
      (DateTime(2026, 9, 27, 7), null),
    ]);
    expect(days, {_d(25)});
  });
}
