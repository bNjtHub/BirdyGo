/// Level of a live row (J7): the level of the best contact of the outing,
/// with the thresholds of [ReliabilityConfig]. It never goes down while the
/// species sings on, and it is the rule of the end-of-outing summary
/// (`ListeningSummary.of` keeps the best level over the contacts).
library;

import '../reliability/reliability_config.dart';
import 'live_table_model.dart';

/// Reliability level of [entry] at a place where [presence] applies.
ReliabilityLevel liveLevelOf(LiveTableEntry entry, GeoPresence? presence) =>
    reliabilityFor(
      score: entry.levelRecord.confidence,
      review: entry.levelRecord.reviewStatus,
      presence: presence,
    );
