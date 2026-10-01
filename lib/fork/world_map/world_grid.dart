/// The grid the geo-model is asked about (the fallback map): cell centers on
/// land only.
library;

import 'world_map_config.dart';
import 'world_regions.dart';

/// Cells of [step] degrees over the map area whose center is inside a region
/// of [regions] (land), north to south, west to east. Done once (the provider
/// caches it): the point-in-polygon test is not free.
List<GridCell> landCells(
  WorldRegions regions, {
  double step = WorldMapConfig.gridStep,
}) {
  final cells = <GridCell>[];
  final cols = ((WorldMapConfig.lonMax - WorldMapConfig.lonMin) / step).floor();
  final rows = ((WorldMapConfig.latMax - WorldMapConfig.latMin) / step).floor();
  for (var row = 0; row < rows; row++) {
    final lat = WorldMapConfig.latMax - step / 2 - row * step;
    for (var col = 0; col < cols; col++) {
      final lon = WorldMapConfig.lonMin + step / 2 + col * step;
      if (regions.regionAt(lon, lat) != null) {
        cells.add((latitude: lat, longitude: lon));
      }
    }
  }
  return cells;
}
