/// What the legend under the world map says (J7): the coarse region where
/// the species nests, winters, stays all year or passes through, and roughly
/// how far the nesting and wintering areas are. Pure logic; the words come
/// from `world_map_text.dart`.
library;

import 'dart:math' as math;

import 'range_class.dart';
import 'world_map_config.dart';
import 'world_regions.dart';

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


/// The legend of a range: for each class present, the coarse region holding
/// most of its area, and the distance between nesting and wintering.
class RangeLegend {
  const RangeLegend(this.regions, {this.distanceKm});

  final Map<RangeClass, WorldRegion> regions;

  /// Rounded distance between the nesting and the wintering centres, only
  /// for a real migration.
  final int? distanceKm;

  bool get isEmpty => regions.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is RangeLegend &&
      other.distanceKm == distanceKm &&
      other.regions.length == regions.length &&
      regions.entries.every((e) => other.regions[e.key] == e.value);

  @override
  int get hashCode => Object.hash(distanceKm, Object.hashAll(regions.keys));

  @override
  String toString() => 'RangeLegend($regions, $distanceKm)';
}

/// The legend of [classes] (region id to class) on [regions]. A region counts
/// for its area, so a small region does not name a whole class; ties go to
/// the first [WorldRegion].
RangeLegend buildRangeLegend(
  WorldRegions regions,
  Map<String, RangeClass> classes,
) {
  final weight = {
    for (final c in RangeClass.values) c: <WorldRegion, double>{},
  };
  final lat = {for (final c in RangeClass.values) c: <WorldRegion, double>{}};
  final lon = {for (final c in RangeClass.values) c: <WorldRegion, double>{}};
  for (final e in classes.entries) {
    final region = regions.byId(e.key);
    if (region == null) continue;
    final at = region.centroid;
    final coarse = regionOf(at.latitude, at.longitude);
    final w = region.area;
    weight[e.value]![coarse] = (weight[e.value]![coarse] ?? 0) + w;
    lat[e.value]![coarse] = (lat[e.value]![coarse] ?? 0) + at.latitude * w;
    lon[e.value]![coarse] = (lon[e.value]![coarse] ?? 0) + at.longitude * w;
  }
  final dominant = <RangeClass, WorldRegion>{};
  final centers = <RangeClass, GridCell>{};
  final total = weight.values.fold<double>(
    0,
    (sum, m) => sum + m.values.fold<double>(0, (a, b) => a + b),
  );
  for (final c in RangeClass.values) {
    // A class of a few scattered regions is noise, not worth a sentence.
    final area = weight[c]!.values.fold<double>(0, (a, b) => a + b);
    if (area < WorldMapConfig.legendMinShare * total) continue;
    WorldRegion? best;
    for (final r in WorldRegion.values) {
      final w = weight[c]![r];
      if (w != null && (best == null || w > weight[c]![best]!)) best = r;
    }
    if (best == null) continue;
    dominant[c] = best;
    final w = weight[c]![best]!;
    centers[c] = (
      latitude: lat[c]![best]! / w,
      longitude: lon[c]![best]! / w,
    );
  }
  final nest = centers[RangeClass.breeding];
  final winter = centers[RangeClass.wintering];
  int? km;
  if (nest != null && winter != null) {
    final d = distanceKm(nest, winter);
    if (d >= WorldMapConfig.migrationMinKm) {
      km =
          (d / WorldMapConfig.distanceRoundKm).round() *
          WorldMapConfig.distanceRoundKm.round();
    }
  }
  return RangeLegend(dominant, distanceKm: km);
}
