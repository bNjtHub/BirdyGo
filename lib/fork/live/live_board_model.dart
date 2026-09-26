/// Rows of the live table (J6c): one per species heard in the session.
///
/// Pure Dart, so the ordering rules are tested without widgets.
library;

import '../../features/live/live_session.dart';
import '../reliability/reliability_config.dart';

/// One species of the live table.
class LiveBoardEntry {
  const LiveBoardEntry({
    required this.scientificName,
    required this.commonName,
    required this.sessionCount,
    required this.total,
    required this.level,
    required this.unexpected,
    required this.lastHeard,
    required this.singing,
    this.clipPath,
  });

  final String scientificName;
  final String commonName;

  /// Episodes of song in this session (the « ×N »).
  final int sessionCount;

  /// Contacts over every session, this one included.
  final int total;

  /// Best reliability of the species in this session.
  final ReliabilityLevel level;

  /// Rare or out of season here (« Inattendu ici »).
  final bool unexpected;

  /// Start of the species' latest episode.
  final DateTime lastHeard;

  /// Heard in the latest analysis cycle.
  final bool singing;

  /// Newest clip of the species, for the replay button.
  final String? clipPath;
}

/// Builds the table from the session records ([sessionDetections], in any
/// order) and the species of the latest cycle ([currentSpecies]).
/// [presenceOf] gives the geo-model presence (null while unknown).
///
/// Ordering: the species whose latest episode started last comes first.
/// A species therefore moves to the top only when a new episode begins (its
/// « ×N » goes up), never on every cycle while it keeps singing. Rows are
/// never dropped while the session lasts.
List<LiveBoardEntry> buildLiveBoard({
  required List<DetectionRecord> sessionDetections,
  required Set<String> currentSpecies,
  required Map<String, int> savedTotals,
  GeoPresence? Function(String scientificName)? presenceOf,
  String Function(DetectionRecord record)? localizedName,
}) {
  final groups = <String, List<DetectionRecord>>{};
  for (final record in sessionDetections) {
    groups.putIfAbsent(record.scientificName, () => []).add(record);
  }

  final entries = <LiveBoardEntry>[];
  groups.forEach((name, records) {
    var latest = records.first;
    var bestScore = 0.0;
    var confirmed = false;
    DetectionRecord? clipRecord;
    for (final record in records) {
      if (record.timestamp.isAfter(latest.timestamp)) latest = record;
      if (record.confidence > bestScore) bestScore = record.confidence;
      if (record.reviewStatus == ReviewStatus.confirmed) confirmed = true;
      if (record.audioClipPath != null &&
          (clipRecord == null ||
              record.timestamp.isAfter(clipRecord.timestamp))) {
        clipRecord = record;
      }
    }
    final presence = presenceOf?.call(name);
    final level = reliabilityFor(
      score: bestScore,
      review: confirmed ? ReviewStatus.confirmed : ReviewStatus.unreviewed,
      presence: presence,
    );
    entries.add(
      LiveBoardEntry(
        scientificName: name,
        commonName: localizedName?.call(latest) ?? latest.commonName,
        sessionCount: records.length,
        total: (savedTotals[name] ?? 0) + records.length,
        level: level,
        unexpected: presence?.unexpected ?? false,
        lastHeard: latest.timestamp,
        singing: currentSpecies.contains(name),
        clipPath: clipRecord?.audioClipPath,
      ),
    );
  });

  entries.sort((a, b) {
    final byTime = b.lastHeard.compareTo(a.lastHeard);
    return byTime != 0 ? byTime : a.scientificName.compareTo(b.scientificName);
  });
  return entries;
}
