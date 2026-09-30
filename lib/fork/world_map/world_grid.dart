/// The grid the geo-model is asked about: cell centers on land only.
library;

import 'land_outline.dart';
import 'world_map_config.dart';

/// Center of a grid cell, in degrees.
typedef GridCell = ({double latitude, double longitude});

/// Cells of [step] degrees over the default view whose center is on land,
/// north to south, west to east. Done once (the provider caches it): the
/// point-in-polygon test is not free.
List<GridCell> landCells(
  LandOutline outline, {
  double step = WorldMapConfig.gridStep,
}) {
  final cells = <GridCell>[];
  final cols = ((WorldMapConfig.lonMax - WorldMapConfig.lonMin) / step).floor();
  final rows = ((WorldMapConfig.latMax - WorldMapConfig.latMin) / step).floor();
  for (var row = 0; row < rows; row++) {
    final lat = WorldMapConfig.latMax - step / 2 - row * step;
    for (var col = 0; col < cols; col++) {
      final lon = WorldMapConfig.lonMin + step / 2 + col * step;
      if (outline.contains(lon, lat)) {
        cells.add((latitude: lat, longitude: lon));
      }
    }
  }
  return cells;
}
