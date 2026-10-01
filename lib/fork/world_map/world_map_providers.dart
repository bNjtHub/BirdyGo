/// Providers of the species page world map (J7). Everything is computed once
/// per app run: the outline and the land grid once, the four seasons once per
/// species (Riverpod keeps the family alive, so it is the in-memory cache).
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
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
/// give null too: the block is then hidden.
final speciesSeasonPresenceProvider =
    FutureProvider.family<SeasonPresence?, String>((ref, scientificName) async {
      try {
        final predict = await ref.watch(worldMapPredictProvider.future);
        if (predict == null) return null;
        final cells = await ref.watch(landCellsProvider.future);
        return await computeSeasonPresence(
          scientificName: scientificName,
          predict: predict,
          cells: cells,
        );
      } catch (_) {
        return null;
      }
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
