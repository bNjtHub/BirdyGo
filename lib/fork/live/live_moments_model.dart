/// Which moment the Live screen shows (J6e, SPEC.md 6.1, fork/DESIGN.md):
/// « Première rencontre » when a bird is « Sûr » for the very first time,
/// the golden card when a never-verified bird is « Rare ici · à
/// confirmer ». Pure, so it is tested alone.
library;

import '../reliability/reliability_config.dart';
import 'live_level.dart';
import 'live_table_model.dart';

enum LiveMomentKind { firstTime, rare }

/// The geo-model's presence score (0–1) under which the rare card says
/// « moins de 1 sur 100 » instead of counting its chances.
const double rareLowPresenceBelow = 0.01;

/// « 1 chance sur n de l'entendre ici »: n = round(1 / score). Null
/// without a usable score (unknown or not above zero).
int? rareChanceN(double? presenceScore) =>
    presenceScore == null || presenceScore <= 0
        ? null
        : (1 / presenceScore).round();

class LiveMoment {
  LiveMoment({required this.kind, required this.entry, this.rank = 0});

  final LiveMomentKind kind;
  final LiveTableEntry entry;

  /// Rank of the species in the notebook once verified (« 24e espèce »).
  /// 0 until the tracker gives it: when the card is shown (first
  /// encounter) or when the bird is confirmed (rare). Then fixed.
  int rank;
}

/// Tracks the moments of one listening. Each species gets one moment at
/// most. Moments that come while another is shown are queued by the screen
/// (J6h: a series of first encounters) rather than dropped.
class LiveMomentTracker {
  LiveMomentTracker({required Set<String> verifiedBefore})
    : _verifiedBefore = verifiedBefore;

  final Set<String> _verifiedBefore;
  final Set<String> _handled = {};
  int _added = 0;

  /// Species verified so far, this listening included.
  int get verifiedCount => _verifiedBefore.length + _added;

  /// The next moment among [entries], or null. [presenceOf] gives the
  /// geo-model's opinion here, [isBird] keeps birds only.
  LiveMoment? next(
    List<LiveTableEntry> entries, {
    required GeoPresence? Function(String scientificName) presenceOf,
    required bool Function(String scientificName) isBird,
  }) {
    for (final entry in entries) {
      final moment = _momentOf(entry, presenceOf, isBird);
      if (moment != null) return moment;
    }
    return null;
  }

  /// Every new moment among [entries], in the order of [entries] (J6h): a
  /// series when several birds were heard while the screen was elsewhere,
  /// or while a card was open. Ranks are not given here: see [shown] and
  /// [confirmed], so they follow the order the user really adds species.
  List<LiveMoment> nextAll(
    List<LiveTableEntry> entries, {
    required GeoPresence? Function(String scientificName) presenceOf,
    required bool Function(String scientificName) isBird,
  }) {
    final moments = <LiveMoment>[];
    for (final entry in entries) {
      final moment = _momentOf(entry, presenceOf, isBird);
      if (moment != null) moments.add(moment);
    }
    return moments;
  }

  LiveMoment? _momentOf(
    LiveTableEntry entry,
    GeoPresence? Function(String scientificName) presenceOf,
    bool Function(String scientificName) isBird,
  ) {
    final name = entry.scientificName;
    if (_handled.contains(name) ||
        _verifiedBefore.contains(name) ||
        !isBird(name)) {
      return null;
    }
    // J7: the best contact of the outing, like the level of the row.
    final record = entry.levelRecord;
    final presence = presenceOf(name);
    final level = liveLevelOf(entry, presence);
    if (level == ReliabilityLevel.sure) {
      _handled.add(name);
      return LiveMoment(kind: LiveMomentKind.firstTime, entry: entry);
    }
    if (placeOnlyToCheck(
      score: record.confidence,
      review: record.reviewStatus,
      presence: presence,
    )) {
      _handled.add(name);
      return LiveMoment(kind: LiveMomentKind.rare, entry: entry);
    }
    return null;
  }

  /// A first-encounter card is shown: the species joins the notebook and
  /// takes the next rank. No-op for a card that already has one.
  void shown(LiveMoment moment) {
    if (moment.kind != LiveMomentKind.firstTime || moment.rank > 0) return;
    _added++;
    moment.rank = verifiedCount;
  }

  /// A shown first-encounter card gives way (a rare bird takes its place):
  /// it gives its rank back and takes a new one when shown again.
  void released(LiveMoment moment) {
    if (moment.kind != LiveMomentKind.firstTime || moment.rank == 0) return;
    _added--;
    moment.rank = 0;
  }

  /// « C'est bien lui » on a rare bird: it joins the notebook now.
  void confirmed(LiveMoment moment) {
    if (moment.rank > 0) return;
    _added++;
    moment.rank = verifiedCount;
  }
}
