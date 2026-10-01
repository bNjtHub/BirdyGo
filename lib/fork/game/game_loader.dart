/// Loads the game's facts (J6e) from the observation index and the
/// geo-model. Recomputed when the index changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/aru/aru_schedule.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/live/live_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../notebook/notebook_loader.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';
import 'challenges.dart';
import 'fine_ear.dart';
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
    DateTime? Function(DateTime now)? challengeStartedAt,
    int Function()? fineEarCorrect,
    String? Function()? activeSessionId,
    DateTime Function()? now,
  }) : _index = index,
       _activeSessionId = activeSessionId ?? (() => null),
       _fineEarCorrect = fineEarCorrect ?? (() => 0),
       _challengeStartedAt = challengeStartedAt ?? ((_) => null),
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
  final DateTime? Function(DateTime now) _challengeStartedAt;
  final int Function() _fineEarCorrect;
  final String? Function() _activeSessionId;
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
    final now = _now();
    // Only the running listening counts up to now; an orphan without end
    // counts up to its last detection.
    final activeId = _activeSessionId();
    final listened = listenedDays([
      for (final l in listenings)
        (
          l.start,
          listeningEnd(
            end: l.end,
            lastSeen: l.lastSeen,
            active: l.id == activeId,
            now: now,
          ),
        ),
    ]);
    final dawnIds = {
      for (final l in listenings)
        if (_isDawn(l.start)) l.id,
    };
    final dawnSpecies = await _sureSpeciesBySession(index, dawnIds, taxonomy);

    return GameFacts(
      verifiedBirds: verified,
      dawnChoruses:
          dawnSpecies.values
              .where((s) => s.length >= GameConfig.dawnChorusSpecies)
              .length,
      earlyStarts: listenings.where(_beforeSunrise).length,
      reviewed: await index.reviewedCount(),
      migrants: await _migrants(verified),
      streak: computeStreak(listened, now),
      challenge: await _challenge(index, listenings, listened, taxonomy, now),
      fineEarCorrect: _fineEarCorrect(),
    );
  }

  bool _isDawn(DateTime start) =>
      start.toLocal().hour < GameConfig.dawnChorusBeforeHour;

  /// Species « Sûr » or confirmed in each of the listenings [ids], birds
  /// only; with [since], only detections from then on.
  Future<Map<String, Set<String>>> _sureSpeciesBySession(
    ObservationIndex index,
    Set<String> ids,
    TaxonomyService? taxonomy, {
    DateTime? since,
  }) async {
    final candidates = await index.verifiedCandidatesIn(
      ids,
      minScore: ReliabilityConfig.sureMinScore,
    );
    final perSession = <String, Set<String>>{};
    for (final d in candidates) {
      if (since != null && d.start.isBefore(since)) continue;
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
    return perSession;
  }

  /// This week's challenge; nothing counts before it was started.
  Future<WeeklyChallenge> _challenge(
    ObservationIndex index,
    List<IndexedListening> listenings,
    Set<DateTime> listened,
    TaxonomyService? taxonomy,
    DateTime now,
  ) async {
    final (kind, target) = challengeOfWeek(now);
    final startedAt = _challengeStartedAt(now);
    var value = 0;
    if (startedAt != null) {
      final startDay = DateTime(startedAt.year, startedAt.month, startedAt.day);
      final since = [
        for (final l in listenings)
          if (!l.start.isBefore(startedAt)) l,
      ];
      value = switch (kind) {
        ChallengeKind.dawnMornings =>
          {
            for (final l in since)
              if (_isDawn(l.start))
                DateTime(
                  l.start.toLocal().year,
                  l.start.toLocal().month,
                  l.start.toLocal().day,
                ),
          }.length,
        ChallengeKind.listeningDays =>
          listened.where((d) => !d.isBefore(startDay)).length,
        ChallengeKind.weekSpecies =>
          {
            for (final species
                in (await _sureSpeciesBySession(
                  index,
                  {
                    for (final l in listenings)
                      if (l.end == null || l.end!.isAfter(startedAt)) l.id,
                  },
                  taxonomy,
                  since: startedAt,
                )).values)
              ...species,
          }.length,
      };
    }
    return WeeklyChallenge(
      kind: kind,
      target: target,
      startedAt: startedAt,
      value: value,
      ends: weekEnd(now),
    );
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
    challengeStartedAt: ref.read(challengeStoreProvider).startedAt,
    fineEarCorrect: ref.read(fineEarStoreProvider).correct,
    activeSessionId: () {
      final session = ref.read(currentSessionProvider);
      return session != null && session.isActive ? session.id : null;
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
