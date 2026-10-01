/// Loads the species page's data: the user's contacts from the observation
/// index, and the geo-model's year at the phone's place (J6c).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/inference/geo_model.dart';
import '../../shared/providers/settings_providers.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../reliability/reliability_config.dart';
import 'species_page_config.dart';
import 'species_page_model.dart';

class SpeciesPageLoader {
  SpeciesPageLoader({
    required Future<ObservationIndex> Function() index,
    required Future<Map<String, List<double>>?> Function() yearScores,
    Future<Set<String>> Function()? audioLabels,
  }) : _index = index,
       _yearScores = yearScores,
       _audioLabels = audioLabels;

  final Future<ObservationIndex> Function() _index;
  final Future<Map<String, List<double>>?> Function() _yearScores;

  /// Audio-detectable species: the population of the rarity scale.
  final Future<Set<String>> Function()? _audioLabels;

  /// The user's contacts with [scientificName]. An index that cannot open
  /// gives an empty record, never an error.
  Future<SpeciesRecord> record(String scientificName) async {
    final ObservationIndex index;
    try {
      index = await _index();
    } catch (_) {
      return SpeciesRecord.empty;
    }
    final tally = await index.speciesTally(scientificName);
    if (tally == null) return SpeciesRecord.empty;

    // Independent index queries, queued together.
    final (precision, verified, favorites, clips, points, hours) = await (
      index.speciesPrecision(scientificName),
      index.verifiedSpecies(minScore: ReliabilityConfig.sureMinScore),
      index.favoriteKeys(),
      index.clipsForSpecies(scientificName),
      index.mapPoints(scientificName: scientificName),
      index.activityByHour(scientificName: scientificName),
    ).wait;
    final shown = pageClips(
      clips,
      favorites,
      limit: SpeciesPageConfig.clipsShown,
    );
    return SpeciesRecord(
      tally: tally,
      confirmed: precision.confirmed,
      reviewed: precision.reviewed,
      verified: verified.contains(scientificName),
      clips: shown,
      clipCount: clips.length,
      favorites: {
        for (final c in shown)
          if (favorites.contains(c.key)) c.key,
      },
      hours: hours,
      spots: distinctSpots(
        points,
        limit: SpeciesPageConfig.mapSpots,
        decimals: SpeciesPageConfig.spotDecimals,
      ),
    );
  }

  /// The geo-model's year for [scientificName] where the phone is. Null
  /// without a position or a model, or for a species the model ignores.
  Future<YearPresence?> presence(String scientificName) async {
    try {
      final weeks = (await _yearScores())?[scientificName];
      return weeks == null ? null : YearPresence.fromWeeks(weeks);
    } catch (_) {
      return null;
    }
  }

  /// Whether the geo-model finds [scientificName] unexpected where the
  /// phone is, during the week of [now]: same rule as the reliability
  /// levels (`presenceFromWeekScores`), so the page explains the
  /// « Rare ici · à confirmer » badge (J3b). False when unknown.
  Future<bool> unexpectedNow(
    String scientificName, {
    required DateTime now,
  }) async {
    try {
      final all = await _yearScores();
      final labels = await _audioLabels?.call();
      if (all == null || labels == null) return false;
      final week = GeoModel.dateTimeToWeek(now.toLocal());
      final map = presenceFromWeekScores({
        for (final MapEntry(:key, :value) in all.entries)
          if (value.length >= week) key: value[week - 1],
      }, audioLabels: labels);
      if (map.isEmpty) return false;
      return (map[scientificName] ?? kAbsentHere).unexpected;
    } catch (_) {
      return false;
    }
  }

  /// Whether [scientificName] is « peu commun » where the phone is, during
  /// the week of [now] (`isUncommonHere`, the notebook's half-disc rule).
  /// False when unknown.
  Future<bool> uncommonNow(
    String scientificName, {
    required DateTime now,
  }) async {
    try {
      final all = await _yearScores();
      final labels = await _audioLabels?.call();
      if (all == null || labels == null) return false;
      final week = GeoModel.dateTimeToWeek(now.toLocal());
      return isUncommonHere(
        {
          for (final MapEntry(:key, :value) in all.entries)
            if (value.length >= week) key: value[week - 1],
        },
        audioLabels: labels,
        scientificName: scientificName,
      );
    } catch (_) {
      return false;
    }
  }

  /// Newest session with a confirmed, positioned contact of
  /// [scientificName]: what « Envoyer à Faune-France » sends from the
  /// species page (J6g-e). Null when there is none, or without the index.
  Future<String?> lastConfirmedSession(String scientificName) async {
    try {
      final points = await (await _index()).mapPoints(
        confirmedOnly: true,
        scientificName: scientificName,
      );
      return points.isEmpty ? null : points.first.sessionId;
    } catch (_) {
      return null;
    }
  }

  /// Marks or unmarks a recording as favorite (same list as the sound
  /// library).
  Future<void> setFavorite(String key, {required bool favorite}) async =>
      (await _index()).setFavorite(key, favorite: favorite);
}

/// 48 weekly geo-model scores of every species at the phone's place,
/// computed once per app run. Null without a position; never asks for the
/// location permission (same care as the home screen).
final speciesYearScoresProvider = FutureProvider<Map<String, List<double>>?>((
  ref,
) async {
  if (ref.read(useGpsProvider) &&
      !await ref.read(locationServiceProvider).hasPermission()) {
    return null;
  }
  final location = await ref.read(currentLocationProvider.future);
  if (location == null) return null;
  final model = await ref.read(geoModelProvider.future);
  return model.predictAllWeeks(
    latitude: location.latitude,
    longitude: location.longitude,
  );
});

final speciesPageLoaderProvider = Provider<SpeciesPageLoader>(
  (ref) => SpeciesPageLoader(
    index: () => ref.read(observationIndexServiceProvider).ensureReady(),
    yearScores: () => ref.read(speciesYearScoresProvider.future),
    audioLabels: () => ref.read(audioLabelsSetProvider.future),
  ),
);
