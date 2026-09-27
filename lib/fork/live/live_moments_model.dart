/// Which moment the Live screen shows (J6e, SPEC.md 6.1, fork/DESIGN.md):
/// « Première rencontre » when a bird is « Sûr » for the very first time,
/// the golden card when a never-verified bird is « Rare ici · à
/// confirmer ». Pure, so it is tested alone.
library;

import '../reliability/reliability_config.dart';
import 'live_table_model.dart';

enum LiveMomentKind { firstTime, rare }

class LiveMoment {
  const LiveMoment({
    required this.kind,
    required this.entry,
    required this.rank,
  });

  final LiveMomentKind kind;
  final LiveTableEntry entry;

  /// Rank of the species in the notebook once verified (« 24e espèce »).
  final int rank;
}

/// Tracks the moments of one listening. Each species gets one moment at
/// most; a moment that comes while another is shown is dropped (the Bilan
/// lists it), as SPEC.md 6.1 asks.
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
      final name = entry.scientificName;
      if (_handled.contains(name) ||
          _verifiedBefore.contains(name) ||
          !isBird(name)) {
        continue;
      }
      final record = entry.record;
      final presence = presenceOf(name);
      final level = reliabilityFor(
        score: record.confidence,
        review: record.reviewStatus,
        presence: presence,
      );
      if (level == ReliabilityLevel.sure) {
        _handled.add(name);
        _added++;
        return LiveMoment(
          kind: LiveMomentKind.firstTime,
          entry: entry,
          rank: verifiedCount,
        );
      }
      if (placeOnlyToCheck(
        score: record.confidence,
        review: record.reviewStatus,
        presence: presence,
      )) {
        _handled.add(name);
        return LiveMoment(
          kind: LiveMomentKind.rare,
          entry: entry,
          rank: verifiedCount + 1,
        );
      }
    }
    return null;
  }

  /// « C'est bien lui » on a rare bird: it joins the notebook.
  void confirmed() => _added++;
}
