/// Loads the game's facts (J6e) from the observation index and the
/// geo-model. Recomputed when the index changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/aru/aru_schedule.dart';
import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../notebook/notebook_loader.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';
import 'game_config.dart';
import 'game_progress.dart';
import 'streak.dart';
import 'verified_species.dart';

/// Position of the phone, or null when it cannot be had without asking.
typedef GamePosition = ({double latitude, double longitude});

class GameLoader {
  GameLoader({
    required Future<ObservationIndex> Function() index,
    required GeoPresenceService presence,
    required Future<TaxonomyService?> Function() taxonomy,
    required Future<GamePosition?> Function() position,
    required Future<Map<String, List<double>>?> Function(GamePosition)
    weeklyScores,
    DateTime Function()? now,
  }) : _index = index,
       _presence = presence,
       _taxonomy = taxonomy,
       _position = position,
       _weeklyScores = weeklyScores,
       _now = now ?? DateTime.now;

  final Future<ObservationIndex> Function() _index;
  final GeoPresenceService _presence;
  final Future<TaxonomyService?> Function() _taxonomy;
  final Future<GamePosition?> Function() _position;
  final Future<Map<String, List<double>>?> Function(GamePosition) _weeklyScores;
  final DateTime Function() _now;

  /// The facts; an index that cannot open gives an empty game.
  Future<GameFacts> load() async {
    final ObservationIndex index;
    try {
      index = await _index();
    } catch (_) {
      return GameFacts.empty;
    }
    final taxonomy = await _taxonomy().catchError((_) => null);
    final verified = {
      for (final name in await gameVerifiedSpecies(
        index: index,
        presence: _presence,
      ))
        if (isBird(taxonomy, name)) name,
    };
    final listenings = await index.listenings();

    return GameFacts(
      verifiedBirds: verified,
      dawnChoruses: await _dawnChoruses(index, listenings, taxonomy),
      earlyStarts: listenings.where(_beforeSunrise).length,
      reviewed: await index.reviewedCount(),
      migrants: await _migrants(verified),
      streak: computeStreak(
        listenedDays([for (final l in listenings) (l.start, l.end)]),
        _now(),
      ),
    );
  }

  /// Listenings started before 8 h with enough verified species.
  Future<int> _dawnChoruses(
    ObservationIndex index,
    List<IndexedListening> listenings,
    TaxonomyService? taxonomy,
  ) async {
    final dawn = {
      for (final l in listenings)
        if (l.start.toLocal().hour < GameConfig.dawnChorusBeforeHour) l.id,
    };
    final candidates = await index.verifiedCandidatesIn(
      dawn,
      minScore: ReliabilityConfig.sureMinScore,
    );
    final perSession = <String, Set<String>>{};
    for (final d in candidates) {
      final species = perSession.putIfAbsent(d.sessionId, () => {});
      if (species.contains(d.scientificName) ||
          !isBird(taxonomy, d.scientificName)) {
        continue;
      }
      final level = reliabilityFor(
        score: d.confidence,
        review: d.reviewStatus,
        presence: await _presence.presenceAt(
          d.scientificName,
          latitude: d.latitude,
          longitude: d.longitude,
          time: d.start,
        ),
      );
      if (level == ReliabilityLevel.sure) species.add(d.scientificName);
    }
    return perSession.values
        .where((s) => s.length >= GameConfig.dawnChorusSpecies)
        .length;
  }

  /// Started before the local sunrise; needs the listening's place.
  bool _beforeSunrise(IndexedListening l) {
    if (l.latitude == null || l.longitude == null) return false;
    final start = l.start.toLocal();
    final sun = estimateAruSunTimes(
      date: start,
      latitude: l.latitude,
      longitude: l.longitude,
    );
    return start.isBefore(sun.sunrise);
  }

  /// Verified species that come and go with the seasons at the user's place.
  Future<Set<String>> _migrants(Set<String> verified) async {
    if (verified.isEmpty) return const {};
    try {
      final position = await _position();
      if (position == null) return const {};
      final weekly = await _weeklyScores(position);
      if (weekly == null) return const {};
      return {
        for (final name in verified)
          if (weekly[name] case final scores? when scores.isNotEmpty)
            if (scores.reduce((a, b) => a > b ? a : b) >=
                    GameConfig.migrantPresentScore &&
                scores.reduce((a, b) => a < b ? a : b) <
                    GameConfig.migrantAbsentScore)
              name,
      };
    } catch (_) {
      return const {};
    }
  }
}

final gameLoaderProvider = Provider<GameLoader>(
  (ref) => GameLoader(
    index: () => ref.read(observationIndexServiceProvider).ensureReady(),
    presence: ref.read(geoPresenceServiceProvider),
    taxonomy: () => ref.read(taxonomyServiceProvider.future),
    // Same care as the home screen: never trigger the location prompt.
    position: () async {
      if (ref.read(useGpsProvider) &&
          !await ref.read(locationServiceProvider).hasPermission()) {
        return null;
      }
      final location = await ref.read(currentLocationProvider.future);
      return location == null
          ? null
          : (latitude: location.latitude, longitude: location.longitude);
    },
    weeklyScores: (position) async {
      final model = await ref.read(geoModelProvider.future);
      return model.predictAllWeeks(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    },
  ),
);

/// The player's progress, recomputed when the index changes. Keeps its
/// previous value while reloading.
final gameProgressProvider = FutureProvider<GameProgress>((ref) async {
  ref.watch(observationIndexServiceProvider);
  return GameProgress(await ref.read(gameLoaderProvider).load());
});
