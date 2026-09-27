/// Loads the notebook (J6e): species heard from the index, and species
/// expected here this week from the geo-model.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../game/verified_species.dart';
import '../reliability/geo_presence_service.dart';
import 'notebook_model.dart';

/// Birds only; a species unknown to the taxonomy is kept.
bool isBird(TaxonomyService? taxonomy, String scientificName) {
  final group = taxonomy?.lookup(scientificName)?.taxonGroup ?? '';
  return group.isEmpty || group == 'Aves';
}

class NotebookLoader {
  NotebookLoader({
    required Future<ObservationIndex> Function() index,
    required GeoPresenceService presence,
    required Future<List<ExpectedSpecies>?> Function() expected,
  }) : _index = index,
       _presence = presence,
       _expected = expected;

  final Future<ObservationIndex> Function() _index;
  final GeoPresenceService _presence;
  final Future<List<ExpectedSpecies>?> Function() _expected;

  /// Every species heard, with its common name from the index. An index
  /// that cannot open gives an empty list, never an error.
  Future<List<HeardSpecies>> heard() async {
    try {
      final index = await _index();
      final tallies = await index.speciesReviewTallies();
      final verified = await gameVerifiedSpecies(
        index: index,
        presence: _presence,
      );
      return [
        for (final tally in tallies)
          HeardSpecies(
            scientificName: tally.scientificName,
            commonName: tally.commonName,
            contacts: tally.contacts,
            verified: verified.contains(tally.scientificName),
            inQueue: tally.inQueue,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Species expected at the phone's place this week, or null when the
  /// place is unknown or the geo-model is missing.
  Future<List<ExpectedSpecies>?> expected() async {
    try {
      return await _expected();
    } catch (_) {
      return null;
    }
  }

  /// Keys of [scientificName]'s detections waiting in the quick review.
  Future<Set<String>> reviewKeysFor(String scientificName) async =>
      (await _index()).reviewKeysFor(scientificName);
}

final notebookLoaderProvider = Provider<NotebookLoader>(
  (ref) => NotebookLoader(
    index: () => ref.read(observationIndexServiceProvider).ensureReady(),
    presence: ref.read(geoPresenceServiceProvider),
    expected: () async {
      // Same care as the home screen: never trigger the location prompt.
      if (ref.read(useGpsProvider) &&
          !await ref.read(locationServiceProvider).hasPermission()) {
        return null;
      }
      final location = await ref.read(currentLocationProvider.future);
      if (location == null) return null;
      final species = await ref.read(exploreSpeciesProvider.future);
      return [
        for (final s in species)
          if ((s.taxonomy?.taxonGroup ?? '').isEmpty ||
              s.taxonomy!.taxonGroup == 'Aves')
            ExpectedSpecies(
              scientificName: s.scientificName,
              commonName: s.commonName,
              score: s.rawGeoScore,
              tier: s.tier,
            ),
      ];
    },
  ),
);
