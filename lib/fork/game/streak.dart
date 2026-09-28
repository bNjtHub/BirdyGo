/// The forgiving série (J6e, SPEC.md 7.4): days in a row with some
/// listening, one rest day allowed per week. Missing more ends the série
/// quietly; the record stays.
library;

import 'game_config.dart';

enum StreakDayState {
  /// At least [GameConfig.streakMinListening] of listening.
  listened,

  /// A day off that keeps the série going.
  rest,

  /// Nothing, and no rest left.
  missed,

  /// Today without listening yet, or a day to come.
  open,
}

class StreakDay {
  const StreakDay({
    required this.date,
    required this.state,
    required this.isToday,
  });

  final DateTime date;
  final StreakDayState state;
  final bool isToday;
}

class Streak {
  const Streak({
    required this.current,
    required this.record,
    required this.calendar,
  });

  static const empty = Streak(current: 0, record: 0, calendar: []);

  /// Days of the running série (rest days included); 0 when broken.
  final int current;

  /// Longest série ever.
  final int record;

  /// Two weeks, Monday to Sunday, the current week last.
  final List<StreakDay> calendar;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Whole days from [a] to [b], safe across daylight saving changes.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

DateTime _plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Days that count: at least [GameConfig.streakMinListening] of listening,
/// each listening counted on the day it started.
Set<DateTime> listenedDays(Iterable<(DateTime, DateTime?)> listenings) {
  final perDay = <DateTime, Duration>{};
  for (final (start, end) in listenings) {
    if (end == null || !end.isAfter(start)) continue;
    final day = _day(start.toLocal());
    perDay[day] = (perDay[day] ?? Duration.zero) + end.difference(start);
  }
  return {
    for (final entry in perDay.entries)
      if (entry.value >= GameConfig.streakMinListening) entry.key,
  };
}

/// The série on [now], from the [listened] days.
Streak computeStreak(Set<DateTime> listened, DateTime now) {
  final today = _day(now);
  final days = {for (final d in listened) _day(d)};
  final states = <DateTime, StreakDayState>{};
  var run = 0;
  var record = 0;
  DateTime? lastRest;
  DateTime? pendingRest;

  if (days.isNotEmpty) {
    final first = days.reduce((a, b) => a.isBefore(b) ? a : b);
    for (var d = first; !d.isAfter(today); d = _plusDays(d, 1)) {
      if (days.contains(d)) {
        if (pendingRest != null) {
          run++;
          states[pendingRest] = StreakDayState.rest;
          lastRest = pendingRest;
          pendingRest = null;
        }
        run++;
        states[d] = StreakDayState.listened;
      } else if (d == today) {
        // The day is not over.
      } else if (run > 0 &&
          pendingRest == null &&
          (lastRest == null ||
              _daysBetween(lastRest, d) >= GameConfig.streakRestEvery)) {
        pendingRest = d;
      } else {
        if (pendingRest != null) states[pendingRest] = StreakDayState.missed;
        pendingRest = null;
        lastRest = null;
        states[d] = StreakDayState.missed;
        run = 0;
      }
      if (run > record) record = run;
    }
  }
  // Yesterday off, today not over: shown as the rest day it will be.
  if (pendingRest != null) states[pendingRest] = StreakDayState.rest;

  final monday = _plusDays(today, -(today.weekday - 1) - 7);
  return Streak(
    current: run,
    record: record,
    calendar: [
      for (var i = 0; i < 14; i++)
        () {
          final date = _plusDays(monday, i);
          return StreakDay(
            date: date,
            state:
                states[date] ??
                (date.isBefore(today)
                    ? StreakDayState.missed
                    : StreakDayState.open),
            isToday: date == today,
          );
        }(),
    ],
  );
}
