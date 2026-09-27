/// A local, persistent listening goal and the rules for acoustic progress.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../features/inference/geo_abundance.dart';
import '../../features/live/live_session.dart';
import '../data/observation_index.dart';
import '../reliability/reliability_config.dart';

abstract final class DailyGoalConfig {
  static const int targetCount = 8;

  /// A goal belongs to this area throughout its calendar day.
  static const int radiusKm = 10;
}

DateTime dailyGoalDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class DailyGoalSpecies {
  const DailyGoalSpecies({
    required this.scientificName,
    required this.commonName,
    required this.geoScore,
    required this.unexpected,
  });

  final String scientificName;
  final String commonName;
  final double geoScore;

  /// Geo-model presence at the saved place/week, retained for offline use.
  final bool unexpected;

  Map<String, Object> toJson() => {
    'scientificName': scientificName,
    'commonName': commonName,
    'geoScore': geoScore,
    'unexpected': unexpected,
  };

  factory DailyGoalSpecies.fromJson(Map<String, dynamic> json) {
    final score = (json['geoScore'] as num).toDouble();
    final name = json['scientificName'] as String;
    if (name.isEmpty || !score.isFinite || score < 0 || score > 1) {
      throw const FormatException('Invalid daily goal species');
    }
    return DailyGoalSpecies(
      scientificName: name,
      commonName: json['commonName'] as String,
      geoScore: score,
      unexpected: json['unexpected'] as bool,
    );
  }
}

/// Only birds known by both models, above the shared local inclusion floor.
/// Ties are resolved by name so reseeding the same inputs is deterministic.
List<DailyGoalSpecies> dailyGoalCandidates({
  required Map<String, double> scores,
  required Map<String, String> audioClasses,
  required String Function(String scientificName) commonName,
}) {
  final presence = presenceFromWeekScores(
    scores,
    audioLabels: audioClasses.keys.toSet(),
  );
  final candidates = [
    for (final entry in scores.entries)
      if (audioClasses[entry.key] == 'Aves' &&
          entry.value.isFinite &&
          entry.value >= kAbundanceInclusionThreshold &&
          entry.value <= 1)
        DailyGoalSpecies(
          scientificName: entry.key,
          commonName: commonName(entry.key),
          geoScore: entry.value,
          unexpected: (presence[entry.key] ?? kAbsentHere).unexpected,
        ),
  ];
  candidates.sort((a, b) {
    final score = b.geoScore.compareTo(a.geoScore);
    return score == 0 ? a.scientificName.compareTo(b.scientificName) : score;
  });
  return candidates;
}

class DailyGoal {
  DailyGoal({
    required DateTime day,
    required this.latitude,
    required this.longitude,
    required List<DailyGoalSpecies> species,
    required List<DailyGoalSpecies> candidates,
  }) : day = dailyGoalDay(day),
       species = List.unmodifiable(species),
       candidates = List.unmodifiable(candidates);

  factory DailyGoal.create({
    required DateTime day,
    required double latitude,
    required double longitude,
    required List<DailyGoalSpecies> candidates,
  }) {
    final unique = <String, DailyGoalSpecies>{};
    for (final bird in candidates) {
      unique.putIfAbsent(bird.scientificName, () => bird);
    }
    final pool = unique.values.toList();
    return DailyGoal(
      day: day,
      latitude: latitude,
      longitude: longitude,
      species: pool.take(DailyGoalConfig.targetCount).toList(),
      candidates: pool,
    );
  }

  final DateTime day;
  final double latitude;
  final double longitude;
  final List<DailyGoalSpecies> species;
  final List<DailyGoalSpecies> candidates;

  int get total => species.length;
  DateTime get nextDay => DateTime(day.year, day.month, day.day + 1);
  bool isForDay(DateTime now) => day == dailyGoalDay(now);

  List<DailyGoalSpecies> get availableReplacements {
    final selected = species.map((bird) => bird.scientificName).toSet();
    return candidates
        .where((bird) => !selected.contains(bird.scientificName))
        .toList();
  }

