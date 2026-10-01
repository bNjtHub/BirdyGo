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

/// Mean position of [cells], or null when there are none. Several separate
/// groups would average to a point between them: for a season use
/// [dominantCenter] instead.
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

/// The densest region of [season]: the region holding the most weight (a
/// cell weighs its intensity level, so a GBIF map follows where the species is
/// seen most), and the weighted mean position of that region's cells. A
/// species seen in two far groups (Europe and West Africa) is thus placed in
/// one of them, not between them. Ties go to the first region of
/// [WorldRegion]. Null when [season] has no cell.
({WorldRegion region, GridCell center})? dominantCenter(
  SeasonPresence presence,
  Season season,
) {
  final weight = <WorldRegion, double>{};
  final lat = <WorldRegion, double>{};
  final lon = <WorldRegion, double>{};
  for (var i = 0; i < presence.cells.length; i++) {
    final level = presence.levelOf(season, i);
    if (level == 0) continue;
    final c = presence.cells[i];
    final r = regionOf(c.latitude, c.longitude);
    weight[r] = (weight[r] ?? 0) + level;
    lat[r] = (lat[r] ?? 0) + c.latitude * level;
    lon[r] = (lon[r] ?? 0) + c.longitude * level;
  }
  WorldRegion? best;
  for (final r in WorldRegion.values) {
    if (weight[r] != null && (best == null || weight[r]! > weight[best]!)) {
      best = r;
    }
  }
  if (best == null) return null;
  return (
    region: best,
    center: (
      latitude: lat[best]! / weight[best]!,
      longitude: lon[best]! / weight[best]!,
    ),
  );
}

/// Whether the species lives mostly south of the equator (weighted mean
/// latitude of every season's cells): « summer » and « winter » of the
/// chips, northern calendar seasons, would then mislead.
bool isSouthern(SeasonPresence presence) {
  var sum = 0.0, weight = 0;
  for (final season in Season.values) {
    for (var i = 0; i < presence.cells.length; i++) {
      final level = presence.levelOf(season, i);
      sum += presence.cells[i].latitude * level;
      weight += level;
    }
  }
  return weight > 0 && sum / weight < 0;
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
  const SeasonLegend(
    this.kind, {
    this.summer,
    this.winter,
    this.distanceKm,
    this.southern = false,
  });

  final LegendKind kind;

  /// The species lives mostly in the southern hemisphere: the words say the
  /// months (June to August, December to February), not summer and winter.
  final bool southern;

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
      other.southern == southern &&
      other.distanceKm == distanceKm;

  @override
  int get hashCode => Object.hash(kind, summer, winter, distanceKm, southern);

  @override
  String toString() => 'SeasonLegend($kind, $summer, $winter, $distanceKm, southern: $southern)';
}

/// The legend of [presence]: the densest region of the summer and of the
/// winter, and the distance between them.
SeasonLegend buildLegend(SeasonPresence presence) {
  final summer = dominantCenter(presence, Season.summer);
  final winter = dominantCenter(presence, Season.winter);
  if (summer == null && winter == null) {
    return SeasonLegend(
      presence.isEmpty ? LegendKind.none : LegendKind.passage,
    );
  }
  final southern = isSouthern(presence);
  if (summer == null || winter == null) {
    return SeasonLegend(
      LegendKind.seasons,
      summer: summer?.region,
      winter: winter?.region,
      southern: southern,
    );
  }
  final km = distanceKm(summer.center, winter.center);
  if (km < WorldMapConfig.migrationMinKm) {
    final allYear = Season.values.every(
      (s) => presence.flags[s]!.contains(true),
    );
    if (allYear) return const SeasonLegend(LegendKind.allYear);
    return SeasonLegend(
      LegendKind.seasons,
      summer: summer.region,
      winter: winter.region,
      southern: southern,
    );
  }
  return SeasonLegend(
    LegendKind.seasons,
    summer: summer.region,
    winter: winter.region,
    southern: southern,
    distanceKm:
        (km / WorldMapConfig.distanceRoundKm).round() *
        WorldMapConfig.distanceRoundKm.round(),
  );
}
