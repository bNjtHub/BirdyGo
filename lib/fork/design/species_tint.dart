/// Species colors (J6a) and the WCAG contrast helper they rely on.
///
/// Each species has an accent (from its icon or photo). The other shades are
/// derived so text on them always keeps AA contrast (SPEC.md 2.5).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'birdy_tokens.dart';

/// WCAG 2 contrast ratio between two opaque colors (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The four shades of a species color.
@immutable
class SpeciesTint {
  const SpeciesTint({
    required this.accent,
    required this.tintDark,
    required this.tintLight,
    required this.deep,
  });

  /// Derives the shades from an accent color:
  /// - [tintDark]: the accent at 24 % on Encre de nuit;
  /// - [tintLight]: same hue, lightness 0.92 or more, ≥ [minInkContrast] with
  ///   Encre de nuit;
  /// - [deep]: the accent darkened toward Encre until ≥ [minDeepContrast] on
  ///   white.
  factory SpeciesTint.fromAccent(Color accent) {
    final opaque = accent.withValues(alpha: 1);
    final tintDark = Color.alphaBlend(
      opaque.withValues(alpha: 0.24),
      BirdyBrand.ink,
    );

    final hsl = HSLColor.fromColor(opaque);
    var lightness = 0.92;
    var tintLight = hsl.withLightness(lightness).toColor();
    while (contrastRatio(BirdyBrand.ink, tintLight) < minInkContrast &&
        lightness < 1) {
      lightness = math.min(1, lightness + 0.01);
      tintLight = hsl.withLightness(lightness).toColor();
    }

    const white = Color(0xFFFFFFFF);
    var deep = opaque;
    for (
      var t = 0.01;
      contrastRatio(deep, white) < minDeepContrast;
      t += 0.01
    ) {
      deep = Color.lerp(opaque, BirdyBrand.ink, math.min(1, t))!;
    }

    return SpeciesTint(
      accent: opaque,
      tintDark: tintDark,
      tintLight: tintLight,
      deep: deep,
    );
  }

  /// Minimum contrast of Encre de nuit text on [tintLight].
  static const double minInkContrast = 12;

  /// Minimum contrast of [deep] graphics on white.
  static const double minDeepContrast = 3.2;

  /// Sober tint for a species without photo nor icon.
  static final SpeciesTint neutral = SpeciesTint.fromAccent(BirdyBrand.bark);

  /// Row halo, glow, wave, podium, map ring on dark.
  final Color accent;

  /// Celebration card top on dark (Brume text).
  final Color tintDark;

  /// Card and header background on light (Encre text).
  final Color tintLight;

  /// Bars and graphics on light.
  final Color deep;

  /// Halo behind the species icon (accent at 20 %).
  Color get halo => accent.withValues(alpha: 0.20);

  /// Glow of a row when the species sings again (accent at 22 %).
  Color get glow => accent.withValues(alpha: 0.22);

  /// Card background for the given theme brightness.
  Color cardBackground(Brightness brightness) =>
      brightness == Brightness.dark ? tintDark : tintLight;

  @override
  bool operator ==(Object other) =>
      other is SpeciesTint &&
      other.accent == accent &&
      other.tintDark == tintDark &&
      other.tintLight == tintLight &&
      other.deep == deep;

  @override
  int get hashCode => Object.hash(accent, tintDark, tintLight, deep);
}
