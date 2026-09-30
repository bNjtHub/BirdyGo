/// Land outline of the world map: parses the compact asset made by
/// tools/fork_land_110m.py, tests whether a point is on land (once per grid
/// cell, cached by the provider) and builds the drawing path once.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'world_map_config.dart';

/// Rings of land, as degrees. Pure data: no Flutter binding needed.
class LandOutline {
  LandOutline._(this._rings, this._bounds);

  /// Parses the asset [bytes]: uint16 ring count, then per ring a uint16
  /// point count and (int16 lon, int16 lat) pairs in 0.01 degree, all
  /// little-endian.
  factory LandOutline.parse(ByteData bytes) {
    var offset = 0;
    final count = bytes.getUint16(offset, Endian.little);
    offset += 2;
    final rings = <Float32List>[];
    final bounds = <Rect>[];
    for (var r = 0; r < count; r++) {
      final n = bytes.getUint16(offset, Endian.little);
      offset += 2;
      final ring = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        ring[i * 2] =
            bytes.getInt16(offset, Endian.little) / WorldMapConfig.landScale;
        ring[i * 2 + 1] =
            bytes.getInt16(offset + 2, Endian.little) /
            WorldMapConfig.landScale;
        offset += 4;
      }
      rings.add(ring);
      bounds.add(_boundsOf(ring));
    }
    return LandOutline._(rings, bounds);
  }

  /// Rings from raw (lon, lat) pairs (tests).
  factory LandOutline.fromRings(List<List<(double, double)>> rings) {
    final data = <Float32List>[];
    for (final ring in rings) {
      final flat = Float32List(ring.length * 2);
      for (var i = 0; i < ring.length; i++) {
        flat[i * 2] = ring[i].$1;
        flat[i * 2 + 1] = ring[i].$2;
      }
      data.add(flat);
    }
    return LandOutline._(data, [for (final r in data) _boundsOf(r)]);
  }

  static Rect _boundsOf(Float32List ring) {
    var minLon = double.infinity, maxLon = -double.infinity;
    var minLat = double.infinity, maxLat = -double.infinity;
    for (var i = 0; i < ring.length; i += 2) {
      minLon = math.min(minLon, ring[i]);
      maxLon = math.max(maxLon, ring[i]);
      minLat = math.min(minLat, ring[i + 1]);
      maxLat = math.max(maxLat, ring[i + 1]);
    }
    // top < bottom here: the rect is in degrees, south to north.
    return Rect.fromLTRB(minLon, minLat, maxLon, maxLat);
  }

  final List<Float32List> _rings;
  final List<Rect> _bounds;

  int get ringCount => _rings.length;

  /// Whether ([lon], [lat]) is inside a land ring (even-odd ray casting).
  bool contains(double lon, double lat) {
    for (var r = 0; r < _rings.length; r++) {
      final b = _bounds[r];
      if (lon < b.left || lon > b.right || lat < b.top || lat > b.bottom) {
        continue;
      }
      if (_ringContains(_rings[r], lon, lat)) return true;
    }
    return false;
  }

  static bool _ringContains(Float32List ring, double lon, double lat) {
    final n = ring.length ~/ 2;
    var inside = false;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = ring[i * 2], yi = ring[i * 2 + 1];
      final xj = ring[j * 2], yj = ring[j * 2 + 1];
      if ((yi > lat) != (yj > lat) &&
          lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  Path? _path;

  /// The land of the default view in unit coordinates (x from the west edge,
  /// y from the north edge, both 0 to 1), built once. Rings entirely outside
  /// the view are left out. Scale the canvas to the map size to draw it.
  Path get unitPath => _path ??= _buildPath();

  Path _buildPath() {
    const lonSpan = WorldMapConfig.lonMax - WorldMapConfig.lonMin;
    const latSpan = WorldMapConfig.latMax - WorldMapConfig.latMin;
    final view = Rect.fromLTRB(
      WorldMapConfig.lonMin,
      WorldMapConfig.latMin,
      WorldMapConfig.lonMax,
      WorldMapConfig.latMax,
    );
    final path = Path();
    for (var r = 0; r < _rings.length; r++) {
      if (!_bounds[r].overlaps(view)) continue;
      final ring = _rings[r];
      for (var i = 0; i < ring.length ~/ 2; i++) {
        final x = (ring[i * 2] - WorldMapConfig.lonMin) / lonSpan;
        final y = (WorldMapConfig.latMax - ring[i * 2 + 1]) / latSpan;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
    }
    return path;
  }
}
