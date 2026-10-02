/// Which part of the world the full-screen map shows (J7): a zoom and a
/// centre, in degrees, inside the map area. Pure geometry: no widgets, so the
/// gestures can be tested without a screen.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'range_frame.dart';
import 'world_map_config.dart';
import 'world_regions.dart';

/// A view of the map in a box of [size] pixels. Zoom 1 shows the whole
/// [home] frame (the species' range, as the inline map frames it), bigger
/// zooms show a smaller window. Degrees keep the aspect of [home]: one degree
/// of longitude is `longitudeScale` times as wide as one of latitude.
@immutable
class MapViewport {
  const MapViewport._(
    this.home,
    this.size,
    this.zoom,
    this.centerLon,
    this.centerLat,
  );

  /// Zoom 1, centred on [home].
  factory MapViewport.home(MapFrame home, Size size) =>
      MapViewport._(
        home,
        size,
        WorldMapConfig.minScale,
        (home.lon0 + home.lon1) / 2,
        (home.lat0 + home.lat1) / 2,
      )._clamped();

  final MapFrame home;
  final Size size;
  final double zoom;
  final double centerLon;
  final double centerLat;

  double get _cos => longitudeScale((home.lat0 + home.lat1) / 2);

  /// Pixels per degree of latitude at zoom 1: the home frame fits the box.
  double get _base => math.min(
    size.width / ((home.lon1 - home.lon0) * _cos),
    size.height / (home.lat1 - home.lat0),
  );

  double get pixelsPerLat => _base * zoom;
  double get pixelsPerLon => _base * zoom * _cos;

  /// The window shown, in degrees.
  MapFrame get frame => (
    lon0: centerLon - size.width / 2 / pixelsPerLon,
    lat0: centerLat - size.height / 2 / pixelsPerLat,
    lon1: centerLon + size.width / 2 / pixelsPerLon,
    lat1: centerLat + size.height / 2 / pixelsPerLat,
  );

  /// Whether the view is back to the home framing.
  bool get isHome => zoom <= WorldMapConfig.minScale;

  bool get atMaxZoom => zoom >= WorldMapConfig.maxScale;

  /// The view at [newZoom] (clamped to the limits) in which the map point
  /// [geo] sits under the pixel [screen]: pinch, pan and double tap are all
  /// this one operation.
  MapViewport anchored(GridCell geo, Offset screen, double newZoom) {
    final z = newZoom.clamp(WorldMapConfig.minScale, WorldMapConfig.maxScale);
    final probe = MapViewport._(home, size, z, 0, 0);
    return MapViewport._(
      home,
      size,
      z,
      geo.longitude - (screen.dx - size.width / 2) / probe.pixelsPerLon,
      geo.latitude + (screen.dy - size.height / 2) / probe.pixelsPerLat,
    )._clamped();
  }

  /// The same view in a box of another size (rotation, a panel resizing).
  MapViewport resized(Size s) =>
      MapViewport._(home, s, zoom, centerLon, centerLat)._clamped();

  /// Back to the home framing.
  MapViewport get reset => MapViewport.home(home, size);

  /// Keeps the window inside the map area; when the window is bigger than
  /// the area on an axis, the area is centred on it.
  MapViewport _clamped() {
    double clamp(double c, double span, double lo, double hi) {
      if (span >= hi - lo) return (lo + hi) / 2;
      return c.clamp(lo + span / 2, hi - span / 2);
    }

    final lon = clamp(
      centerLon,
      size.width / pixelsPerLon,
      WorldMapConfig.lonMin,
      // A Pacific-centred home frame may use the second copy of the world.
      home.lon1 > WorldMapConfig.lonMax
          ? WorldMapConfig.lonWrapMax
          : WorldMapConfig.lonMax,
    );
    final lat = clamp(
      centerLat,
      size.height / pixelsPerLat,
      WorldMapConfig.latMin,
      WorldMapConfig.latMax,
    );
    return MapViewport._(home, size, zoom, lon, lat);
  }

  @override
  bool operator ==(Object other) =>
      other is MapViewport &&
      other.home == home &&
      other.size == size &&
      other.zoom == zoom &&
      other.centerLon == centerLon &&
      other.centerLat == centerLat;

  @override
  int get hashCode => Object.hash(home, size, zoom, centerLon, centerLat);
}
