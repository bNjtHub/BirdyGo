/// Shared 7-day strip of the série (J6f): a dot per day, filled when
/// listened, outlined otherwise, with the narrow weekday letter beneath.
/// Used on the home série block and the Profil série block, so both show
/// the exact same look.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'streak.dart';

/// The 7 days ending today (today last), from the two-week calendar
/// ([Streak.calendar]: two ISO weeks Monday to Sunday, current week last).
/// A calendar-week slice would hide yesterday on a Monday; this rolling
/// window always shows the days that actually count toward the série.
/// Falls back to the calendar week when today is missing from the
/// calendar (should not happen).
List<StreakDay> lastSevenDays(Streak streak) {
  final days = streak.calendar;
  final todayIndex = days.indexWhere((d) => d.isToday);
  if (todayIndex < 6) {
    return days.length <= 7 ? days : days.sublist(days.length - 7);
  }
  return days.sublist(todayIndex - 6, todayIndex + 1);
}

/// Row of 7 day dots ([days], a [lastSevenDays] window), each with its
/// narrow weekday letter underneath. Filled [BirdyColors.orioleText] when
/// listened, outlined at [BirdyAlpha.dayDotOutline] otherwise; today's
/// letter is bold, the only mark for "today" (no extra ring).
class StreakDots extends StatelessWidget {
  const StreakDots({
    super.key,
    required this.days,
    required this.localeName,
    this.dayLabel,
  });

  final List<StreakDay> days;
  final String localeName;

  /// Per-day accessibility label (date, listened or not); the dots stay
  /// silent (relying on a block-level [Semantics] instead) when null, same
  /// as the home série block.
  final String Function(StreakDay day)? dayLabel;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final weekday = DateFormat('EEEEE', localeName);
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _maybeSemantics(
                dayLabel?.call(day),
                Column(
                  children: [
                    _StreakDot(
                      listened: day.state == StreakDayState.listened,
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      weekday.format(day.date).toUpperCase(),
                      style: BirdyText.caption.copyWith(
                        color: c.orioleText,
                        fontWeight:
                            day.isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _maybeSemantics(String? label, Widget child) =>
      label == null
          ? child
          : Semantics(label: label, child: ExcludeSemantics(child: child));
}

/// Filled when listened, outlined otherwise. Loriot text color, not the
/// Loriot fill: the fill is too pale on its own container.
class _StreakDot extends StatelessWidget {
  const _StreakDot({required this.listened});

  final bool listened;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      key: ValueKey(listened ? 'day-listened' : 'day-open'),
      width: BirdySizes.dayDot,
      height: BirdySizes.dayDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: listened ? c.orioleText : null,
        border:
            listened
                ? null
                : Border.all(
                  color: c.orioleText.withValues(
                    alpha: BirdyAlpha.dayDotOutline,
                  ),
                  width: BirdySizes.dayDotStroke,
                ),
      ),
    );
  }
}

/// Same shape as [StreakDots] (7 dots and weekday letters), while the
/// streak facts are still loading: [days] can come from the real clock
/// alone (which day is "today" does not depend on the loaded data), only
/// each dot's fill still a placeholder.
class StreakDotsSkeleton extends StatelessWidget {
  const StreakDotsSkeleton({
    super.key,
    required this.days,
    required this.localeName,
  });

  final List<StreakDay> days;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final weekday = DateFormat('EEEEE', localeName);
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.skeleton,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: BirdySizes.dayDot,
                      height: BirdySizes.dayDot,
                    ),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    weekday.format(day.date).toUpperCase(),
                    style: BirdyText.caption.copyWith(
                      color: c.orioleText,
                      fontWeight:
                          day.isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
