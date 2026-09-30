/// Providers of the species page world map (J7). Everything is computed once
/// per app run: the outline and the land grid once, the four seasons once per
/// species (Riverpod keeps the family alive, so it is the in-memory cache).
library;

import 'package:flutter/foundation.dart' show compute, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import 'gbif_ranges.dart';
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

/// Metadata of the GBIF asset, or null when it is missing or is the
/// fictitious demo asset in a release build. Overridden by tests.
final gbifMetaProvider = FutureProvider<GbifMeta?>((ref) async {
  try {
    final meta = GbifMeta.parse(
      await rootBundle.loadString(WorldMapConfig.gbifMetaAsset),
    );
    return meta.usableIn(release: kReleaseMode) ? meta : null;
  } catch (_) {
    return null;
  }
});

/// Header and species index of the GBIF asset (a few KB of names; one
/// species is decoded off the UI thread when it is asked for), or null when
/// the asset is missing, unreadable or unusable here. Overridden by tests.
final gbifIndexProvider = FutureProvider<GbifIndex?>((ref) async {
  try {
    if (await ref.watch(gbifMetaProvider.future) == null) return null;
    final data = await rootBundle.load(WorldMapConfig.gbifAsset);
    return GbifIndex.parse(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } catch (_) {
    return null;
  }
});

/// Decodes one GBIF species; overridden by tests that cannot spawn isolates.
final gbifDecodeProvider = Provider<Future<SeasonPresence> Function(
  GbifDecodeRequest,
)>((ref) => (request) => compute(decodeGbifSpecies, request));

/// What the map shows for one species: GBIF observations when the asset has
/// the species (instant, nothing computed on the phone), else the geo-model
/// estimate (the 5 degree fallback, computed in the background). Null hides
/// the block.
final worldMapDataProvider = FutureProvider.family<WorldMapData?, String>((
  ref,
  scientificName,
) async {
  final index = await ref.watch(gbifIndexProvider.future);
  if (chooseWorldMapSource(index, scientificName) == WorldMapSource.gbif) {
    try {
      final presence = await ref.read(gbifDecodeProvider)(
        GbifDecodeRequest(index!.blockOf(scientificName)!, index.grid),
      );
      return WorldMapData(presence, WorldMapSource.gbif);
    } catch (_) {
      // A damaged block: the geo-model still answers.
    }
  }
  final presence = await ref.watch(
    speciesSeasonPresenceProvider(scientificName).future,
  );
  return presence == null
      ? null
      : WorldMapData(presence, WorldMapSource.geomodel);
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
