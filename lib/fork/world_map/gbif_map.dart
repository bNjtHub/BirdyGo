/// GBIF observation maps of one species (J7 world map), asked on demand.
///
/// GBIF draws occurrence maps as PNG tiles, filtered by taxon, months and
/// years. We ask the few tiles that cover the map area, once per season, and
/// read the squares back into cells on the same grid as the geo-model
/// fallback (`SeasonPresence`), so the painter, the legend and the colors are
/// shared. Pure Dart apart from the PNG decoder, which is injected.
library;

import 'dart:typed_data';

import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';

/// Where the map of a species comes from.
enum WorldMapSource { gbif, geomodel }

/// The range of one species, ready to draw, and where it comes from.
class WorldMapData {
  const WorldMapData(this.presence, this.source);

  final SeasonPresence presence;
  final WorldMapSource source;
}

/// A decoded tile: straight (not premultiplied) RGBA, row-major.
class GbifRaster {
  const GbifRaster(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;
}

/// Decodes a PNG into a [GbifRaster]. Injected, so tests need no engine.
typedef GbifRasterDecoder = Future<GbifRaster> Function(Uint8List png);

/// One tile of the XYZ-like scheme of EPSG:4326: [x] counts from -180
/// degrees eastwards, [y] from 90 degrees southwards.
typedef GbifTile = ({int x, int y});

/// Cells of the map area, at the resolution of the GBIF squares.
class GbifGrid {
  const GbifGrid._({
    required this.step,
    required this.col0,
    required this.row0,
    required this.cols,
    required this.rows,
  });

  /// The grid of the configured zone, zoom and square size.
  factory GbifGrid.forZone() {
    final step =
        180 /
        (1 << WorldMapConfig.gbifZoom) /
        WorldMapConfig.gbifTilePx *
        WorldMapConfig.gbifBinPx;
    final col0 = ((WorldMapConfig.lonMin + 180) / step).floor();
    final col1 = ((WorldMapConfig.lonMax + 180) / step).floor();
    final row0 = ((90 - WorldMapConfig.latMax) / step).floor();
    final row1 = ((90 - WorldMapConfig.latMin) / step).floor();
    return GbifGrid._(
      step: step,
      col0: col0,
      row0: row0,
      cols: col1 - col0 + 1,
      rows: row1 - row0 + 1,
    );
  }

  /// Side of a cell, in degrees.
  final double step;

  /// Global index of the first column (from -180 degrees) and row (from 90).
  final int col0;
  final int row0;
  final int cols;
  final int rows;

  int get cellCount => cols * rows;

  static int get _binsPerTile =>
      WorldMapConfig.gbifTilePx ~/ WorldMapConfig.gbifBinPx;

  /// Center of [cell] (row-major, north row first).
  GridCell centerOf(int cell) {
    final row = row0 + cell ~/ cols;
    final col = col0 + cell % cols;
    return (
      latitude: 90 - (row + 0.5) * step,
      longitude: -180 + (col + 0.5) * step,
    );
  }

  /// The tiles that cover the grid.
  List<GbifTile> get tiles => [
    for (var y = row0 ~/ _binsPerTile; y <= (row0 + rows - 1) ~/ _binsPerTile; y++)
      for (var x = col0 ~/ _binsPerTile; x <= (col0 + cols - 1) ~/ _binsPerTile; x++)
        (x: x, y: y),
  ];

