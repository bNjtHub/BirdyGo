/// Where the player stands (J6e, SPEC.md 7): status from the verified
/// species, badges and their tiers, the série. Pure, so it is tested alone.
library;

import 'challenges.dart';
import 'game_config.dart';
import 'streak.dart';

/// Status reached with [verified] species; null before the first one.
StatusDef? statusFor(int verified) {
  StatusDef? reached;
  for (final status in GameConfig.statuses) {
    if (verified >= status.from) reached = status;
  }
  return reached;
}

/// Status after [current] (the first one before any species); null at the
/// top.
StatusDef? nextStatus(StatusDef? current) {
  final rank = current?.rank ?? 0;
  return rank < GameConfig.statuses.length ? GameConfig.statuses[rank] : null;
}

/// Progress from the current status to the next one (0–1); 1 at the top.
double statusProgress(int verified) {
  final current = statusFor(verified);
  final next = nextStatus(current);
  if (next == null) return 1;
  final from = current?.from ?? 0;
  return ((verified - from) / (next.from - from)).clamp(0.0, 1.0);
}

class BadgeProgress {
  const BadgeProgress({required this.kind, required this.value});

  final BadgeKind kind;

  /// Count toward the tiers (times, species, days, answers).
  final int value;

  List<int> get tiers => GameConfig.badgeTiers[kind]!;

  /// 0 (locked) to 3 plumes.
  int get tier => tiers.where((t) => value >= t).length;

  /// Next tier's threshold; null once the three plumes are won.
  int? get nextTarget => tier < tiers.length ? tiers[tier] : null;
}

/// Facts the game is computed from.
class GameFacts {
  const GameFacts({
    required this.verifiedBirds,
    required this.dawnChoruses,
    required this.earlyStarts,
    required this.reviewed,
    required this.migrants,
    required this.streak,
    this.challenge,
  });

  static const empty = GameFacts(
    verifiedBirds: {},
    dawnChoruses: 0,
    earlyStarts: 0,
    reviewed: 0,
    migrants: {},
    streak: Streak.empty,
  );

  /// Birds verified at least once (Sûr or confirmed).
  final Set<String> verifiedBirds;

  /// Listenings started before 8 h with 10 verified species.
  final int dawnChoruses;

  /// Listenings started before sunrise.
  final int earlyStarts;

  /// Detections answered in the quick review.
  final int reviewed;

  /// Verified birds that are migrants at the user's place.
  final Set<String> migrants;

  final Streak streak;

  /// This week's challenge; null when unknown.
  final WeeklyChallenge? challenge;
}

class GameProgress {
  const GameProgress(this.facts);

  final GameFacts facts;

  int get verified => facts.verifiedBirds.length;
  StatusDef? get status => statusFor(verified);
  StatusDef? get next => nextStatus(status);
  double get progress => statusProgress(verified);

  /// Species still needed for [next].
  int get remaining => next == null ? 0 : next!.from - verified;

  List<BadgeProgress> get badges => [
    for (final kind in BadgeKind.values)
      BadgeProgress(kind: kind, value: _value(kind)),
  ];

  int _value(BadgeKind kind) => switch (kind) {
    BadgeKind.dawnChorus => facts.dawnChoruses,
    BadgeKind.earlyBird => facts.earlyStarts,
    BadgeKind.nightOwl =>
      facts.verifiedBirds
          .where((s) => GameConfig.nightGenera.contains(genusOf(s)))
          .length,
    BadgeKind.reviewer => facts.reviewed,
    BadgeKind.migrant => facts.migrants.length,
    BadgeKind.streak => facts.streak.record,
    BadgeKind.tits =>
      facts.verifiedBirds
          .where((s) => GameConfig.titGenera.contains(genusOf(s)))
          .length,
  };
}
