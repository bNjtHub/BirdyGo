/// Paints the world map (J7): land, the cells where the species is expected
/// in the chosen season, faint cells for the other seasons, the user's dot.
/// No tiles, no network.
library;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';
import 'land_outline.dart';

/// Colors of the map, from the theme's tokens.
///
/// One tint means one thing (DESIGN.md, J6h rule 4): a colored cell is
/// « expected here », in the brand color of the chosen bird (`accentText`,
/// which keeps 3:1 on the land and the ocean in every theme). The season is
/// told by the chips, not by a hue: oriole means rare and Lichen means
/// confirmed, so neither is borrowed for « passage » or « summer ».
@immutable
class WorldMapColors {
  const WorldMapColors({
    required this.ocean,
    required this.land,
    required this.present,
    required this.other,
    required this.user,
    required this.userRing,
  });

  factory WorldMapColors.of(BirdyColors c) {
    final land = Color.alphaBlend(c.line, c.surface1);
    return WorldMapColors(
      ocean: c.surface1,
      land: land,
      present: c.accentText,
      other: Color.alphaBlend(
        c.accentText.withValues(alpha: WorldMapConfig.ghostAlpha),
        land,
      ),
      user: c.text1,
      userRing: c.surface1,
    );
  }

  /// Sea: the block's own fill.
  final Color ocean;
  final Color land;

  /// Expected in the chosen season.
  final Color present;

  /// Expected in another season only.
  final Color other;
  final Color user;
  final Color userRing;

  @override
  bool operator ==(Object other) =>
      other is WorldMapColors &&
      other.ocean == ocean &&
      other.land == land &&
      other.present == present &&
      other.other == this.other &&
      other.user == user &&
      other.userRing == userRing;

  @override
  int get hashCode => Object.hash(ocean, land, present, other, user, userRing);
}

class WorldMapPainter extends CustomPainter {
  WorldMapPainter({
    required this.outline,
    required this.presence,
    required this.season,
    required this.colors,
    this.user,
  });

  final LandOutline outline;
  final SeasonPresence presence;
  final Season season;
  final WorldMapColors colors;
  final GridCell? user;

  static const double _lonSpan = WorldMapConfig.lonMax - WorldMapConfig.lonMin;
  static const double _latSpan = WorldMapConfig.latMax - WorldMapConfig.latMin;

  Offset _project(Size size, double lat, double lon) => Offset(
    (lon - WorldMapConfig.lonMin) / _lonSpan * size.width,
    (WorldMapConfig.latMax - lat) / _latSpan * size.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.ocean);

    // The path is built once in unit coordinates; scale the canvas to fit.
    canvas
      ..save()
      ..scale(size.width, size.height)
      ..drawPath(outline.unitPath, Paint()..color = colors.land)
      ..restore();

    final cellW = WorldMapConfig.gridStep / _lonSpan * size.width;
    final cellH = WorldMapConfig.gridStep / _latSpan * size.height;
    final inset = WorldMapConfig.cellInset;
    final radius = Radius.circular(
      WorldMapConfig.cellRadius * (cellW < cellH ? cellW : cellH),
    );
    final here = Paint()..color = colors.present;
    final elsewhere = Paint()..color = colors.other;
    // Faint cells first (other seasons only), then the chosen season's.
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < presence.cells.length; i++) {
        final isHere = presence.isPresent(season, i);
        final draw = pass == 0 ? !isHere && _inAnotherSeason(i) : isHere;
        if (!draw) continue;
        final centre = _project(
          size,
          presence.cells[i].latitude,
          presence.cells[i].longitude,
        );
        final rect = Rect.fromCenter(
          center: centre,
          width: cellW * (1 - inset),
          height: cellH * (1 - inset),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, radius),
          pass == 0 ? elsewhere : here,
        );
      }
    }

    final u = user;
    if (u != null &&
        u.longitude >= WorldMapConfig.lonMin &&
        u.longitude <= WorldMapConfig.lonMax &&
        u.latitude >= WorldMapConfig.latMin &&
        u.latitude <= WorldMapConfig.latMax) {
      final p = _project(size, u.latitude, u.longitude);
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

  bool _inAnotherSeason(int cell) =>
      Season.values.any((s) => s != season && presence.isPresent(s, cell));

  @override
  bool shouldRepaint(WorldMapPainter old) =>
      old.season != season ||
      old.presence != presence ||
      old.colors != colors ||
      old.user != user ||
      old.outline != outline;
}
