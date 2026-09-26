/// What the end-of-listening summary shows (fork/PLAN.md J6c, SPEC.md 9.8).
///
/// Pure data: built from a finished session, the species already verified
/// in other sessions and the geo-model's opinion, so it tests without
/// providers.
library;

import '../../features/live/live_session.dart';
import '../data/observation_index.dart';
import '../reliability/reliability_config.dart';

/// Part of the day a listening started in, for the headline.
enum DayPart { morning, afternoon, evening, night }

/// First hour of each part of the day (local time). Before [morning] or
/// from [night] on, it is night.
abstract final class DayPartHours {
  static const int morning = 5;
  static const int afternoon = 12;
  static const int evening = 18;
  static const int night = 22;
}

DayPart dayPartOf(DateTime time) {
  final hour = time.toLocal().hour;
  if (hour < DayPartHours.morning || hour >= DayPartHours.night) {
    return DayPart.night;
  }
  if (hour < DayPartHours.afternoon) return DayPart.morning;
  if (hour < DayPartHours.evening) return DayPart.afternoon;
  return DayPart.evening;
}

/// One species of the session.
class SummarySpecies {
  const SummarySpecies({
    required this.scientificName,
    required this.commonName,
    required this.count,
    required this.firstHeard,
    required this.level,
    required this.unexpected,
    required this.firstEver,
    this.verifiedAt,
    this.keysToCheck = const {},
  });

  final String scientificName;
  final String commonName;

  /// Contacts in this session (rejected ones aside).
  final int count;

  final DateTime firstHeard;

  /// Best level over the session's contacts.
  final ReliabilityLevel level;

  /// The geo-model does not expect it here this week.
  final bool unexpected;

  /// Never verified in another session.
  final bool firstEver;

  /// First contact that made it « Sûr » (or confirmed), if any.
  final DateTime? verifiedAt;

  /// Unreviewed contacts to check: all of them while the species is not
  /// « Sûr » in this session, none once it is.
  final Set<String> keysToCheck;

  /// Waits for a check: the dot on the species strip.
  bool get pending => level != ReliabilityLevel.sure;

  /// « Première fois »: verified for the first time ever.
  bool get isFirstTime => firstEver && !pending;

  /// « Peut-être une première »: first ever, but not verified yet.
  bool get isMaybeFirst => firstEver && pending;
}

/// A first-ever verified species, with its rank in the user's list.
class FirstTime {
  const FirstTime({required this.species, required this.rank});

  final SummarySpecies species;

  /// « Ta 24e espèce »: species verified before, plus this one's order.
  final int rank;
}

class ListeningSummary {
  const ListeningSummary({
    required this.start,
    required this.end,
    required this.duration,
    required this.species,
    required this.contacts,
    required this.firstTimes,
    required this.maybeFirsts,
  });

  /// Builds the summary of [session].
  ///
  /// [verifiedBefore] holds the species verified in other sessions
  /// ([ObservationIndex.verifiedSpecies]). [presence] gives the geo-model's
  /// opinion per species, null when unknown (then a high score stays
  /// « Probable », as in the Live screen).
  factory ListeningSummary.of(
    LiveSession session, {
    required Set<String> verifiedBefore,
    GeoPresence? Function(String scientificName)? presence,
  }) {
    final bySpecies = <String, List<(int, DetectionRecord)>>{};
    for (var i = 0; i < session.detections.length; i++) {
      final d = session.detections[i];
      if (d.isRejected || d.isUnknown) continue;
      bySpecies.putIfAbsent(d.scientificName, () => []).add((i, d));
    }

    final species = <SummarySpecies>[];
    for (final MapEntry(key: name, value: records) in bySpecies.entries) {
      records.sort((a, b) => a.$2.timestamp.compareTo(b.$2.timestamp));
      final geo = presence?.call(name);
      var best = ReliabilityLevel.toCheck;
      DateTime? verifiedAt;
      for (final (_, d) in records) {
        final level = reliabilityFor(
          score: d.confidence,
          review: d.reviewStatus,
          presence: geo,
        );
        if (level.index < best.index) best = level;
        if (level == ReliabilityLevel.sure) verifiedAt ??= d.timestamp;
      }
      species.add(
        SummarySpecies(
          scientificName: name,
          commonName: records.first.$2.commonName,
          count: records.length,
          firstHeard: records.first.$2.timestamp,
          level: best,
          unexpected: geo?.unexpected ?? false,
          firstEver: !verifiedBefore.contains(name),
          verifiedAt: verifiedAt,
          keysToCheck:
              best == ReliabilityLevel.sure
                  ? const {}
                  : {
                    for (final (_, d) in records)
                      if (d.reviewStatus == ReviewStatus.unreviewed)
                        detectionKey(session.id, d),
                  },
        ),
      );
    }
    // Most heard first; ties by first contact.
    species.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.firstHeard.compareTo(b.firstHeard);
    });

    final firsts =
        species.where((s) => s.isFirstTime).toList()
          ..sort((a, b) => a.verifiedAt!.compareTo(b.verifiedAt!));
    final alreadyVerified = verifiedBefore.length;
    return ListeningSummary(
      start: session.startTime,
      end: session.endTime ?? session.startTime.add(session.duration),
      duration: session.duration,
      species: species,
      contacts: species.fold(0, (sum, s) => sum + s.count),
      firstTimes: [
        for (var i = 0; i < firsts.length; i++)
          FirstTime(species: firsts[i], rank: alreadyVerified + i + 1),
      ],
      maybeFirsts: [
        for (final s in species)
          if (s.isMaybeFirst) s,
      ]..sort((a, b) => a.firstHeard.compareTo(b.firstHeard)),
    );
  }

  final DateTime start;
  final DateTime end;

  /// Listening time, pauses aside.
  final Duration duration;

  /// Species of the session, most heard first.
  final List<SummarySpecies> species;

  /// Contacts of the session (rejected and unknown ones aside).
  final int contacts;

  /// Species verified for the first time ever, in the order they were.
  final List<FirstTime> firstTimes;

  /// First-ever species still to verify, in the order they were heard.
  final List<SummarySpecies> maybeFirsts;

  DayPart get dayPart => dayPartOf(start);

  bool get isEmpty => species.isEmpty;

  /// Detections to check: the unreviewed contacts of species not « Sûr ».
  Set<String> get keysToCheck => {for (final s in species) ...s.keysToCheck};
}
