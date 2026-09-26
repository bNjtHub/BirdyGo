/// BirdyGo design tokens (J6a): brand palette, light and dark theme colors,
/// reliability colors, radii, spacing and sizes.
///
/// Values come from fork/DESIGN.md and fork/maquette/SPEC.md (section 2).
/// Widgets read colors with [BirdyColors.of], never with raw hex values.
library;

import 'package:flutter/material.dart';

import '../reliability/reliability_config.dart';

/// Brand colors named in fork/DESIGN.md.
abstract final class BirdyBrand {
  /// Encre de nuit: dark background, text on light.
  static const Color ink = Color(0xFF13233A);

  /// Brume: light background, text on dark.
  static const Color mist = Color(0xFFEEF1EC);

  /// Martin-pêcheur: fills of actions (Écouter, play).
  static const Color kingfisher = Color(0xFF19A7B3);

  /// Loriot: novelty and rarity.
  static const Color oriole = Color(0xFFF4C542);

  /// Lichen: confirmed, level Sûr.
  static const Color lichen = Color(0xFF9DB46A);

  /// Écorce: secondary text on light.
  static const Color bark = Color(0xFF6B5847);

  /// Background of the spectrogram well (both themes).
  static const Color wellTop = Color(0xFF0B1728);
  static const Color wellBottom = Color(0xFF0F1E33);
}

/// Foreground and background of one reliability level.
@immutable
class LevelColors {
  const LevelColors({
    required this.foreground,
    required this.background,
    this.dashed = false,
  });

  final Color foreground;
  final Color background;

  /// "À vérifier" is the only outlined (dashed) badge.
  final bool dashed;

  static LevelColors lerp(LevelColors a, LevelColors b, double t) =>
      LevelColors(
        foreground: Color.lerp(a.foreground, b.foreground, t)!,
        background: Color.lerp(a.background, b.background, t)!,
        dashed: t < 0.5 ? a.dashed : b.dashed,
      );
}

/// Theme colors of BirdyGo, light ("carnet") and dark ("écoute").
///
/// Translucent values (line, border, veil) are kept as in the spec so they
/// sit well on any surface; the [ColorScheme] uses their opaque blends.
@immutable
class BirdyColors extends ThemeExtension<BirdyColors> {
  const BirdyColors({
    required this.brightness,
    required this.background,
    required this.backgroundDeep,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.border,
    required this.borderStrong,
    required this.dashed,
    required this.text1,
    required this.text2,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.tonal,
    required this.navIndicator,
    required this.oriole,
    required this.onOriole,
    required this.orioleText,
    required this.orioleContainer,
    required this.rarityMuted,
    required this.veil,
    required this.sure,
    required this.probable,
    required this.toCheck,
  });

  final Brightness brightness;

  /// Screen background.
  final Color background;

  /// Bottom control bar (dark); same as [background] on light.
  final Color backgroundDeep;

  /// Rows, cards, tiles (elevation = lighter surface, no grey shadow).
  final Color surface1;

  /// Raised pills, selected row.
  final Color surface2;

  /// Toast.
  final Color surface3;

  /// Separators, tracks.
  final Color line;

  /// Chips, icon buttons, outlines.
  final Color border;

  /// Secondary buttons.
  final Color borderStrong;

  /// Mystery cards (1.5 px dashed).
  final Color dashed;

  /// Main text.
  final Color text1;

  /// Secondary text and quiet icons.
  final Color text2;

  /// Martin-pêcheur fill of actions.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Martin-pêcheur for text and icons on this theme's surfaces (AA).
  final Color accentText;

  /// Tonal buttons.
  final Color tonal;

  /// Active item of the bottom navigation.
  final Color navIndicator;

  /// Loriot fill (Première fois, Nouveau).
  final Color oriole;

  /// Text on [oriole].
  final Color onOriole;

  /// Loriot-colored text on this theme's surfaces (AA).
  final Color orioleText;

