/// Pure logic of the species page (J6c « Fiche espèce »,
/// fork/maquette/SPEC.md 9.13): the year as seen by the geo-model, the order
/// of the sheet chips, and what the page shows about the user's contacts.
library;

import '../../features/inference/geo_abundance.dart';
import '../data/observation_index.dart';
import '../species_sheet/species_sheet.dart';

/// Geo-model weeks per month (48 weeks, see `GeoModel.dateTimeToWeek`).
const int _weeksPerMonth = 4;

/// The geo-model's year for one species at the phone's place.
class YearPresence {
  const YearPresence(this.months);

  /// Built from the 48 weekly scores: a month takes its best week.
  factory YearPresence.fromWeeks(List<double> weeks) {
    if (weeks.length != 12 * _weeksPerMonth) {
      throw ArgumentError.value(weeks.length, 'weeks', 'expected 48');
    }
    return YearPresence([
      for (var m = 0; m < 12; m++)
        weeks
            .sublist(m * _weeksPerMonth, (m + 1) * _weeksPerMonth)
            .reduce((a, b) => a > b ? a : b),
    ]);
  }

  /// Best weekly score of each month, January first.
  final List<double> months;

  /// Whether the species is expected here in [month] (1 to 12): same
  /// threshold as the Explore list.
  bool presentIn(int month) =>
      months[month - 1] >= kAbundanceInclusionThreshold;

  /// Bar heights from 0 to 1, relative to the species' best month.
  List<double> get bars {
    final top = months.reduce((a, b) => a > b ? a : b);
    return [for (final m in months) top <= 0 ? 0 : m / top];
  }

  /// What the page says about the year.
  PresenceSpan get span {
    final present = [for (var m = 1; m <= 12; m++) presentIn(m)];
    final count = present.where((p) => p).length;
    if (count == 12) return const PresenceSpan.allYear();
    if (count == 0) return const PresenceSpan.rare();
    // One run of present months, possibly across the new year.
    final starts = [
      for (var m = 1; m <= 12; m++)
        if (present[m - 1] && !present[(m + 10) % 12]) m,
    ];
    if (starts.length != 1) return const PresenceSpan.partOfYear();
    final from = starts.single;
    final to = (from + count - 2) % 12 + 1;
    return PresenceSpan.range(from, to);
  }
}

enum PresenceKind { allYear, range, partOfYear, rare }

/// Months when the species is expected here.
class PresenceSpan {
  const PresenceSpan.allYear()
    : kind = PresenceKind.allYear,
      from = null,
      to = null;
  const PresenceSpan.rare() : kind = PresenceKind.rare, from = null, to = null;
  const PresenceSpan.partOfYear()
    : kind = PresenceKind.partOfYear,
      from = null,
      to = null;
  const PresenceSpan.range(int this.from, int this.to)
    : kind = PresenceKind.range;

  final PresenceKind kind;

  /// First and last present month (1 to 12) of a [PresenceKind.range].
  final int? from;
  final int? to;

  @override
  bool operator ==(Object other) =>
      other is PresenceSpan &&
      other.kind == kind &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(kind, from, to);

  @override
  String toString() => 'PresenceSpan($kind, $from, $to)';
}

/// Chip order of SPEC.md 9.13, then the sections the mockup lacks. The
/// summary is the lead paragraph, never a chip.
const List<SheetSection> sheetChipOrder = [
  SheetSection.size,
  SheetSection.behaviour,
  SheetSection.whyHere,
  SheetSection.migration,
  SheetSection.enemies,
  SheetSection.anecdote,
  SheetSection.byEar,
  SheetSection.confusions,
];

/// Chips of [sheet], without its empty sections.
List<SheetSection> sheetChips(SpeciesSheet sheet) => [
  for (final section in sheetChipOrder)
    if (sheet.sections.containsKey(section)) section,
];

/// A spot of the mini map.
typedef MapSpot = ({double latitude, double longitude});

/// Everything the page shows about the user's own contacts with a species.
class SpeciesRecord {
  const SpeciesRecord({
    this.tally,
    this.confirmed = 0,
    this.reviewed = 0,
    this.verified = false,
    this.clips = const [],
    this.clipCount = 0,
    this.favorites = const {},
    this.hours = const [],
    this.spots = const [],
  });

  /// Never heard: nothing personal to show.
  static const SpeciesRecord empty = SpeciesRecord();

  /// Contacts, days, first and last contact. Null when never heard.
  final SpeciesTally? tally;

  /// Reviews: confirmed among reviewed.
  final int confirmed;
  final int reviewed;

  /// Confirmed, or heard with a « Sûr » score (same rule as the summary's
  /// « Première fois »).
  final bool verified;

  /// Best recordings shown on the page, favorites first.
  final List<IndexedDetection> clips;

  /// Every recording of the species (the page shows a few).
  final int clipCount;

  /// Keys of favorite recordings among [clips].
  final Set<String> favorites;

  /// Contacts per local hour, 24 values, or empty.
  final List<int> hours;

  /// Distinct places of the contacts, newest first.
  final List<MapSpot> spots;

  bool get heard => tally != null;

  bool get hasActivity => hours.any((h) => h > 0);

  SpeciesRecord copyWith({Set<String>? favorites}) => SpeciesRecord(
    tally: tally,
    confirmed: confirmed,
    reviewed: reviewed,
    verified: verified,
    clips: clips,
    clipCount: clipCount,
    favorites: favorites ?? this.favorites,
    hours: hours,
    spots: spots,
  );
}

/// Picks the [limit] recordings of the page: favorites first, then the best
/// scores ([clips] comes best first).
List<IndexedDetection> pageClips(
  List<IndexedDetection> clips,
  Set<String> favorites, {
  required int limit,
}) {
  final sorted = [
    ...clips.where((c) => favorites.contains(c.key)),
    ...clips.where((c) => !favorites.contains(c.key)),
  ];
  return sorted.take(limit).toList();
}

/// Distinct places, rounded to [decimals] (about 100 m at 3), at most
/// [limit], in the order given.
List<MapSpot> distinctSpots(
  Iterable<IndexedDetection> points, {
  required int limit,
  required int decimals,
}) {
  final seen = <String>{};
  final spots = <MapSpot>[];
  for (final p in points) {
    final lat = p.latitude;
    final lon = p.longitude;
    if (lat == null || lon == null) continue;
    final key =
        '${lat.toStringAsFixed(decimals)},${lon.toStringAsFixed(decimals)}';
    if (!seen.add(key)) continue;
    spots.add((latitude: lat, longitude: lon));
    if (spots.length >= limit) break;
  }
  return spots;
}
