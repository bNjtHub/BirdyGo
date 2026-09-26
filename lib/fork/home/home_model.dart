/// What the home screen shows (J6c, fork/maquette/SPEC.md 9.1): today's
/// numbers, the last bird heard and the detections to check.
library;

import 'package:flutter/foundation.dart';

import '../data/observation_index.dart';
import '../reliability/reliability_config.dart';

/// Today's tiles: « 13 espèces aujourd'hui · 52 contacts · 1 nouvelle ».
@immutable
class DaySummary {
  const DaySummary({
    required this.species,
    required this.contacts,
    required this.newSpecies,
  });

  static const DaySummary empty = DaySummary(
    species: 0,
    contacts: 0,
    newSpecies: 0,
  );

  final int species;
  final int contacts;

  /// Species never heard before today, with a Sûr or confirmed contact
  /// (the same rule as the Bilan's « Première fois »).
  final int newSpecies;

  bool get isEmpty => contacts == 0;
}

/// Builds today's tiles from today's [detections] (rejected ones already
/// left out by the index).
///
/// - [presence]: geo presence per species; a missing species has an
///   unknown plausibility (never Sûr without a confirmation).
/// - [heardBefore]: species heard before today; null when unknown, and then
///   nothing is new.
DaySummary buildDaySummary({
  required List<IndexedDetection> detections,
  Map<String, GeoPresence> presence = const {},
  Set<String>? heardBefore,
}) {
  final levels = <String, List<ReliabilityLevel>>{};
  for (final d in detections) {
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
  if (heardBefore != null) {
    for (final MapEntry(key: name, value: list) in levels.entries) {
      if (!heardBefore.contains(name) &&
          bestLevel(list) == ReliabilityLevel.sure) {
        newSpecies++;
      }
    }
  }
  return DaySummary(
    species: levels.length,
    contacts: detections.length,
    newSpecies: newSpecies,
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
