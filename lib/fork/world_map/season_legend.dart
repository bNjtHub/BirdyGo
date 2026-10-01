/// What the legend under the world map says (J7): where the species spends
/// the summer and the winter, and roughly how far apart. Pure logic; the
/// words come from `world_map_text.dart`.
library;

import 'dart:math' as math;

import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';

/// Coarse regions of the default view, for the legend's wording only.
enum WorldRegion {
  northernEurope,
  westernEurope,
  centralEasternEurope,
  mediterranean,
  northAfrica,
  westAfrica,
  centralAfrica,
  eastAfrica,
  southernAfrica,
  middleEast,
  centralAsia,

  /// A centre that falls in none of the boxes.
  other,
}

/// Bounding box of a [WorldRegion], in degrees.
typedef RegionBox =
    ({
      WorldRegion region,
      double latMin,
      double latMax,
      double lonMin,
      double lonMax,
    });

/// Regions, first match wins. Deliberately rough: a region names where the
/// centre of a season's cells falls, not where the birds are.
const List<RegionBox> kRegionBoxes = [
  (
    region: WorldRegion.northernEurope,
    latMin: 55,
    latMax: 90,
    lonMin: -30,
    lonMax: 45,
  ),
  (
    region: WorldRegion.centralAsia,
    latMin: 42,
    latMax: 90,
    lonMin: 45,
    lonMax: 180,
  ),
  (
    region: WorldRegion.westernEurope,
    latMin: 42,
    latMax: 55,
    lonMin: -30,
    lonMax: 10,
  ),
  (
    region: WorldRegion.centralEasternEurope,
    latMin: 42,
    latMax: 55,
    lonMin: 10,
    lonMax: 45,
  ),
  (
    region: WorldRegion.mediterranean,
    latMin: 30,
    latMax: 42,
    lonMin: -30,
    lonMax: 36,
  ),
  (
    region: WorldRegion.middleEast,
    latMin: 12,
    latMax: 42,
    lonMin: 36,
    lonMax: 90,
  ),
  (
    region: WorldRegion.northAfrica,
    latMin: 15,
    latMax: 30,
    lonMin: -30,
    lonMax: 36,
  ),
  (
    region: WorldRegion.westAfrica,
    latMin: 0,
    latMax: 15,
    lonMin: -30,
    lonMax: 10,
  ),
  (
    region: WorldRegion.centralAfrica,
    latMin: -12,
    latMax: 15,
    lonMin: 10,
    lonMax: 30,
  ),
  (
    region: WorldRegion.eastAfrica,
    latMin: -12,
    latMax: 15,
    lonMin: 30,
    lonMax: 52,
  ),
  (
    region: WorldRegion.southernAfrica,
    latMin: -90,
    latMax: -12,
    lonMin: 5,
    lonMax: 60,
  ),
];

/// Region containing ([latitude], [longitude]).
WorldRegion regionOf(
  double latitude,
  double longitude, {
  List<RegionBox> boxes = kRegionBoxes,
}) {
  for (final b in boxes) {
    if (latitude >= b.latMin &&
        latitude < b.latMax &&
        longitude >= b.lonMin &&
        longitude < b.lonMax) {
      return b.region;
    }
  }
  return WorldRegion.other;
}

/// Mean position of [cells], or null when there are none.
GridCell? centerOf(List<GridCell> cells) {
  if (cells.isEmpty) return null;
  var lat = 0.0, lon = 0.0;
  for (final c in cells) {
    lat += c.latitude;
    lon += c.longitude;
  }
  return (latitude: lat / cells.length, longitude: lon / cells.length);
}

const double _earthRadiusKm = 6371;

/// Great-circle distance between two points, in km.
double distanceKm(GridCell a, GridCell b) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusKm * math.asin(math.sqrt(h.toDouble()));
}

enum LegendKind {
  /// Nowhere on the map, in any season.
  none,

  /// Only in spring and/or autumn.
  passage,

  /// The same place all year.
  allYear,

  /// Summer and winter, possibly in different places.
  seasons,
}

class SeasonLegend {
  const SeasonLegend(this.kind, {this.summer, this.winter, this.distanceKm});

  final LegendKind kind;

  /// Region of the summer / winter cells; null when none of that season is on
  /// the map.
  final WorldRegion? summer;
  final WorldRegion? winter;

  /// Rounded distance between the summer and the winter centres, only for a
  /// real migration.
  final int? distanceKm;

  @override
  bool operator ==(Object other) =>
      other is SeasonLegend &&
      other.kind == kind &&
      other.summer == summer &&
      other.winter == winter &&
      other.distanceKm == distanceKm;

  @override
  int get hashCode => Object.hash(kind, summer, winter, distanceKm);

  @override
  String toString() => 'SeasonLegend($kind, $summer, $winter, $distanceKm)';
}

/// The legend of [presence].
SeasonLegend buildLegend(SeasonPresence presence) {
  final summerCells = presence.cellsOf(Season.summer);
  final winterCells = presence.cellsOf(Season.winter);
  final summer = centerOf(summerCells);
  final winter = centerOf(winterCells);
  if (summer == null && winter == null) {
    return SeasonLegend(
      presence.isEmpty ? LegendKind.none : LegendKind.passage,
    );
  }
  WorldRegion? region(GridCell? c) =>
      c == null ? null : regionOf(c.latitude, c.longitude);
  if (summer == null || winter == null) {
    return SeasonLegend(
      LegendKind.seasons,
      summer: region(summer),
      winter: region(winter),
    );
  }
  final km = distanceKm(summer, winter);
  if (km < WorldMapConfig.migrationMinKm) {
    final allYear = Season.values.every(
      (s) => presence.flags[s]!.contains(true),
    );
    if (allYear) return const SeasonLegend(LegendKind.allYear);
    return SeasonLegend(
      LegendKind.seasons,
      summer: region(summer),
      winter: region(winter),
    );
  }
  return SeasonLegend(
    LegendKind.seasons,
    summer: region(summer),
    winter: region(winter),
    distanceKm:
        (km / WorldMapConfig.distanceRoundKm).round() *
        WorldMapConfig.distanceRoundKm.round(),
  );
}
