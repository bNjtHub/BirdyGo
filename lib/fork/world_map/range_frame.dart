/// Framing of the world map (J7): the area drawn, from the species' range.
library;

import 'dart:math' as math;

import 'range_class.dart';
import 'world_map_config.dart';
import 'world_regions.dart';

/// The area of the map to draw, in degrees.
typedef MapFrame = ({double lon0, double lat0, double lon1, double lat1});

/// The whole map area.
const MapFrame kWorldFrame = (
  lon0: WorldMapConfig.lonMin,
  lat0: WorldMapConfig.latMin,
  lon1: WorldMapConfig.lonMax,
  lat1: WorldMapConfig.latMax,
);

/// Horizontal scale of a map centred on [latitude]: degrees of longitude
/// shrink with the cosine of the latitude (up to
/// `WorldMapConfig.maxProjectionLatitude`).
double longitudeScale(double latitude) => math.cos(
  math.min(latitude.abs(), WorldMapConfig.maxProjectionLatitude) *
      math.pi /
      180,
);

/// Width over height of [frame] as drawn.
double frameAspect(MapFrame frame) =>
    (frame.lon1 - frame.lon0) *
    longitudeScale((frame.lat0 + frame.lat1) / 2) /
    (frame.lat1 - frame.lat0);

/// The frame of a range: the box of its regions (those far from every other
/// one left out), plus a margin, at least the minimum span, with a width over
/// height kept between the configured bounds, inside the map area. The whole
/// area when [classes] is empty.
MapFrame frameOf(WorldRegions regions, Map<String, RangeClass> classes) {
  final used = [
    for (final id in classes.keys)
      if (regions.byId(id) case final r? when r.rings.isNotEmpty) r,
  ];
  if (used.isEmpty) return kWorldFrame;
  var kept = used;
  if (used.length >= 3) {
    final limit = WorldMapConfig.frameIsolatedDeg;
    kept = [
      for (final a in used)
        if (used.any(
          (b) =>
              !identical(a, b) &&
              math.sqrt(
                    math.pow(a.centroid.latitude - b.centroid.latitude, 2) +
                        math.pow(
                          a.centroid.longitude - b.centroid.longitude,
                          2,
                        ),
                  ) <=
                  limit,
        ))
          a,
    ];
    if (kept.isEmpty) kept = used;
  }
  var lon0 = double.infinity, lon1 = -double.infinity;
  var lat0 = double.infinity, lat1 = -double.infinity;
  for (final r in kept) {
    lon0 = math.min(lon0, r.bounds.left);
    lon1 = math.max(lon1, r.bounds.right);
    lat0 = math.min(lat0, r.bounds.top);
    lat1 = math.max(lat1, r.bounds.bottom);
  }
  const m = WorldMapConfig.frameMarginDeg;
  lon0 -= m;
  lon1 += m;
  lat0 -= m;
  lat1 += m;

  void grow(double minSpan, bool horizontal) {
    final span = horizontal ? lon1 - lon0 : lat1 - lat0;
    if (span >= minSpan) return;
    final extra = (minSpan - span) / 2;
    if (horizontal) {
      lon0 -= extra;
      lon1 += extra;
    } else {
      lat0 -= extra;
      lat1 += extra;
    }
  }

  grow(WorldMapConfig.frameMinSpanDeg, true);
  grow(WorldMapConfig.frameMinSpanDeg, false);
  final mid = (lat0 + lat1) / 2;
  final aspect = frameAspect((lon0: lon0, lat0: lat0, lon1: lon1, lat1: lat1));
  if (aspect < WorldMapConfig.aspectMin) {
    grow(
      WorldMapConfig.aspectMin * (lat1 - lat0) / longitudeScale(mid),
      true,
    );
  } else if (aspect > WorldMapConfig.aspectMax) {
    grow(
      (lon1 - lon0) * longitudeScale(mid) / WorldMapConfig.aspectMax,
      false,
    );
  }

  // Inside the map area: shift, then cut what is still too big.
  double fit(double a0, double a1, double lo, double hi) {
    // returns the shift to apply
    if (a1 - a0 >= hi - lo) return lo - a0;
    if (a0 < lo) return lo - a0;
    if (a1 > hi) return hi - a1;
    return 0;
  }

  final dx = fit(lon0, lon1, WorldMapConfig.lonMin, WorldMapConfig.lonMax);
  lon0 = math.max(lon0 + dx, WorldMapConfig.lonMin);
  lon1 = math.min(lon1 + dx, WorldMapConfig.lonMax);
  final dy = fit(lat0, lat1, WorldMapConfig.latMin, WorldMapConfig.latMax);
  lat0 = math.max(lat0 + dy, WorldMapConfig.latMin);
  lat1 = math.min(lat1 + dy, WorldMapConfig.latMax);
  return (lon0: lon0, lat0: lat0, lon1: lon1, lat1: lat1);
}
