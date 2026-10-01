/// Providers of the species page world map (J7). The regions and the land grid
/// are computed once per app run, the geo-model's four seasons once per
/// species (Riverpod keeps the family alive); GBIF counts live in a disk
/// cache.
library;

import 'dart:io' show Directory;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import 'gbif_cache.dart';
import 'gbif_ranges.dart';
import 'gbif_service.dart';
import 'range_class.dart';
import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';
import 'world_regions.dart';

/// The administrative regions and country borders of the bundled asset.
final worldRegionsProvider = FutureProvider<WorldRegions>((ref) async {
  final data = await rootBundle.load(WorldMapConfig.regionsAsset);
  return WorldRegions.fromGzip(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
});

/// GADM level-1 id to region ids (a key join; no GADM geometry).
final gadmJoinProvider = FutureProvider<GadmJoin>((ref) async {
  final data = await rootBundle.load(WorldMapConfig.gadmJoinAsset);
  return GadmJoin.fromGzip(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
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

/// HTTP client of the GBIF requests. Overridden by tests with a fake.
final gbifHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The GBIF service: nothing is asked of GBIF except through it, and it is
/// only reached with the online-map consent (see [worldMapDataProvider]).
final gbifRangeServiceProvider = Provider<GbifRangeService>((ref) {
  return GbifRangeService(
    client: ref.watch(gbifHttpClientProvider),
    cache: GbifCountsCache(
      directory:
          () async => Directory(
            p.join(
              (await getApplicationCacheDirectory()).path,
              WorldMapConfig.gbifCacheDirName,
            ),
          ),
    ),
  );
});

/// What the map shows for one species: with the online-map consent, the GBIF
/// observations (disk cache first, then GBIF) classified by region; otherwise,
/// offline, on any GBIF error, or when GBIF has too little on the species,
/// the geo-model estimate (the 5 degree fallback, computed in the
/// background). Null hides the block. Not kept alive, so a species whose
/// request failed is asked again next time its page opens.
final worldMapDataProvider = FutureProvider.autoDispose
    .family<WorldMapData?, String>((ref, scientificName) async {
      final regions = await ref.watch(worldRegionsProvider.future);
      if (ref.watch(privacyAllowMapProvider)) {
        try {
          final join = await ref.watch(gadmJoinProvider.future);
          final range = await ref
              .read(gbifRangeServiceProvider)
              .load(scientificName);
          final classes = classesOnRegions(
            classifyGadm(range.species, range.effort),
            join,
          );
          if (classes.isNotEmpty) {
            return WorldMapData(classes, WorldMapSource.gbif);
          }
        } catch (_) {
          // Offline, unknown species, GBIF error: the geo-model still answers.
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
