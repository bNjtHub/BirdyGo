/// The four bird themes (J6i): the child picks "their bird" and the brand
/// color of the app, the logo and the launch screen follow.
///
/// Only the brand roles change (action fill, links, tonal fills, active nav
/// item, logo, glow). Colors that carry a meaning never do: the Sûr /
/// Probable / À vérifier levels, the Loriot gold (reward, streak, rare),
/// medals, level emblems, species tints and the Vent / Boost / Ville modes.
///
/// Values are those of the design project's `themes.js`
/// (fork/handoff/maquettes/themes.js); this file is the one place with the
/// raw theme colors. [BirdyColors.forBird] derives the theme's tokens from it.
library;

import 'package:flutter/material.dart';
import 'birdy_tokens.dart';

/// The bird a child chose. Named `BirdyBird` because [BirdyTheme] already
/// builds the `ThemeData`.
enum BirdyBird {
  /// Yellow and turquoise: the app's original look, and the default.
  loriot,
  martin,
  flamant,
  etourneau;

  /// The bird whose [name] is [stored], [loriot] when unknown or absent.
  static BirdyBird fromName(String? stored) => BirdyBird.values.firstWhere(
    (b) => b.name == stored,
    orElse: () => BirdyBird.loriot,
  );
}

/// Raw values of one bird, light and dark.
class _Palette {
  const _Palette({
    required this.acc,
    required this.accHi,
    required this.accDeep,
    required this.accT,
    required this.ton,
    required this.tonDark,
    required this.nav,
    required this.accL,
    required this.hi,
    required this.hiDeep,
    required this.dot,
    required this.dotDark,
    required this.accTDark,
    required this.glow,
  });

  final Color acc;
  final Color accHi;
  final Color accDeep;
  final Color accT;
  final Color ton;

  /// [acc] at 16 % (the dark tonal fill, as on the original Loriot theme).
  final Color tonDark;
  final Color nav;
  final Color accL;
  final Color hi;
  final Color hiDeep;
  final Color dot;
  final Color dotDark;
  final Color accTDark;
  final Color glow;
}

const Map<BirdyBird, _Palette> _palettes = {
  BirdyBird.loriot: _Palette(
    acc: Color(0xFF19A7B3),
    accHi: Color(0xFF1CAEBA),
    accDeep: Color(0xFF0E7C86),
    accT: Color(0xFF0B6E77),
    ton: Color(0xFFD6EEF0),
    tonDark: Color(0x2919A7B3),
    nav: Color(0xFFD1ECEF),
    accL: Color(0xFF8CD3D9),
    hi: Color(0xFFF4C542),
    hiDeep: Color(0xFFE3A22B),
    dot: Color(0xFFF4C542),
    dotDark: Color(0xFFF4C542),
    accTDark: Color(0xFF4FC3CC),
    glow: Color(0x5919A7B3),
  ),
  BirdyBird.martin: _Palette(
    acc: Color(0xFF3A9BE0),
    accHi: Color(0xFF4DA8E8),
    accDeep: Color(0xFF1F6FB8),
    accT: Color(0xFF1565A8),
    ton: Color(0xFFDCEBF8),
    tonDark: Color(0x293A9BE0),
    nav: Color(0xFFD3E5F7),
    accL: Color(0xFFA9D2F3),
    hi: Color(0xFFF28C38),
    hiDeep: Color(0xFFD46A1E),
    dot: Color(0xFFF28C38),
    dotDark: Color(0xFFF28C38),
    accTDark: Color(0xFF7DBBF0),
    glow: Color(0x593A9BE0),
  ),
  BirdyBird.flamant: _Palette(
    acc: Color(0xFFE86A9A),
    accHi: Color(0xFFEE7DA8),
    accDeep: Color(0xFFC2447A),
    accT: Color(0xFFA8305F),
    ton: Color(0xFFFBE1EB),
    tonDark: Color(0x29E86A9A),
    nav: Color(0xFFF8D6E3),
    accL: Color(0xFFF7B6CF),
    hi: Color(0xFF3A2F4F),
    hiDeep: Color(0xFF231B33),
    dot: Color(0xFFE86A9A),
    dotDark: Color(0xFFF59BC0),
    accTDark: Color(0xFFF59BC0),
    glow: Color(0x59E86A9A),
  ),
  BirdyBird.etourneau: _Palette(
    acc: Color(0xFF9D82E0),
    accHi: Color(0xFFA98FE6),
    accDeep: Color(0xFF6E4FC4),
    accT: Color(0xFF5B3FB0),
    ton: Color(0xFFE9E3F8),
    tonDark: Color(0x299D82E0),
    nav: Color(0xFFE2DAF6),
    accL: Color(0xFFCBBDF1),
    hi: Color(0xFFE9C46A),
    hiDeep: Color(0xFFC9A043),
    dot: Color(0xFFE9C46A),
    dotDark: Color(0xFFE9C46A),
    accTDark: Color(0xFFBBA6F0),
    glow: Color(0x599D82E0),
  ),
};

