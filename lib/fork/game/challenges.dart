/// Weekly challenges (J6e, SPEC.md 7.5): Monday to Sunday, opt-in. Nothing
/// counts before « Commencer », and an unfinished challenge simply closes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';
import 'game_config.dart';

/// Monday 00:00 of [now]'s week, local time.
DateTime weekStart(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.weekday - 1));

/// Next Monday 00:00: the end of [now]'s week.
DateTime weekEnd(DateTime now) {
  final start = weekStart(now);
  return DateTime(start.year, start.month, start.day + 7);
}

/// The challenge of [now]'s week.
(ChallengeKind, int) challengeOfWeek(DateTime now) {
  final start = weekStart(now);
  final weeks =
      DateTime.utc(
        start.year,
        start.month,
        start.day,
      ).difference(DateTime.utc(2024, 1, 1)).inDays ~/
      7;
  final list = GameConfig.weeklyChallenges;
  return list[weeks % list.length];
}

/// This week's challenge and where it stands.
class WeeklyChallenge {
  const WeeklyChallenge({
    required this.kind,
    required this.target,
    required this.startedAt,
    required this.value,
    required this.ends,
  });

  final ChallengeKind kind;
  final int target;

  /// When « Commencer » was pressed this week; null: offered, not started.
  final DateTime? startedAt;

  /// Progress since [startedAt].
  final int value;

  /// Next Monday 00:00.
  final DateTime ends;

  bool get started => startedAt != null;
  bool get done => started && value >= target;
}

const String kChallengeStartedPref = 'fork_challenge_started';

/// When the user started this week's challenge.
class ChallengeStore {
  ChallengeStore(this._prefs);

  final SharedPreferences _prefs;

  /// Start time, if it falls in [now]'s week.
  DateTime? startedAt(DateTime now) {
    final raw = _prefs.getString(kChallengeStartedPref);
    final at = raw == null ? null : DateTime.tryParse(raw);
    if (at == null ||
        at.isBefore(weekStart(now)) ||
        !at.isBefore(weekEnd(now))) {
      return null;
    }
    return at;
  }

  Future<void> start(DateTime now) =>
      _prefs.setString(kChallengeStartedPref, now.toIso8601String());
}

final challengeStoreProvider = Provider<ChallengeStore>(
  (ref) => ChallengeStore(ref.watch(sharedPreferencesProvider)),
);
