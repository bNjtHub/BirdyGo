/// Hexagonal binning on the Web Mercator plane, for the contact map
/// (fork/PLAN.md J5). Pure Dart, no Flutter.
///
/// A grid is tied to a zoom level: its hexagons have a fixed radius in
/// pixels at that zoom, so they look the same size on screen whatever the
/// latitude, and they nest cleanly with the map's own tiles.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Axial coordinates `(q, r)` of a hexagon (pointy top).
typedef HexKey = (int, int);

const double _maxMercatorLat = 85.05112878;
const double _sqrt3 = 1.7320508075688772;

/// Normalized Web Mercator position of a point: `x` and `y` in `[0, 1]`,
/// `y` growing southward, like map tiles.
({double x, double y}) toMercator(double latitude, double longitude) {
  final lat = latitude.clamp(-_maxMercatorLat, _maxMercatorLat);
  final phi = lat * math.pi / 180;
  final x = (longitude + 180) / 360;
  final y = (1 - math.log(math.tan(phi) + 1 / math.cos(phi)) / math.pi) / 2;
  return (x: x, y: y);
}

/// Inverse of [toMercator].
LatLng fromMercator(double x, double y) {
  final n = math.pi * (1 - 2 * y);
  final lat = math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
  return LatLng(lat, x * 360 - 180);
}

/// A hexagon grid of [radiusPx] pixels at [zoom].
class HexGrid {
  HexGrid({required this.zoom, required this.radiusPx})
    : _scale = 256 * math.pow(2, zoom).toDouble();

  final int zoom;
  final double radiusPx;

  /// World size in pixels at [zoom].
  final double _scale;

  /// Hexagon containing the normalized Mercator point `(x, y)`.
  HexKey keyOfMercator(double x, double y) {
    final px = x * _scale;
    final py = y * _scale;
    final q = (_sqrt3 / 3 * px - py / 3) / radiusPx;
    final r = (2 / 3 * py) / radiusPx;
    return _round(q, r);
  }

  /// Hexagon containing [point].
  HexKey keyOf(LatLng point) {
    final m = toMercator(point.latitude, point.longitude);
    return keyOfMercator(m.x, m.y);
  }

  /// Center of hexagon [key].
  LatLng center(HexKey key) {
    final (px, py) = _centerPx(key);
    return fromMercator(px / _scale, py / _scale);
  }

  /// The six corners of hexagon [key], clockwise from the top right.
  List<LatLng> corners(HexKey key) {
    final (cx, cy) = _centerPx(key);
    return [
      for (var i = 0; i < 6; i++)
        fromMercator(
          (cx + radiusPx * math.cos(math.pi / 180 * (60 * i - 30))) / _scale,
          (cy + radiusPx * math.sin(math.pi / 180 * (60 * i - 30))) / _scale,
        ),
    ];
  }

  (double, double) _centerPx(HexKey key) {
    final (q, r) = key;
    return (radiusPx * (_sqrt3 * q + _sqrt3 / 2 * r), radiusPx * (1.5 * r));
  }

  /// Cube rounding of fractional axial coordinates.
  static HexKey _round(double q, double r) {
    final s = -q - r;
    var rq = q.roundToDouble();
    var rr = r.roundToDouble();
    final rs = s.roundToDouble();
    final dq = (rq - q).abs();
    final dr = (rr - r).abs();
    final ds = (rs - s).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return (rq.toInt(), rr.toInt());
  }
}