  /// Background of Loriot chips ("Inattendu ici").
  final Color orioleContainer;

  /// "Peu commun" mark.
  final Color rarityMuted;

  /// Layer behind moments.
  final Color veil;

  final LevelColors sure;
  final LevelColors probable;
  final LevelColors toCheck;

  bool get isDark => brightness == Brightness.dark;

  /// Colors of a reliability level.
  LevelColors level(ReliabilityLevel level) => switch (level) {
    ReliabilityLevel.sure => sure,
    ReliabilityLevel.probable => probable,
    ReliabilityLevel.toCheck => toCheck,
  };

  /// Opaque [line] on [background], for widgets that need a solid color.
  Color get lineOpaque => Color.alphaBlend(line, background);

  /// Opaque [border] on [background].
  Color get borderOpaque => Color.alphaBlend(border, background);

  /// Shadow of floating layers only (sheet, review card stack).
  List<BoxShadow> get floatShadow => const [
    BoxShadow(color: Color(0x2413233A), offset: Offset(0, 8), blurRadius: 28),
  ];

  /// Glow of the big « Écouter » button only.
  List<BoxShadow> get ctaGlow => const [
    BoxShadow(color: Color(0x5919A7B3), offset: Offset(0, 10), blurRadius: 28),
  ];

  /// Light theme (notebook), SPEC.md 2.3.
  static const BirdyColors light = BirdyColors(
    brightness: Brightness.light,
    background: BirdyBrand.mist,
    backgroundDeep: BirdyBrand.mist,
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFFFFF),
    surface3: Color(0xFFFFFFFF),
    line: Color(0xFFDCE2DA),
    border: Color(0xFFC5CCC2),
    borderStrong: Color(0xFFC5CCC2),
    dashed: Color(0xFFB9C0B5),
    text1: BirdyBrand.ink,
    text2: BirdyBrand.bark,
    accent: BirdyBrand.kingfisher,
    onAccent: BirdyBrand.ink,
    // DESIGN.md's #0E7C86 only reaches 4.3:1 on Brume (J6a decision).
    accentText: Color(0xFF0B6E77),
    tonal: Color(0xFFD6EEF0),
    navIndicator: Color(0xFFD1ECEF),
    oriole: BirdyBrand.oriole,
    onOriole: BirdyBrand.ink,
    orioleText: Color(0xFF7A5A00),
    orioleContainer: Color(0xFFFBEFC8),
    rarityMuted: BirdyBrand.bark,
    veil: Color(0xC70C1829),
    sure: LevelColors(
      foreground: Color(0xFF4B6023),
      background: Color(0xFFE6EDD6),
    ),
    probable: LevelColors(
      foreground: Color(0xFF34495E),
      background: Color(0xFFE3E9EF),
    ),
    toCheck: LevelColors(
      foreground: Color(0xFFA04A1C),
      background: Color(0xFFFFFFFF),
      dashed: true,
    ),
  );

  /// Dark theme (listening and moments), SPEC.md 2.2.
  static const BirdyColors dark = BirdyColors(
    brightness: Brightness.dark,
    background: BirdyBrand.ink,
    backgroundDeep: Color(0xFF0F1D31),
    surface1: Color(0xFF1A2D47),
    surface2: Color(0xFF213852),
    surface3: Color(0xFF29425F),
    line: Color(0x14EEF1EC),
    border: Color(0x24EEF1EC),
    borderStrong: Color(0x52EEF1EC),
    dashed: Color(0x52EEF1EC),
    text1: BirdyBrand.mist,
    text2: Color(0xFFB4C0CC),
    accent: BirdyBrand.kingfisher,
    onAccent: BirdyBrand.ink,
    accentText: Color(0xFF4FC3CC),
    tonal: Color(0x2919A7B3),
    navIndicator: Color(0xFF213852),
    oriole: BirdyBrand.oriole,
    onOriole: BirdyBrand.ink,
    orioleText: BirdyBrand.oriole,
    orioleContainer: Color(0x29F4C542),
    rarityMuted: Color(0xFFC9B8A4),
    veil: Color(0xC70C1829),
    sure: LevelColors(
      foreground: Color(0xFFB7CF83),
      background: Color(0x339DB46A),
    ),
    probable: LevelColors(
      foreground: Color(0xFFC9D3DD),
      background: Color(0x1FC9D3DD),
    ),
    toCheck: LevelColors(
      foreground: Color(0xFFF2A677),
      background: Color(0x00000000),
      dashed: true,
    ),
  );

  /// Tokens of the current theme. Falls back to the brightness-matching set
  /// when the theme carries none (upstream high-contrast or dynamic themes).
  static BirdyColors of(BuildContext context) => fromTheme(Theme.of(context));

  /// [ThemeData]-based companion to [of].
  static BirdyColors fromTheme(ThemeData theme) =>
      theme.extension<BirdyColors>() ??
      (theme.brightness == Brightness.dark ? dark : light);

  /// Tokens are fixed per theme: use [light] or [dark].
  @override
  BirdyColors copyWith() => this;

  @override
  BirdyColors lerp(ThemeExtension<BirdyColors>? other, double t) {
    if (other is! BirdyColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BirdyColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      backgroundDeep: c(backgroundDeep, other.backgroundDeep),
      surface1: c(surface1, other.surface1),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      line: c(line, other.line),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      dashed: c(dashed, other.dashed),
      text1: c(text1, other.text1),
      text2: c(text2, other.text2),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentText: c(accentText, other.accentText),
      tonal: c(tonal, other.tonal),
      navIndicator: c(navIndicator, other.navIndicator),
      oriole: c(oriole, other.oriole),
      onOriole: c(onOriole, other.onOriole),
      orioleText: c(orioleText, other.orioleText),
      orioleContainer: c(orioleContainer, other.orioleContainer),
      rarityMuted: c(rarityMuted, other.rarityMuted),
      veil: c(veil, other.veil),
      sure: LevelColors.lerp(sure, other.sure, t),
      probable: LevelColors.lerp(probable, other.probable, t),
      toCheck: LevelColors.lerp(toCheck, other.toCheck, t),
    );
  }
}

