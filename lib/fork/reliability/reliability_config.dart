/// Reliability levels shown everywhere a detection appears (fork/PLAN.md J3).
///
/// Every threshold lives here; tune them with the measured precision
/// (Reliability screen) after a few weeks of reviews.
library;

import '../../features/announcements/domain/announcement_signals.dart';
import '../../features/inference/geo_abundance.dart';
import '../../features/live/live_session.dart';

/// How much to trust a detection.
enum ReliabilityLevel { sure, probable, toCheck }

/// Fork-owned reliability thresholds.
abstract final class ReliabilityConfig {
  /// Minimum score for "Sûr", when the species is plausible here.
  static const double sureMinScore = 0.80;

  /// Minimum score for "Probable".
  static const double probableMinScore = 0.55;

  /// Abundance tiers that mean "rare here at this season".
  static const Set<ExploreTier> rareTiers = {ExploreTier.rare};

  /// Abundance tiers marked « peu commun » (half disc) in the notebook
  /// (J6e). Rarity never gives points or levels.
  static const Set<ExploreTier> uncommonTiers = {ExploreTier.scarce};

  /// Reviews needed before a species' precision is shown.
  static const int minReviewsForSpeciesPrecision = 5;

  /// Live (J6c-bis-b): consecutive windows under the support threshold that
  /// put out the singing symbol. The first unsupported window ends it;
  /// temporal pooling still preserves the contact in the results/history.
  static const int liveSingingHoldWindows = 1;

  /// Live (J6c-bis-b): cycles « Analyse… » stays on after a candidate is
  /// confirmed, so the header does not fade while the row comes in.
  static const int analysingHoldWindows = 1;

  /// Live GPS track: minimum seconds between two position updates.
  static const int liveGpsIntervalSeconds = 10;

  /// Live GPS track: minimum move (meters) before the OS reports a new fix.
  static const int liveGpsDistanceFilterMeters = 5;

  /// Live GPS track: fixes less accurate than this (meters) are dropped.
  static const double liveGpsMaxAccuracyMeters = 30;

  /// Live empty state (J6f): species listed under « Attendus ici ».
  static const int liveExpectedCount = 5;

  /// Live empty state (J6f): commonness bins said « Parmi les plus
  /// fréquents ici en `<mois>` ».
  static const Set<CommonnessBin> liveExpectedFrequentBins = {
    CommonnessBin.abundant,
    CommonnessBin.common,
  };

  /// Live empty state (J6f): this week's score over the species' annual
  /// peak here from which it is « En pleine saison ici ».
  static const double liveExpectedPeakShare = 0.8;
}

/// What the geo-model says about a species at a place and week.
class GeoPresence {
  const GeoPresence({required this.unexpected});

  /// Rare or absent here at this season: the "Inattendu ici" badge.
  final bool unexpected;
}

/// Reliability of one detection.
///
/// A confirmed detection is always sure (a person checked it). Without geo
/// information ([presence] null), plausibility is unknown, so a high score
/// stays "Probable": "Sûr" needs the species to be plausible here.
ReliabilityLevel reliabilityFor({
  required double score,
  ReviewStatus review = ReviewStatus.unreviewed,
  GeoPresence? presence,
}) {
  if (review == ReviewStatus.confirmed) return ReliabilityLevel.sure;
  if (presence?.unexpected ?? false) return ReliabilityLevel.toCheck;
  if (score >= ReliabilityConfig.sureMinScore) {
    return presence == null ? ReliabilityLevel.probable : ReliabilityLevel.sure;
  }
  if (score >= ReliabilityConfig.probableMinScore) {
    return ReliabilityLevel.probable;
  }
  return ReliabilityLevel.toCheck;
}

/// True when [presence] alone makes a detection « À vérifier »: the score
/// would reach « Probable » or « Sûr », but the species is unexpected here
/// (J3b). The level stays [ReliabilityLevel.toCheck]; only its label and
/// explanation change (« Rare ici · à confirmer »).
bool placeOnlyToCheck({
  required double score,
  ReviewStatus review = ReviewStatus.unreviewed,
  GeoPresence? presence,
}) =>
    review != ReviewStatus.confirmed &&
    (presence?.unexpected ?? false) &&
    score >= ReliabilityConfig.probableMinScore;

/// Most trusted of [levels] (the level of a species over several contacts);
/// [ReliabilityLevel.toCheck] when there is none.
ReliabilityLevel bestLevel(Iterable<ReliabilityLevel> levels) {
  var best = ReliabilityLevel.toCheck;
  for (final level in levels) {
    if (level.index < best.index) best = level;
  }
  return best;
}

/// Presence of every audio-detectable species for one place and week, from
/// the geo-model's raw scores ([weekScores]: species -> probability).
///
/// Uses the same population and tier scale as Explore and the spoken
/// commonness hints, so the "Inattendu ici" badge agrees with them. A
/// species under the inclusion threshold is absent here, hence unexpected.
Map<String, GeoPresence> presenceFromWeekScores(
  Map<String, double> weekScores, {
  required Set<String> audioLabels,
}) {
  final population = [
    for (final entry in weekScores.entries)
      if (audioLabels.contains(entry.key) &&
          entry.value >= kAbundanceInclusionThreshold)
        entry.value,
  ];
  if (population.isEmpty) return const {};
  final scale = ExploreTierScale.fromScores(population);
  return {
    for (final entry in weekScores.entries)
      if (audioLabels.contains(entry.key))
        entry.key: GeoPresence(
          unexpected:
              entry.value < kAbundanceInclusionThreshold ||
              ReliabilityConfig.rareTiers.contains(scale.tierFor(entry.value)),
        ),
  };
}

/// Presence of a species missing from a non-empty presence map: the
/// geo-model does not expect it here at all.
const GeoPresence kAbsentHere = GeoPresence(unexpected: true);

/// Score band used to measure precision per level. Precision is measured
/// on the score alone, because the thresholds being tuned are scores.
ReliabilityLevel scoreBand(double score) {
  if (score >= ReliabilityConfig.sureMinScore) return ReliabilityLevel.sure;
  if (score >= ReliabilityConfig.probableMinScore) {
    return ReliabilityLevel.probable;
  }
  return ReliabilityLevel.toCheck;
}
