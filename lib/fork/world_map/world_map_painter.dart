/// Paints the world map (J7): land, the cells where the species is expected
/// in the chosen season, faint cells for the other seasons, the user's dot.
/// No tiles, no network.
library;

import 'package:flutter/foundation.dart' show listEquals;
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
    required this.levels,
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
      levels: [
        for (final a in WorldMapConfig.levelAlphas)
          Color.alphaBlend(c.accentText.withValues(alpha: a), land),
      ],
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

  /// Expected in the chosen season (the strongest level).
  final Color present;

  /// Color of GBIF intensity level 1, 2, 3 (index = level - 1): the same tint
  /// at growing opacity, blended over the land so cells stay opaque.
  final List<Color> levels;

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
      listEquals(other.levels, levels) &&
      other.other == this.other &&
      other.user == user &&
      other.userRing == userRing;

  @override
  int get hashCode => Object.hash(ocean, land, present, Object.hashAll(levels), other, user, userRing);
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

    final step = presence.step;
    final cellW = step / _lonSpan * size.width;
    final cellH = step / _latSpan * size.height;
    final smallest = cellW < cellH ? cellW : cellH;
    // Fine (GBIF) cells touch and join into areas; big ones keep a gap.
    final tight = smallest < WorldMapConfig.cellGapMinSize;
    final inset = tight ? 0.0 : WorldMapConfig.cellInset;
    final radius = Radius.circular(
      tight ? 0 : WorldMapConfig.cellRadius * smallest,
    );
    RRect cellRect(int i) {
      final centre = _project(
        size,
        presence.cells[i].latitude,
        presence.cells[i].longitude,
      );
      return RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centre,
          width: cellW * (1 - inset),
          height: cellH * (1 - inset),
        ),
        radius,
      );
    }

    // Faint cells first (other seasons only), then the chosen season's, one
    // path per intensity level (a GBIF map can have thousands of cells).
    final elsewhere = Path();
    final here = [for (final _ in colors.levels) Path()];
    for (var i = 0; i < presence.cells.length; i++) {
      final level = presence.levelOf(season, i);
      if (level > 0) {
        here[level.clamp(1, here.length) - 1].addRRect(cellRect(i));
      } else if (_inAnotherSeason(i)) {
        elsewhere.addRRect(cellRect(i));
      }
    }
    canvas.drawPath(elsewhere, Paint()..color = colors.other);
    for (var l = 0; l < here.length; l++) {
      canvas.drawPath(here[l], Paint()..color = colors.levels[l]);
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