/// Corner radii (SPEC.md 2.8).
abstract final class BirdyRadii {
  /// Hero and celebration cards, sheet top corners, fiche header.
  static const double hero = 28;

  /// Cards, rows, tiles.
  static const double card = 20;

  /// Insets (mini spectrum, mini map).
  static const double inset = 16;

  /// Small thumbnails.
  static const double thumb = 12;

  /// Buttons, chips, badges, pills, rings.
  static const double pill = 999;
}

/// Spacing scale (SPEC.md 2.8).
abstract final class BirdySpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Page gutter on light screens.
  static const double gutter = 20;

  /// Header gutter on dark screens.
  static const double gutterDark = 16;

  /// Gutter of the live list.
  static const double gutterLive = 8;
}

/// Component sizes (SPEC.md 2.8).
abstract final class BirdySizes {
  /// Minimum touch target.
  static const double target = 48;

  /// Main action button.
  static const double mainAction = 56;

  /// Big « Écouter » button.
  static const double listen = 72;

  /// « Arrêter » and « Pause » in the live control bar.
  static const double liveControl = 64;

  static const double navBar = 80;
  static const double topBar = 56;

  /// Minimum height of badges and pills (they grow with text scale).
  static const double pill = 26;

  /// Minimum height of a live row, and of a compact row.
  static const double row = 72;
  static const double rowCompact = 60;

  /// Spectrum heights: reduced strip, normal band, expanded plot.
  static const double spectrumReduced = 56;
  static const double spectrumNormal = 120;
  static const double spectrumExpanded = 450;
}
