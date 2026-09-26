/// Summary of one listening session for the Bilan screen (J6c,
/// fork/maquette/SPEC.md 9.8): numbers, species, novelties and detections
/// left to check.
library;

import 'package:flutter/foundation.dart';

import '../../features/live/live_session.dart';
import '../data/observation_index.dart';
import '../reliability/reliability_config.dart';

/// Part of the day the listening started in, for « Belle matinée ! ».
enum BilanMoment { morning, afternoon, evening, night }

/// Local start hours of each [BilanMoment].
abstract final class BilanMomentHours {
  static const int morning = 5;
  static const int afternoon = 12;
  static const int evening = 18;
  static const int night = 22;
}

/// Part of the day of [start] (local time).
BilanMoment momentOf(DateTime start) {
  final hour = start.toLocal().hour;
  if (hour >= BilanMomentHours.night || hour < BilanMomentHours.morning) {
    return BilanMoment.night;
  }
  if (hour >= BilanMomentHours.evening) return BilanMoment.evening;
  if (hour >= BilanMomentHours.afternoon) return BilanMoment.afternoon;
  return BilanMoment.morning;
}

/// One species of the outing.
@immutable
class BilanSpecies {
  const BilanSpecies({
    required this.scientificName,
    required this.commonName,
    required this.count,
    required this.firstHeard,
    required this.level,
    required this.unexpected,
    required this.isNew,
    required this.toVerifyKeys,
  });

  final String scientificName;

  /// Localized common name.
  final String commonName;

  /// Contacts of this outing (« ×9 »).
  final int count;

  /// Start of the first contact.
  final DateTime firstHeard;

  /// Best level over the outing's contacts (confirmed counts as Sûr).
  final ReliabilityLevel level;

  /// The geo-model does not expect it here this week (« Inattendu ici »).
  final bool unexpected;

  /// Never heard before this outing (rejected contacts aside).
  final bool isNew;

  /// Keys of this species' detections to check, see [BilanSummary.toVerifyKeys].
  final List<String> toVerifyKeys;

  /// No contact is Sûr or confirmed yet: the dot of the species strip.
  bool get pending => level != ReliabilityLevel.sure;
}

/// Everything the Bilan shows.
@immutable
class BilanSummary {
  const BilanSummary({
    required this.start,
    required this.end,
    required this.duration,
    required this.species,
    required this.contacts,
  });

  final DateTime start;
  final DateTime end;

  /// Recorded time (pauses excluded).
  final Duration duration;

  /// Most contacts first, then by first contact.
  final List<BilanSpecies> species;

  final int contacts;

  BilanMoment get moment => momentOf(start);

  bool get isEmpty => species.isEmpty;

  /// New species with a Sûr or confirmed contact, in order of arrival.
  List<BilanSpecies> get newVerified =>
      _byArrival(species.where((s) => s.isNew && !s.pending));

  /// New species still to check (« peut-être deux »), in order of arrival.
  List<BilanSpecies> get newPending =>
      _byArrival(species.where((s) => s.isNew && s.pending));

  /// Unreviewed detections of the species still pending, « Je ne sais pas »
  /// answers aside: the « Vérifier 3 détections » button. A species with a
  /// Sûr or confirmed contact in the outing is settled, so its weaker
  /// contacts are not asked again.
  List<String> get toVerifyKeys => [for (final s in species) ...s.toVerifyKeys];

  static List<BilanSpecies> _byArrival(Iterable<BilanSpecies> list) =>
      list.toList()..sort((a, b) => a.firstHeard.compareTo(b.firstHeard));
}

/// Builds the Bilan of [session].
///
/// - [presence]: geo presence per species at the session's place and week;
///   a species missing from it has an unknown plausibility (never Sûr
///   without a confirmation, as in the review).
/// - [heardBefore]: species heard before the session started; null when
///   unknown, and then nothing is new.
/// - [skippedKeys]: detections answered « Je ne sais pas ».
///
/// Rejected detections and the « unknown species » entries are left out.
BilanSummary buildBilan({
  required LiveSession session,
  Map<String, GeoPresence> presence = const {},
  Set<String>? heardBefore,
  Set<String> skippedKeys = const {},
  String Function(DetectionRecord record)? localizedName,
}) {
  final groups = <String, List<DetectionRecord>>{};
  for (final record in session.detections) {
    if (record.isRejected ||
        record.scientificName == DetectionRecord.unknownSpeciesName) {
      continue;
    }
    groups.putIfAbsent(record.scientificName, () => []).add(record);
  }

  final species = <BilanSpecies>[];
  var contacts = 0;
  for (final MapEntry(key: name, value: records) in groups.entries) {
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    contacts += records.length;
    final geo = presence[name];
    var best = ReliabilityLevel.toCheck;
    final toVerify = <String>[];
    for (final record in records) {
      final level = reliabilityFor(
        score: record.confidence,
        review: record.reviewStatus,
        presence: geo,
      );
      if (level.index < best.index) best = level;
      final key = detectionKey(session.id, record);
      if (!record.isReviewed &&
          level != ReliabilityLevel.sure &&
          !skippedKeys.contains(key)) {
        toVerify.add(key);
      }
    }
    species.add(
      BilanSpecies(
        scientificName: name,
        commonName:
            localizedName?.call(records.first) ?? records.first.commonName,
        count: records.length,
        firstHeard: records.first.timestamp,
        level: best,
        unexpected: geo?.unexpected ?? false,
        isNew: heardBefore != null && !heardBefore.contains(name),
        toVerifyKeys: best == ReliabilityLevel.sure ? const [] : toVerify,
      ),
    );
  }
  species.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    final byTime = a.firstHeard.compareTo(b.firstHeard);
    return byTime != 0 ? byTime : a.scientificName.compareTo(b.scientificName);
  });

  final duration = session.duration;
  return BilanSummary(
    start: session.startTime,
    end: session.endTime ?? session.startTime.add(duration),
    duration: duration,
    species: species,
    contacts: contacts,
  );
}
