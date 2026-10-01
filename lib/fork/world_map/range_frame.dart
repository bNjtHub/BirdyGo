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
                          _lonDistance(
                            a.centroid.longitude,
                            b.centroid.longitude,
                          ),
                          2,
                        ),
                  ) <=
                  limit,
        ))
          a,
    ];
    if (kept.isEmpty) kept = used;
  }
  var (lon0, lon1) = _longitudeWindow(kept);
  var lat0 = double.infinity, lat1 = -double.infinity;
  for (final r in kept) {
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

  // A window that crosses the antimeridian (lon1 > 180) may use the second
  // copy of the world; one as wide as the world is the plain world.
  if (lon1 - lon0 >= WorldMapConfig.lonPeriod) {
    lon0 = WorldMapConfig.lonMin;
    lon1 = WorldMapConfig.lonMax;
  }
  final wrapped = lon1 > WorldMapConfig.lonMax;
  final loLon = WorldMapConfig.lonMin;
  final hiLon = wrapped ? WorldMapConfig.lonWrapMax : WorldMapConfig.lonMax;
  final dx = fit(lon0, lon1, loLon, hiLon);
  lon0 = math.max(lon0 + dx, loLon);
  lon1 = math.min(lon1 + dx, hiLon);
  final dy = fit(lat0, lat1, WorldMapConfig.latMin, WorldMapConfig.latMax);
  lat0 = math.max(lat0 + dy, WorldMapConfig.latMin);
  lat1 = math.min(lat1 + dy, WorldMapConfig.latMax);
  return (lon0: lon0, lat0: lat0, lon1: lon1, lat1: lat1);
}

/// Distance in degrees of longitude, the short way round the globe.
double _lonDistance(double a, double b) {
  final d = (a - b).abs() % WorldMapConfig.lonPeriod;
  return d > WorldMapConfig.lonPeriod / 2 ? WorldMapConfig.lonPeriod - d : d;
}

/// Longitude window of [regions]: the shortest arc of the globe holding all
/// their boxes. Usually the plain west-to-east box; when the regions sit on
/// both sides of the antimeridian (Chukotka and Alaska, Fiji and Samoa) the
/// window is Pacific-centred and [lon1] goes past 180 (lon0 < 180 < lon1).
(double, double) _longitudeWindow(List<MapRegion> regions) {
  // One box per ring: a region with parts on both sides of 180 (Chukotka,
  // Fiji) has a bounding box as wide as the world.
  final spans = <(double, double)>[];
  for (final r in regions) {
    for (final ring in r.rings) {
      var lo = double.infinity, hi = -double.infinity;
      for (var i = 0; i < ring.length; i += 2) {
        final x = ring[i];
        if (x < lo) lo = x;
        if (x > hi) hi = x;
      }
      if (lo <= hi) spans.add((lo, hi));
    }
  }
  spans.sort((a, b) => a.$1.compareTo(b.$1));
  // Union of the sorted boxes, then the widest gap between two of them,
  // the wrap-around gap (east end back to west start + 360) included.
  final merged = <(double, double)>[];
  for (final s in spans) {
    if (merged.isNotEmpty && s.$1 <= merged.last.$2) {
      if (s.$2 > merged.last.$2) merged.last = (merged.last.$1, s.$2);
    } else {
      merged.add(s);
    }
  }
  final west = merged.first.$1, east = merged.last.$2;
  var bestGap = west + WorldMapConfig.lonPeriod - east;
  var cut = -1; // -1: the wrap-around gap, the plain box
  for (var i = 0; i + 1 < merged.length; i++) {
    final gap = merged[i + 1].$1 - merged[i].$2;
    if (gap > bestGap) {
      bestGap = gap;
      cut = i;
    }
  }
  if (cut < 0) return (west, east);
  // Window starts after the gap and ends before the wrap-around, shifted.
  return (merged[cut + 1].$1, merged[cut].$2 + WorldMapConfig.lonPeriod);
}