  /// Invalid or duplicate replacements leave the goal intact.
  DailyGoal replace(String oldName, String newName) {
    final index = species.indexWhere((bird) => bird.scientificName == oldName);
    if (index < 0 || species.any((bird) => bird.scientificName == newName)) {
      return this;
    }
    final replacements = availableReplacements.where(
      (bird) => bird.scientificName == newName,
    );
    if (replacements.isEmpty) return this;
    final updated = [...species];
    updated[index] = replacements.first;
    return DailyGoal(
      day: day,
      latitude: latitude,
      longitude: longitude,
      species: updated,
      candidates: candidates,
    );
  }

  bool containsPosition(double? lat, double? lon) {
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return false;
    }
    const radians = math.pi / 180;
    final dLat = (lat - latitude) * radians;
    final dLon = (lon - longitude) * radians;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(lat * radians) *
            math.pow(math.sin(dLon / 2), 2);
    const earthRadiusKm = 6371.0088;
    final distance = 2 * earthRadiusKm * math.asin(math.sqrt(a.clamp(0, 1)));
    return distance <= DailyGoalConfig.radiusKm;
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'day': day.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'species': species.map((bird) => bird.scientificName).toList(),
    'candidates': candidates.map((bird) => bird.toJson()).toList(),
  };

  factory DailyGoal.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown daily goal version');
    }
    final latitude = (json['latitude'] as num).toDouble();
    final longitude = (json['longitude'] as num).toDouble();
    if (!latitude.isFinite ||
        latitude.abs() > 90 ||
        !longitude.isFinite ||
        longitude.abs() > 180) {
      throw const FormatException('Invalid daily goal position');
    }
    final pool =
        (json['candidates'] as List)
            .map(
              (bird) => DailyGoalSpecies.fromJson(bird as Map<String, dynamic>),
            )
            .toList();
    final byName = {for (final bird in pool) bird.scientificName: bird};
    final names = (json['species'] as List).cast<String>();
    if (names.isEmpty ||
        names.length > DailyGoalConfig.targetCount ||
        names.toSet().length != names.length ||
        pool.length != byName.length ||
        names.any((name) => !byName.containsKey(name))) {
      throw const FormatException('Invalid daily goal selection');
    }
    return DailyGoal(
      day: DateTime.parse(json['day'] as String),
      latitude: latitude,
      longitude: longitude,
      species: names.map((name) => byName[name]!).toList(),
      candidates: pool,
    );
  }
}

/// Saved acoustic observations count once per target, inside the saved area.
/// The index already excludes practice and imported-file sessions.
Set<String> completedDailyGoalSpecies(
  DailyGoal goal,
  Iterable<IndexedDetection> detections,
) {
  final targets = {for (final bird in goal.species) bird.scientificName: bird};
  final completed = <String>{};
  for (final detection in detections) {
    final target = targets[detection.scientificName];
    if (target == null ||
        detection.reviewStatus == ReviewStatus.rejected ||
        !detection.isHeard ||
        detection.start.isBefore(goal.day) ||
        !detection.start.isBefore(goal.nextDay) ||
        !goal.containsPosition(detection.latitude, detection.longitude)) {
      continue;
    }
    if (detection.source != DetectionSource.auto ||
        reliabilityFor(
              score: detection.confidence,
              review: detection.reviewStatus,
              presence: GeoPresence(unexpected: target.unexpected),
            ) ==
            ReliabilityLevel.sure) {
      completed.add(detection.scientificName);
    }
  }
  return completed;
}

class DailyGoalStore {
  const DailyGoalStore(this.prefs);

  final SharedPreferences prefs;

  DailyGoal? readToday(DateTime now) {
    final raw = prefs.getString(PrefKeys.dailyBirdGoal);
    if (raw == null) return null;
    try {
      final goal = DailyGoal.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return goal.isForDay(now) ? goal : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(DailyGoal goal) async {
    if (!await prefs.setString(
      PrefKeys.dailyBirdGoal,
      jsonEncode(goal.toJson()),
    )) {
      throw StateError('Could not save daily goal');
    }
  }
}

enum DailyGoalStatus {
  idle,
  loading,
  ready,
  needsLocation,
  noCandidates,
  error,
}

class DailyGoalState {
  const DailyGoalState({this.goal, this.status = DailyGoalStatus.idle});

  final DailyGoal? goal;
  final DailyGoalStatus status;
}
