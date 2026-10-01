/// Administrative regions of the world map (J7): the Natural Earth admin-1
/// polygons of the map area and the country borders, read from the compact
/// asset made by tools/fork_world_regions.py, plus the join table GADM
/// level-1 id -> region ids (GBIF counts observations per GADM region).
///
/// Pure data and `dart:ui` paths; no Flutter binding needed.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'world_map_config.dart';

/// A point of the map, in degrees.
typedef GridCell = ({double latitude, double longitude});

/// One region: its rings (outer ones counter-clockwise, holes clockwise, as
/// flat lon, lat lists in degrees, not closed) and what is derived from them.
class MapRegion {
  MapRegion._(this.id, this.name, this.rings, this.bounds, this.area, this.centroid);

  /// Region from raw rings of (lon, lat) pairs (tests and the parser).
  factory MapRegion.fromRings(
    String id,
    String name,
    List<Float32List> rings,
  ) {
    var minLon = double.infinity, maxLon = -double.infinity;
    var minLat = double.infinity, maxLat = -double.infinity;
    var area = 0.0, cx = 0.0, cy = 0.0;
    for (final ring in rings) {
      final n = ring.length ~/ 2;
      var a = 0.0, rx = 0.0, ry = 0.0;
      for (var i = 0; i < n; i++) {
        final x0 = ring[i * 2], y0 = ring[i * 2 + 1];
        final j = (i + 1) % n;
        final x1 = ring[j * 2], y1 = ring[j * 2 + 1];
        minLon = math.min(minLon, x0);
        maxLon = math.max(maxLon, x0);
        minLat = math.min(minLat, y0);
        maxLat = math.max(maxLat, y0);
        final cross = x0 * y1 - x1 * y0;
        a += cross;
        rx += (x0 + x1) * cross;
        ry += (y0 + y1) * cross;
      }
      a /= 2;
      area += a;
      if (a != 0) {
        cx += rx / 6;
        cy += ry / 6;
      }
    }
    if (rings.isEmpty) {
      minLon = maxLon = minLat = maxLat = 0;
    }
    final GridCell centroid;
    if (area.abs() > 1e-12) {
      centroid = (latitude: cy / area, longitude: cx / area);
    } else {
      centroid = (
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2,
      );
    }
    // Square degrees, shrunk towards the poles: a fair weight for the legend.
    final weighted =
        area.abs() * math.cos(centroid.latitude * math.pi / 180).abs();
    return MapRegion._(
      id,
      name,
      rings,
      Rect.fromLTRB(minLon, minLat, maxLon, maxLat),
      weighted,
      centroid,
    );
  }

  /// Stable id (Natural Earth `adm1_code`).
  final String id;
  final String name;
  final List<Float32List> rings;

  /// Bounding box in degrees (left, right = longitudes; top, bottom =
  /// south and north latitudes, so `top < bottom`).
  final Rect bounds;

  /// Approximate area, in square degrees corrected for latitude.
  final double area;
  final GridCell centroid;

  Path? _path;

  /// The region as a path in map units: x = longitude, y = minus latitude
  /// (north up). Even-odd, so holes are holes. Built once.
  Path get path => _path ??= _pathOf(rings);

  /// Whether ([lon], [lat]) is inside (even-odd ray casting).
  bool contains(double lon, double lat) {
    if (lon < bounds.left ||
        lon > bounds.right ||
        lat < bounds.top ||
        lat > bounds.bottom) {
      return false;
    }
    var inside = false;
    for (final ring in rings) {
      final n = ring.length ~/ 2;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        final xi = ring[i * 2], yi = ring[i * 2 + 1];
        final xj = ring[j * 2], yj = ring[j * 2 + 1];
        if ((yi > lat) != (yj > lat) &&
            lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
    }
    return inside;
  }
}

Path _pathOf(List<Float32List> rings, {bool closed = true}) {
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final ring in rings) {
    final n = ring.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final x = ring[i * 2].toDouble(), y = -ring[i * 2 + 1].toDouble();
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    if (closed) path.close();
  }
  return path;
}

