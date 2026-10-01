/// Providers of the species page world map (J7). The regions, the bundled
/// GBIF ranges and the land grid are computed once per app run, the
/// geo-model's four seasons once per species (Riverpod keeps the family
/// alive).
library;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import 'range_class.dart';
import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';
import 'world_map_data.dart';
import 'world_ranges.dart';
import 'world_regions.dart';

/// The administrative regions and country borders of the bundled asset.
final worldRegionsProvider = FutureProvider<WorldRegions>((ref) async {
  final data = await rootBundle.load(WorldMapConfig.regionsAsset);
  return WorldRegions.fromGzip(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
});

WorldRanges? _parseRanges(Uint8List gz) => WorldRanges.fromGzip(gz);

/// The bundled GBIF ranges, parsed once in a background isolate; null when the
/// asset is missing or unreadable (the geo-model then answers for every
/// species). Overridden by tests with a fake.
final worldRangesProvider = FutureProvider<WorldRanges?>((ref) async {
  try {
    final data = await rootBundle.load(WorldMapConfig.rangesAsset);
    return await compute(
      _parseRanges,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } catch (_) {
    return null;
  }
});

/// Grid cells on land (the point-in-polygon test runs once).
final landCellsProvider = FutureProvider<List<GridCell>>((ref) async {
  final regions = await ref.watch(worldRegionsProvider.future);
  return landCells(regions);
});

/// The geo-model's `predict`, or null when the model is not available.
/// Overridden by tests with a fake.
final worldMapPredictProvider = FutureProvider<GeoPredict?>((ref) async {
  try {
    final model = await ref.watch(geoModelProvider.future);
    return model.isReady ? model.predict : null;
  } catch (_) {
    return null;
  }
});

/// The four seasons of one species, or null without a geo-model. Failures
/// give null too: the block is then hidden. While computing, the provider
/// lives as long as someone watches it: leaving the page cancels the work
/// (checked between cells). A finished result is kept for the app run.
final speciesSeasonPresenceProvider = FutureProvider.autoDispose
    .family<SeasonPresence?, String>((ref, scientificName) async {
      var cancelled = false;
      ref.onDispose(() => cancelled = true);
      try {
        final predict = await ref.watch(worldMapPredictProvider.future);
        if (predict == null) return null;
        final cells = await ref.watch(landCellsProvider.future);
        final presence = await computeSeasonPresence(
          scientificName: scientificName,
          predict: predict,
          cells: cells,
          isCancelled: () => cancelled,
        );
        ref.keepAlive();
        return presence;
      } catch (_) {
        return null;
      }
    });

/// What the map shows for one species: the bundled GBIF range when the
/// species is in it (instant, offline), otherwise the geo-model estimate (the
/// 5 degree fallback, computed in the background). Null hides the block.
final worldMapDataProvider = FutureProvider.autoDispose
    .family<WorldMapData?, String>((ref, scientificName) async {
      final regions = await ref.watch(worldRegionsProvider.future);
      final ranges = await ref.watch(worldRangesProvider.future);
      final entries = ranges?.entriesOf(scientificName);
      if (ranges != null && entries != null) {
        final classes = <String, RangeClass>{
          for (final e in entries.entries)
            if (e.key < regions.regions.length)
              regions.regions[e.key].id: e.value,
        };
        if (classes.isNotEmpty) {
          return WorldMapData(
            classes,
            WorldMapSource.gbif,
            generation: ranges.generation,
          );
        }
      }
      final presence = await ref.watch(
        speciesSeasonPresenceProvider(scientificName).future,
      );
      return presence == null
          ? null
          : WorldMapData(
            classesFromPresence(presence, regions),
            WorldMapSource.geomodel,
          );
    });

/// Whether the species page has a world map block to show: yes while it
/// loads (the skeleton), no once it is known there is nothing to draw, so
/// the page adds neither the block nor its spacing.
final worldMapVisibleProvider = Provider.autoDispose.family<bool, String>((
  ref,
  scientificName,
) {
  final data = ref.watch(worldMapDataProvider(scientificName));
  final regions = ref.watch(worldRegionsProvider);
  if (data.hasError || regions.hasError) return false;
  if (data.isLoading || regions.isLoading) return true;
  return data.value != null && regions.value != null;
});

/// Where the phone is, for the map's dot. Never asks for the location
/// permission (same care as the species page's year chart); null when unknown.
final worldMapUserPositionProvider = FutureProvider<GridCell?>((ref) async {
  try {
    if (ref.read(useGpsProvider) &&
        !await ref.read(locationServiceProvider).hasPermission()) {
      return null;
    }
    final location = await ref.read(currentLocationProvider.future);
    if (location == null) return null;
    return (latitude: location.latitude, longitude: location.longitude);
  } catch (_) {
    return null;
  }
});