/// Brand roles of a [bird] in a [brightness]. A [ThemeExtension] carried by
/// `BirdyTheme`, next to `BirdyColors` (which holds the accent roles the
/// screens already read: accent, accentText, tonal, navIndicator).
///
/// The logo painters take one, defaulting to the Loriot look.
@immutable
class BirdyBrandColors extends ThemeExtension<BirdyBrandColors> {
  const BirdyBrandColors(this.bird, [this.brightness = Brightness.light]);

  final BirdyBird bird;
  final Brightness brightness;

  _Palette get _p => _palettes[bird]!;

  bool get isDark => brightness == Brightness.dark;

  /// Action fill (Écouter, progress); ink on it reaches 4.5:1.
  Color get accent => _p.acc;

  /// Lighter end of the logo's body gradient.
  Color get accentHi => _p.accHi;

  /// Deeper end of the logo's body gradient.
  Color get accentDeep => _p.accDeep;

  /// Accent for text and icons on this brightness's surfaces (AA).
  Color get accentText => isDark ? _p.accTDark : _p.accT;

  /// The dark-surface accent text, whatever the brightness (live listening).
  Color get accentTextDark => _p.accTDark;

  /// Tonal fill: solid on light, a translucent accent on dark.
  Color get tonal => isDark ? _p.tonDark : _p.ton;

  /// Active bottom-navigation item; on dark it is the surface, as before.
  Color get navIndicator => isDark ? BirdyColors.dark.navIndicator : _p.nav;

  /// Pale tint: the wing's fourth bar.
  Color get accentLight => _p.accL;

  /// Logo: upper beak and second wing bar.
  Color get highlight => _p.hi;

  /// Logo: lower beak.
  Color get highlightDeep => _p.hiDeep;

  /// The dot of the wordmark.
  Color get wordmarkDot => isDark ? _p.dotDark : _p.dot;

  /// Halo under the main button.
  Color get glow => _p.glow;

  /// Theme of the closest `BirdyTheme`; the Loriot look on other themes
  /// (upstream high-contrast, dynamic color, bare test themes).
  static BirdyBrandColors of(BuildContext context) =>
      fromTheme(Theme.of(context));

  static BirdyBrandColors fromTheme(ThemeData theme) =>
      theme.extension<BirdyBrandColors>() ??
      BirdyBrandColors(BirdyBird.loriot, theme.brightness);

  @override
  BirdyBrandColors copyWith({BirdyBird? bird, Brightness? brightness}) =>
      BirdyBrandColors(bird ?? this.bird, brightness ?? this.brightness);

  /// Themes are discrete: no in-between colors, the switch happens at half.
  @override
  BirdyBrandColors lerp(ThemeExtension<BirdyBrandColors>? other, double t) =>
      other is! BirdyBrandColors || t < 0.5 ? this : other;

  @override
  bool operator ==(Object other) =>
      other is BirdyBrandColors &&
      other.bird == bird &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(bird, brightness);
}
