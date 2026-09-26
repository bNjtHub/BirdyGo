/// « Oiseaux des jardins » count (LPO and MNHN), fork/PLAN.md J5b.
///
/// The protocol counts the birds seen perched in the garden, plus the
/// swallows, swifts and raptors hunting above it: for each species, the
/// largest number seen at the same time, entered by hand. Sound detections
/// are only an invitation to look. Nothing is sent: a summary is reported
/// by the observer on oiseauxdesjardins.fr.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';
import '../lpo/lpo_config.dart';

/// SharedPreferences key of the count in progress (or just finished).
const String kGardenCountPref = 'fork_garden_count';

/// Birds usually seen in French gardens, offered first when adding a
/// species (any other species can be searched).
const List<String> kGardenSpecies = [
  'Parus major',
  'Cyanistes caeruleus',
  'Erithacus rubecula',
  'Turdus merula',
  'Passer domesticus',
  'Fringilla coelebs',
  'Streptopelia decaocto',
  'Columba palumbus',
  'Sturnus vulgaris',
  'Pica pica',
  'Corvus corone',
  'Chloris chloris',
  'Carduelis carduelis',
  'Prunella modularis',
  'Troglodytes troglodytes',
  'Sitta europaea',
  'Aegithalos caudatus',
  'Dendrocopos major',
  'Garrulus glandarius',
  'Phoenicurus ochruros',
  'Sylvia atricapilla',
  'Turdus philomelos',
  'Coloeus monedula',
  'Poecile palustris',
  'Periparus ater',
  'Lophophanes cristatus',
  'Certhia brachydactyla',
  'Regulus ignicapilla',
  'Serinus serinus',
  'Pyrrhula pyrrhula',
  'Spinus spinus',
  'Fringilla montifringilla',
  'Coccothraustes coccothraustes',
  'Passer montanus',
  'Motacilla alba',
  'Picus viridis',
  'Phylloscopus collybita',
  'Hirundo rustica',
  'Delichon urbicum',
  'Apus apus',
  'Accipiter nisus',
  'Falco tinnunculus',
  'Buteo buteo',
];

/// Saturday of the last full weekend of [month] in [year].
DateTime lastFullWeekendSaturday(int year, int month) {
  final lastDay = DateTime(year, month + 1, 0);
  final sinceSunday = (lastDay.weekday - DateTime.sunday) % 7;
  return DateTime(year, month, lastDay.day - sinceSunday - 1);
}

/// True on the Saturday or Sunday of a national count weekend.
bool isNationalGardenWeekend(DateTime date) {
  for (final month in LpoConfig.gardenNationalMonths) {
    if (date.month != month) continue;
    final saturday = lastFullWeekendSaturday(date.year, month);
    if (date.day == saturday.day || date.day == saturday.day + 1) return true;
  }
  return false;
}

/// A garden count: its start, its planned length (national weekends
/// only), the largest number seen at once per species, and its end.
@immutable
class GardenCount {
  const GardenCount({
    required this.start,
    this.planned,
    this.counts = const {},
    this.end,
  });

  factory GardenCount.fromJson(Map<String, dynamic> json) => GardenCount(
    start: DateTime.parse(json['start'] as String),
    planned:
        json['plannedMinutes'] == null
            ? null
            : Duration(minutes: json['plannedMinutes'] as int),
    counts: {
      for (final e in (json['counts'] as Map<String, dynamic>? ?? {}).entries)
        e.key: e.value as int,
    },
    end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
  );

  /// Starts a count at [now]: one hour on a national weekend, free
  /// otherwise.
  factory GardenCount.startAt(DateTime now) => GardenCount(
    start: now,
    planned:
        isNationalGardenWeekend(now) ? LpoConfig.gardenNationalDuration : null,
  );

  final DateTime start;

  /// Planned length, or null for a free duration.
  final Duration? planned;

  /// Species (scientific name) to largest number seen at once, in the
  /// order they were added.
  final Map<String, int> counts;

  final DateTime? end;

  bool get finished => end != null;

  Duration elapsed(DateTime now) => (end ?? now).difference(start);

  /// Species seen at least once, in the order they were added.
  Map<String, int> get seen => {
    for (final e in counts.entries)
      if (e.value > 0) e.key: e.value,
  };

  GardenCount copyWith({Map<String, int>? counts, DateTime? end}) =>
      GardenCount(
        start: start,
        planned: planned,
        counts: counts ?? this.counts,
        end: end ?? this.end,
      );

  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    if (planned != null) 'plannedMinutes': planned!.inMinutes,
    'counts': counts,
    if (end != null) 'end': end!.toIso8601String(),
  };
}

/// The count in progress, kept in the preferences so leaving the screen
/// or closing the app loses nothing.
class GardenCountController extends Notifier<GardenCount?> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  GardenCount? build() {
    final raw = _prefs.getString(kGardenCountPref);
    if (raw == null) return null;
    try {
      return GardenCount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Garden count: unreadable saved count ($error)');
      return null;
    }
  }

  void _save(GardenCount? count) {
    state = count;
    if (count == null) {
      _prefs.remove(kGardenCountPref);
    } else {
      _prefs.setString(kGardenCountPref, jsonEncode(count.toJson()));
    }
  }

  void start(DateTime now) => _save(GardenCount.startAt(now));

  /// Adds [scientificName] with no bird yet (seen birds are entered by
  /// hand).
  void addSpecies(String scientificName) {
    final count = state;
    if (count == null || count.counts.containsKey(scientificName)) return;
    _save(count.copyWith(counts: {...count.counts, scientificName: 0}));
  }

  void setCount(String scientificName, int value) {
    final count = state;
    if (count == null) return;
    _save(
      count.copyWith(
        counts: {
          ...count.counts,
          scientificName: value.clamp(0, LpoConfig.gardenMaxCount),
        },
      ),
    );
  }

  void finish(DateTime now) {
    final count = state;
    if (count == null || count.finished) return;
    _save(count.copyWith(end: now));
  }

  void clear() => _save(null);
}

final gardenCountProvider =
    NotifierProvider<GardenCountController, GardenCount?>(
      GardenCountController.new,
    );
