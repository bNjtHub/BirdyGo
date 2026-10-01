/// Paints the world map (J7): sea, land, the regions the species uses in
/// their class color (whole regions, following their borders), hairlines
/// between regions, thicker country borders, the user's dot. No tiles, no
/// network; the paths are built once and only transformed to the size.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import 'range_class.dart';
import 'range_frame.dart';
import 'world_map_config.dart';
import 'world_regions.dart';

/// Colors of the map, from the theme's tokens: the four class colors are the
/// `range*` tokens; sea and land are the block's own fill and its `line`.
@immutable
class WorldMapColors {
  const WorldMapColors({
    required this.ocean,
    required this.land,
    required this.classes,
    required this.regionLine,
    required this.countryLine,
    required this.selected,
    required this.user,
    required this.userRing,
  });

  factory WorldMapColors.of(BirdyColors c) => WorldMapColors(
    ocean: c.surface1,
    land: Color.alphaBlend(c.line, c.surface1),
    classes: {
      RangeClass.breeding: c.rangeBreeding,
      RangeClass.wintering: c.rangeWintering,
      RangeClass.resident: c.rangeResident,
      RangeClass.passage: c.rangePassage,
    },
    regionLine: c.surface1.withValues(alpha: WorldMapConfig.regionLineAlpha),
    countryLine: c.text2.withValues(alpha: WorldMapConfig.countryLineAlpha),
    selected: c.text1,
    user: c.text1,
    userRing: c.surface1,
  );

  /// Sea: the block's own fill.
  final Color ocean;
  final Color land;

  /// Fill of each class.
  final Map<RangeClass, Color> classes;

  /// Hairline between regions (the block's fill, so it also separates two
  /// colored neighbours) and the country borders.
  final Color regionLine;
  final Color countryLine;

  /// Outline of the tapped region.
  final Color selected;
  final Color user;
  final Color userRing;

  @override
  bool operator ==(Object other) =>
      other is WorldMapColors &&
      other.ocean == ocean &&
      other.land == land &&
      other.classes[RangeClass.breeding] == classes[RangeClass.breeding] &&
      other.classes[RangeClass.wintering] == classes[RangeClass.wintering] &&
      other.classes[RangeClass.resident] == classes[RangeClass.resident] &&
      other.classes[RangeClass.passage] == classes[RangeClass.passage] &&
      other.regionLine == regionLine &&
      other.countryLine == countryLine &&
      other.selected == selected &&
      other.user == user &&
      other.userRing == userRing;

  @override
  int get hashCode => Object.hash(
    ocean,
    land,
    Object.hashAll(classes.values),
    regionLine,
    countryLine,
    selected,
    user,
    userRing,
  );
}

/// Where a map point of a [frame] falls in a [size] box, and back.
class MapProjection {
  MapProjection(this.frame, this.size)
    : _sx = size.width / (frame.lon1 - frame.lon0),
      _sy = size.height / (frame.lat1 - frame.lat0);

  final MapFrame frame;
  final Size size;
  final double _sx;
  final double _sy;

  Offset project(double lat, double lon) =>
      Offset((lon - frame.lon0) * _sx, (frame.lat1 - lat) * _sy);

  GridCell unproject(Offset p) => (
    latitude: frame.lat1 - p.dy / _sy,
    longitude: frame.lon0 + p.dx / _sx,
  );

  /// Matrix taking the regions' path units (x = lon, y = -lat) to pixels.
  Float64List get matrix =>
      Float64List(16)
        ..[0] = _sx
        ..[5] = _sy
        ..[10] = 1
        ..[12] = -frame.lon0 * _sx
        ..[13] = frame.lat1 * _sy
        ..[15] = 1;
}

class WorldMapPainter extends CustomPainter {
  WorldMapPainter({
    required this.regions,
    required this.classes,
    required this.frame,
    required this.colors,
    this.user,
    this.selected,
  });

  final WorldRegions regions;

  /// Class of each region the species uses, by region id.
  final Map<String, RangeClass> classes;
  final MapFrame frame;
  final WorldMapColors colors;
  final GridCell? user;

  /// Id of the tapped region.
  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.ocean);

    final projection = MapProjection(frame, size);
    final m = projection.matrix;
    final fill = Paint()..style = PaintingStyle.fill;
    canvas.drawPath(regions.landPath.transform(m), fill..color = colors.land);

    final byClass = {
      for (final c in RangeClass.values)
        c: Path()..fillType = PathFillType.evenOdd,
    };
    for (final e in classes.entries) {
      final region = regions.byId(e.key);
      if (region == null) continue;
      byClass[e.value]!.addPath(region.path, Offset.zero, matrix4: m);
    }
    for (final c in RangeClass.values) {
      canvas.drawPath(byClass[c]!, fill..color = colors.classes[c]!);
    }

    canvas
      ..drawPath(
        regions.landPath.transform(m),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = WorldMapConfig.regionLineWidth
          ..strokeJoin = StrokeJoin.round
          ..color = colors.regionLine,
      )
      ..drawPath(
        regions.bordersPath.transform(m),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = WorldMapConfig.countryLineWidth
          ..strokeJoin = StrokeJoin.round
          ..color = colors.countryLine,
      );

    final tapped = selected == null ? null : regions.byId(selected!);
    if (tapped != null) {
      canvas.drawPath(
        tapped.path.transform(m),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = WorldMapConfig.selectedLineWidth
          ..strokeJoin = StrokeJoin.round
          ..color = colors.selected,
      );
    }

    final u = user;
    if (u != null &&
        u.longitude >= frame.lon0 &&
        u.longitude <= frame.lon1 &&
        u.latitude >= frame.lat0 &&
        u.latitude <= frame.lat1) {
      final p = projection.project(u.latitude, u.longitude);
      canvas
        ..drawCircle(
          p,
          WorldMapConfig.userDot / 2 + WorldMapConfig.userDotRing,
          Paint()..color = colors.userRing,
        )
        ..drawCircle(
          p,
          WorldMapConfig.userDot / 2,
          Paint()..color = colors.user,
        );
    }
  }

  @override
  bool shouldRepaint(WorldMapPainter old) =>
      old.regions != regions ||
      old.classes != classes ||
      old.frame != frame ||
      old.colors != colors ||
      old.user != user ||
      old.selected != selected;
}