class WorldRegions {
  WorldRegions(this.regions, this.borders)
    : _index = {for (var i = 0; i < regions.length; i++) regions[i].id: i};

  /// Parses the asset [bytes] (already gunzipped); the format is described
  /// in tools/fork_world_regions.py.
  factory WorldRegions.parse(Uint8List bytes) {
    final r = _Reader(bytes);
    if (bytes.length < 6 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'BGR1') {
      throw const FormatException('not a regions asset');
    }
    r.pos = 4;
    final count = r.byte() | (r.byte() << 8);
    final regions = <MapRegion>[];
    for (var i = 0; i < count; i++) {
      final id = String.fromCharCodes(r.take(r.byte()));
      final name = utf8.decode(r.take(r.byte()), allowMalformed: true);
      final rings = [
        for (var k = 0, n = r.varint(); k < n; k++) r.points(),
      ];
      regions.add(MapRegion.fromRings(id, name, rings));
    }
    final borders = [
      for (var k = 0, n = r.varint(); k < n; k++) r.points(),
    ];
    return WorldRegions(regions, borders);
  }

  /// Parses the gzip asset [gz].
  factory WorldRegions.fromGzip(Uint8List gz) =>
      WorldRegions.parse(Uint8List.fromList(gzip.decode(gz)));

  final List<MapRegion> regions;

  /// Country borders (shared borders once), as flat lon, lat lists.
  final List<Float32List> borders;

  final Map<String, int> _index;

  MapRegion? byId(String id) {
    final i = _index[id];
    return i == null ? null : regions[i];
  }

  int? indexOf(String id) => _index[id];

  /// The region holding ([lon], [lat]), or null at sea.
  MapRegion? regionAt(double lon, double lat) {
    for (final region in regions) {
      if (region.contains(lon, lat)) return region;
    }
    return null;
  }

  Path? _bordersPath;

  /// Country borders as one open-contour path (map units).
  Path get bordersPath => _bordersPath ??= _pathOf(borders, closed: false);

  Path? _landPath;

  /// All regions in one path: the land.
  Path get landPath =>
      _landPath ??= (Path()..fillType = PathFillType.evenOdd)
        ..addAll(regions.map((r) => r.path));

}

extension on Path {
  void addAll(Iterable<Path> paths) {
    for (final p in paths) {
      addPath(p, Offset.zero);
    }
  }
}

class _Reader {
  _Reader(this.bytes);

  final Uint8List bytes;
  int pos = 0;

  int byte() => bytes[pos++];

  Uint8List take(int n) {
    final out = Uint8List.sublistView(bytes, pos, pos + n);
    pos += n;
    return out;
  }

  int varint() {
    var shift = 0, value = 0;
    while (true) {
      final b = bytes[pos++];
      value |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return value;
      shift += 7;
    }
  }

  int zigzag() {
    final n = varint();
    return (n >> 1) ^ -(n & 1);
  }

  /// A point list: count, then absolute first point and deltas.
  Float32List points() {
    final n = varint();
    final out = Float32List(n * 2);
    var x = 0, y = 0;
    for (var i = 0; i < n; i++) {
      x += zigzag();
      y += zigzag();
      out[i * 2] = x / WorldMapConfig.regionsScale;
      out[i * 2 + 1] = y / WorldMapConfig.regionsScale;
    }
    return out;
  }
}

/// GADM level-1 id -> ids of the regions it covers (a key join: the app
/// carries no GADM geometry).
class GadmJoin {
  const GadmJoin(this.regionsOf);

  /// Parses the gzip asset [gz].
  factory GadmJoin.fromGzip(Uint8List gz) {
    final json = jsonDecode(utf8.decode(gzip.decode(gz))) as Map<String, dynamic>;
    return GadmJoin({
      for (final e in json.entries)
        e.key: [for (final id in e.value as List<dynamic>) id as String],
    });
  }

  final Map<String, List<String>> regionsOf;
}
