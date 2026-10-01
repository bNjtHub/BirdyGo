/// Providers of the species page world map (J7). The outline and the land grid
/// are computed once per app run, the geo-model's four seasons once per
/// species (Riverpod keeps the family alive); GBIF maps live in a disk cache.
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
import 'gbif_map.dart';
import 'gbif_service.dart';
import 'land_outline.dart';
import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';

/// The land outline of the bundled Natural Earth asset.
final landOutlineProvider = FutureProvider<LandOutline>((ref) async {
  final data = await rootBundle.load(WorldMapConfig.landAsset);
  return LandOutline.parse(data);
});

/// Grid cells on land (the point-in-polygon test runs once).
final landCellsProvider = FutureProvider<List<GridCell>>((ref) async {
  final outline = await ref.watch(landOutlineProvider.future);
  return landCells(outline);
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

/// The GBIF map service: nothing is asked of GBIF except through it, and it
/// is only reached with the online-map consent (see [worldMapDataProvider]).
final gbifMapServiceProvider = Provider<GbifMapService>((ref) {
  return GbifMapService(
    client: ref.watch(gbifHttpClientProvider),
    cache: GbifMapCache(
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
/// observations (disk cache first, then GBIF); otherwise, offline, or on any
/// GBIF error, the geo-model estimate (the 5 degree fallback, computed in the
/// background). Null hides the block. Not kept alive, so a species whose
/// request failed is asked again next time its page opens.
final worldMapDataProvider = FutureProvider.autoDispose
    .family<WorldMapData?, String>((ref, scientificName) async {
      if (ref.watch(privacyAllowMapProvider)) {
        final service = ref.read(gbifMapServiceProvider);
        try {
          final map = await service.load(scientificName);
          return WorldMapData(
            map.toPresence(service.grid),
            WorldMapSource.gbif,
          );
        } catch (_) {
          // Offline, unknown species, GBIF error: the geo-model still answers.
        }
      }
      final presence = await ref.watch(
        speciesSeasonPresenceProvider(scientificName).future,
      );
      return presence == null
          ? null
          : WorldMapData(presence, WorldMapSource.geomodel);
    });

/// Whether the species page has a world map block to show: yes while it
/// loads (the skeleton), no once it is known there is nothing to draw, so
/// the page adds neither the block nor its spacing.
final worldMapVisibleProvider = Provider.autoDispose.family<bool, String>((
  ref,
  scientificName,
) {
  final data = ref.watch(worldMapDataProvider(scientificName));
  final outline = ref.watch(landOutlineProvider);
  if (data.hasError || outline.hasError) return false;
  if (data.isLoading || outline.isLoading) return true;
  return data.value != null && outline.value != null;
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
