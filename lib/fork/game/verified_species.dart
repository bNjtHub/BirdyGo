/// Species that count for the game (J6e, SPEC.md 7.1): at least one
/// detection confirmed by the user, or one « Sûr » detection.
///
/// « Sûr » follows [reliabilityFor]: a high score, and the geo-model saying
/// the species is plausible at the place and week of the detection. A rare
/// bird therefore always waits for « C'est bien lui », and a detection
/// without a position never counts on its score alone.
library;

import '../data/observation_index.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';

/// Scientific names of the species verified at least once.
Future<Set<String>> gameVerifiedSpecies({
  required ObservationIndex index,
  required GeoPresenceService presence,
}) async {
  final verified = <String>{
    for (final tally in await index.speciesReviewTallies())
      if (tally.confirmed > 0) tally.scientificName,
  };
  final candidates = await index.sureCandidates(
    minScore: ReliabilityConfig.sureMinScore,
  );
  for (final detection in candidates) {
    if (verified.contains(detection.scientificName)) continue;
    final level = reliabilityFor(
      score: detection.confidence,
      review: detection.reviewStatus,
      presence: await presence.presenceAt(
        detection.scientificName,
        latitude: detection.latitude,
        longitude: detection.longitude,
        time: detection.start,
      ),
    );
    if (level == ReliabilityLevel.sure) verified.add(detection.scientificName);
  }
  return verified;
}
