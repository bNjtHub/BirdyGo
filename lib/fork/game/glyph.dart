/// Layered glyph model (J6k): the status and badge drawings on a 24 grid.
/// A glyph is a stack of [GlyphLayer]s (solid shapes, round-capped lines,
/// dots), each tinted by a tone of the disc it sits on. One drawing engine
/// for all of them: `paintGlyph` in `game_widgets.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Which colour of the disc a layer takes: the main tone (white), the accent
/// (Loriot) or the deep tone (the disc's shade, or ink).
enum GlyphTone { main, accent, deep }

/// Colours a glyph is painted with. [real]: the layers that have a true-life
/// colour (a beak, a kingfisher) use it, the others take their tone.
@immutable
class GlyphTones {
  const GlyphTones({
    required this.main,
    required this.accent,
    required this.deep,
    this.real = false,
  });

  final Color main;
  final Color accent;
  final Color deep;
  final bool real;

  Color of(GlyphTone tone) => switch (tone) {
    GlyphTone.main => main,
    GlyphTone.accent => accent,
    GlyphTone.deep => deep,
  };
}

/// One shape of a [Glyph]: an SVG path (solid or a line) or a dot, with its
/// tone, an optional true-life colour and opacity, and an optional transform
/// (translate [dx], [dy], then [scale], then [rotate] in degrees around the
/// grid centre).
@immutable
class GlyphLayer {
  /// Solid shape; [cut] is subtracted from it; [outline] adds a round stroke
  /// of that width in the same colour (small beaks).
  const GlyphLayer.fill(
    this.d,
    this.tone, {
    this.real,
    this.realOnly = false,
    this.opacity = 1,
    this.realOpacity,
    this.cut,
    this.outline = 0,
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
    this.rotate = 0,
  }) : line = false,
       width = 0,
       circle = null;

  /// Round-capped, round-joined line of [width].
  const GlyphLayer.line(
    this.d,
    this.width,
    this.tone, {
    this.real,
    this.realOnly = false,
    this.opacity = 1,
    this.realOpacity,
  }) : line = true,
       cut = null,
       outline = 0,
       dx = 0,
       dy = 0,
       scale = 1,
       rotate = 0,
       circle = null;

  /// Solid dot (cx, cy, r).
  const GlyphLayer.dot(
    double cx,
    double cy,
    double r,
    this.tone, {
    this.real,
    this.realOnly = false,
    this.opacity = 1,
    this.realOpacity,
  }) : d = '',
       line = false,
       width = 0,
       cut = null,
       outline = 0,
       dx = 0,
       dy = 0,
       scale = 1,
       rotate = 0,
       circle = (cx, cy, r);

  final String d;
  final (double, double, double)? circle;
  final bool line;
  final double width;
  final GlyphTone tone;

  /// True-life colour, used when the glyph is painted with real tones.
  final Color? real;

  /// Drawn only with real tones (details a silhouette does not need).
  final bool realOnly;
  final double opacity;

  /// Opacity with real tones, when it differs from [opacity].
  final double? realOpacity;
  final String? cut;
  final double outline;
  final double dx;
  final double dy;
  final double scale;
  final double rotate;
}

/// A 24 × 24 drawing made of [layers], painted back to front.
@immutable
class Glyph {
  const Glyph(this.layers);

  final List<GlyphLayer> layers;
}