  /// Reads [raster], the tile [tile], into [levels] (one byte per cell, 0 for
  /// none, keeping the higher level where cells overlap tiles' edges).
  void readTile(GbifTile tile, GbifRaster raster, Uint8List levels) {
    final bins = _binsPerTile;
    final binPx = WorldMapConfig.gbifBinPx;
    final needed = (WorldMapConfig.gbifCellCoverage * binPx * binPx).ceil();
    for (var r = 0; r < rows; r++) {
      final row = row0 + r;
      if (row ~/ bins != tile.y) continue;
      for (var c = 0; c < cols; c++) {
        final col = col0 + c;
        if (col ~/ bins != tile.x) continue;
        final px = (col % bins) * binPx;
        final py = (row % bins) * binPx;
        var seen = 0;
        var level = 0;
        for (var dy = 0; dy < binPx; dy++) {
          for (var dx = 0; dx < binPx; dx++) {
            final o = ((py + dy) * raster.width + px + dx) * 4;
            if (o + 3 >= raster.rgba.length) continue;
            final l = pixelLevel(raster.rgba[o + 1], raster.rgba[o + 3]);
            if (l == 0) continue;
            seen++;
            if (l > level) level = l;
          }
        }
        if (seen >= needed && level > levels[r * cols + c]) {
          levels[r * cols + c] = level;
        }
      }
    }
  }

  /// Intensity of a pixel from its [green] channel and [alpha]: 0 when not
  /// observed, else 1 to `WorldMapConfig.gbifLevels`.
  static int pixelLevel(int green, int alpha) {
    if (alpha < WorldMapConfig.gbifMinAlpha) return 0;
    final floors = WorldMapConfig.gbifGreenLevelFloors;
    for (var i = 0; i < floors.length; i++) {
      if (green >= floors[i]) return i + 1;
    }
    return floors.length + 1;
  }
}

/// The four seasons of one species on the [GbifGrid]: what is cached.
class GbifSpeciesMap {
  GbifSpeciesMap({
    required this.taxonKey,
    required this.fetchedAt,
    required this.cols,
    required this.rows,
    required this.levels,
  });

  /// GBIF taxon key of the species.
  final int taxonKey;
  final DateTime fetchedAt;
  final int cols;
  final int rows;

  /// One list per season, in the order of `Season.values`, one level per cell.
  final List<Uint8List> levels;

  /// The drawing model: only the cells observed in some season.
  SeasonPresence toPresence(GbifGrid grid) {
    final cells = <GridCell>[];
    final flags = {for (final s in Season.values) s: <bool>[]};
    final perSeason = {for (final s in Season.values) s: <int>[]};
    for (var cell = 0; cell < grid.cellCount; cell++) {
      if (levels.every((l) => l[cell] == 0)) continue;
      cells.add(grid.centerOf(cell));
      for (var s = 0; s < levels.length; s++) {
        final season = Season.values[s];
        flags[season]!.add(levels[s][cell] != 0);
        perSeason[season]!.add(levels[s][cell]);
      }
    }
    return SeasonPresence(cells, flags, step: grid.step, levels: perSeason);
  }
}

/// URL of one tile of the ad hoc occurrence map: the filters (licenses,
/// human observations, years, the months of [season]) and the style.
Uri gbifTileUri({
  required int taxonKey,
  required Season season,
  required GbifTile tile,
  required int lastYear,
}) => Uri.https(
  WorldMapConfig.gbifApiHost,
  '${WorldMapConfig.gbifMapPath}/${WorldMapConfig.gbifZoom}/${tile.x}/${tile.y}@1x.png',
  {
    'srs': WorldMapConfig.gbifSrs,
    'taxonKey': '$taxonKey',
    'license': WorldMapConfig.gbifLicenses,
    'basisOfRecord': WorldMapConfig.gbifBasisOfRecord,
    'year': '${WorldMapConfig.gbifFirstYear},$lastYear',
    'month': [for (final m in WorldMapConfig.gbifSeasonMonths[season]!) '$m'],
    'style': WorldMapConfig.gbifStyle,
    'bin': 'square',
    'squareSize': '${WorldMapConfig.gbifSquareSize}',
  },
);

/// URL of the species match for [scientificName].
Uri gbifMatchUri(String scientificName) => Uri.https(
  WorldMapConfig.gbifApiHost,
  WorldMapConfig.gbifMatchPath,
  {
    'scientificName': scientificName,
    'class': WorldMapConfig.gbifMatchClass,
  },
);
