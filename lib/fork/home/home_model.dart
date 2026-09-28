/// What the home screen shows (J6c, fork/maquette/SPEC.md 9.1; J6f blocks):
/// today's numbers and species, the last bird heard and the detections to
/// check.
library;

import 'package:flutter/foundation.dart';

import '../data/observation_index.dart';
import '../reliability/reliability_config.dart';

/// One species heard today, for the « Aujourd'hui » row.
@immutable
class DaySpecies {
  const DaySpecies({
    required this.scientificName,
    required this.commonName,
    required this.contacts,
  });

  final String scientificName;

  /// Name stored with the detection (fallback of the taxonomy name).
  final String commonName;
  final int contacts;
}

/// Today's line: « 13 espèces · 52 contacts · 1 nouvelle », and the species.
@immutable
class DaySummary {
  const DaySummary({
    required this.species,
    required this.contacts,
    required this.newSpecies,
    this.heard = const [],
    this.latestSessionId,
    this.sessionCount = 0,
  });

  static const DaySummary empty = DaySummary(
    species: 0,
    contacts: 0,
    newSpecies: 0,
  );

  final int species;
  final int contacts;

  /// Species Sûr or confirmed today and never verified before (the same
  /// rule as the listening summary's « Première fois »).
  final int newSpecies;

  /// Today's species, the most recently heard first.
  final List<DaySpecies> heard;

  /// Session of the most recent detection of the day: the one whose Bilan
  /// « Aujourd'hui » opens (the Bilan sums up a single session). Null when
  /// nothing was heard today.
  final String? latestSessionId;

  /// Sessions with at least one detection today.
  final int sessionCount;

  bool get isEmpty => contacts == 0;
}

/// Builds today's line from today's [detections] (rejected ones already
/// left out by the index).
///
/// - [presence]: geo presence per species; a missing species has an
///   unknown plausibility (never Sûr without a confirmation).
/// - [verifiedBefore]: species verified before today
///   ([ObservationIndex.verifiedSpecies]); null when unknown, and then
///   nothing is new.
DaySummary buildDaySummary({
  required List<IndexedDetection> detections,
  Map<String, GeoPresence> presence = const {},
  Set<String>? verifiedBefore,
}) {
  final levels = <String, List<ReliabilityLevel>>{};
  final latest = <String, IndexedDetection>{};
  for (final d in detections) {
    final seen = latest[d.scientificName];
    if (seen == null || d.start.isAfter(seen.start)) {
      latest[d.scientificName] = d;
    }
    levels
        .putIfAbsent(d.scientificName, () => [])
        .add(
          reliabilityFor(
            score: d.confidence,
            review: d.reviewStatus,
            presence: presence[d.scientificName],
          ),
        );
  }
  var newSpecies = 0;
  if (verifiedBefore != null) {
    for (final MapEntry(key: name, value: list) in levels.entries) {
      if (!verifiedBefore.contains(name) &&
          bestLevel(list) == ReliabilityLevel.sure) {
        newSpecies++;
      }
    }
  }
  IndexedDetection? newest;
  final sessions = <String>{};
  for (final d in detections) {
    sessions.add(d.sessionId);
    if (newest == null || d.start.isAfter(newest.start)) newest = d;
  }
  final heard =
      latest.values.toList()..sort((a, b) => b.start.compareTo(a.start));
  return DaySummary(
    species: levels.length,
    contacts: detections.length,
    newSpecies: newSpecies,
    latestSessionId: newest?.sessionId,
    sessionCount: sessions.length,
    heard: [
      for (final d in heard)
        DaySpecies(
          scientificName: d.scientificName,
          commonName: d.commonName,
          contacts: levels[d.scientificName]!.length,
        ),
    ],
  );
}

/// « Dernier oiseau entendu ».
@immutable
class LastBird {
  const LastBird({
    required this.detection,
    required this.level,
    required this.unexpected,
    required this.total,
  });

  final IndexedDetection detection;

  /// Level of that contact.
  final ReliabilityLevel level;
  final bool unexpected;

  /// Contacts of the species over every outing (« 142 au total »).
  final int total;

  String get scientificName => detection.scientificName;

  /// Clip of that contact (« Réécouter »); null when none was kept.
  String? get clipPath => detection.clipPath;
}

/// Everything the home screen loads.
@immutable
class HomeSnapshot {
  const HomeSnapshot({
    this.today = DaySummary.empty,
    this.last,
    this.toVerify = 0,
  });

  final DaySummary today;
  final LastBird? last;

  /// Detections waiting in the quick review.
  final int toVerify;
}
