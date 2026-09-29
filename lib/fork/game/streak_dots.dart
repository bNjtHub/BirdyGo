/// Shared 7-day strip of the série (J6f Profil mockup): a dot per day, with
/// the narrow weekday letter beneath. Used on the home série block and the
/// Profil série block, so both show the exact same look.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/dashed_border.dart';
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
/// narrow weekday letter underneath (J6f Profil mockup): a listened day is
/// an accent disc with an ink check, a day without listening is a plain
/// line-color disc, a rest day is a dashed accent ring, an upcoming day is
/// a plain outline, and today is a small accent dot ringed twice (the card
/// background, then ink) regardless of whether it was listened to yet.
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
                    _StreakDot(day: day),
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

/// One day of [StreakDots] (J6f Profil mockup): today always shows its own
/// small ringed dot, whatever its listened state; otherwise the dot follows
/// [StreakDay.state].
class _StreakDot extends StatelessWidget {
  const _StreakDot({required this.day});

  final StreakDay day;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    if (day.isToday) {
      // The card these dots sit in is always the série block's Loriot tone
      // (home and Profil both use it), so the outer ring matches it.
      return Container(
        key: const ValueKey('day-today'),
        width: BirdySizes.dayDot,
        height: BirdySizes.dayDot,
        alignment: Alignment.center,
        child: Container(
          width: BirdySizes.dayDot * 16 / 20,
          height: BirdySizes.dayDot * 16 / 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.accent,
            boxShadow: [
              BoxShadow(color: c.orioleContainer, spreadRadius: 2),
              BoxShadow(color: c.text1, spreadRadius: 4),
            ],
          ),
        ),
      );
    }
    switch (day.state) {
      case StreakDayState.listened:
        return Container(
          key: const ValueKey('day-listened'),
          width: BirdySizes.dayDot,
          height: BirdySizes.dayDot,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
          child: Icon(
            AppIcons.check,
            size: BirdySizes.dayDot * 0.7,
            color: c.onAccent,
          ),
        );
      case StreakDayState.rest:
        return SizedBox(
          key: const ValueKey('day-rest'),
          width: BirdySizes.dayDot,
          height: BirdySizes.dayDot,
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: c.accent,
              radius: BirdySizes.dayDot / 2,
              strokeWidth: 2,
              dash: 2,
              gap: 1.6,
            ),
          ),
        );
      case StreakDayState.open:
        return Container(
          key: const ValueKey('day-open'),
          width: BirdySizes.dayDot,
          height: BirdySizes.dayDot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.borderStrong, width: 1.5),
          ),
        );
      case StreakDayState.missed:
        return Container(
          key: const ValueKey('day-missed'),
          width: BirdySizes.dayDot,
          height: BirdySizes.dayDot,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.lineOpaque),
        );
    }
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
