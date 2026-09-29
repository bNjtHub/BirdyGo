/// Sequential Martin-pêcheur scale for value-based bars (J6f-b fix): the
/// species page's activity-by-hour chart colors each bar by its share of
/// the busiest hour, from a quiet-but-legible shade to the busiest,
/// strongest one. Every non-zero step keeps at least 3:1 contrast on its
/// card (fork/maquette/SPEC.md 9.13); zero hours use a separate track
/// color, not this scale.
library;

import 'package:flutter/material.dart';

import 'birdy_tokens.dart';
import 'species_tint.dart' show contrastRatio;

@immutable
class ActivityScale {
  const ActivityScale._(this._quiet, this._busy);

  final Color _quiet;
  final Color _busy;

  /// Minimum contrast every non-zero step keeps against its card
  /// (fork/maquette/SPEC.md 9.13).
  static const double minContrast = 3;

  /// Color for [value] out of [maxValue]; meant for value > 0 only (zero
  /// hours are drawn with a separate track color).
  Color of(int value, int maxValue) => Color.lerp(
    _quiet,
    _busy,
    maxValue <= 0 ? 1 : (value / maxValue).clamp(0, 1),
  )!;

  /// Builds the scale from the brand [hue] (the bird theme's accent; the
  /// Loriot teal by default) against [background]:
  /// the quietest non-zero step is the shade closest to [background]'s own
  /// lightness that still reaches [minContrast]; the busiest step is the
  /// farthest, most legible shade.
  factory ActivityScale.kingfisher(
    Color background, {
    Color hue = BirdyBrand.kingfisher,
  }) {
    final hsl = HSLColor.fromColor(hue);
    final bgLightness = HSLColor.fromColor(background).lightness;
    // A light card needs darker bars for contrast, and vice versa.
    final darken = bgLightness > 0.5;
    final farthest = darken ? 0.0 : 1.0;
    final step = darken ? -0.02 : 0.02;
    var lightness = bgLightness;
    Color shade() => hsl.withLightness(lightness).toColor();
    var guard = 0;
    while (contrastRatio(shade(), background) < minContrast && guard < 60) {
      lightness = (lightness + step).clamp(0.0, 1.0);
      guard++;
    }
    return ActivityScale._(shade(), hsl.withLightness(farthest).toColor());
  }
}
