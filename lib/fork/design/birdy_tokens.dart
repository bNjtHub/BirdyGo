/// BirdyGo design tokens (J6a): brand palette, light and dark theme colors,
/// reliability colors, radii, spacing and sizes.
///
/// Values come from fork/DESIGN.md and fork/maquette/SPEC.md (section 2).
/// Widgets read colors with [BirdyColors.of], never with raw hex values.
library;

import 'package:flutter/material.dart';

import '../reliability/reliability_config.dart';
import 'birdy_theme_choice.dart';

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

  /// Small "current level" check badge on the Profil ladder (J6f), both
  /// themes: real metal green, not a theme token.
  static const Color checkGreen = Color(0xFF3E8E4F);

  /// Faint radial highlight over the well (Quiz v2 mockup's hero and stage).
  static const Color wellHighlight = Color(0xFF173A55);

  /// The light blue bar of the logo's wing (fork/brand/birdygo-logo.svg).
  static const Color wingSky = Color(0xFF8CD3D9);

  /// Soft shadow of the wing icon (J6h): dark teal at 45 %.
  static const Color wingShadow = Color(0x730B3C46);

  /// Pure white and black, for marks on photos and painted highlights.
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// Black at 38 % (thin outline of the fiche grab handle on any photo).
  static const Color black38 = Color(0x61000000);

  /// Fully transparent black (gradient and shimmer end stops).
  static const Color clear = Color(0x00000000);

  /// Soft black shadow, 25 %.
  static const Color shadowSoft = Color(0x40000000);

  /// [wellHighlight] faded to transparent (quiz stage glow end stop).
  static const Color wellHighlightClear = Color(0x00173A55);

  /// Light-theme track of the splash progress arcs (Encre at 8 %).
  static const Color splashTrackLight = Color(0x1413233A);

  /// Unselected rim of a quiz answer dot in the light theme.
  static const Color mistTrack = Color(0xFFE1E5DE);
}

/// Colors of the shared confetti (`BirdyConfetti`, J6e quiz, J6f moments),
/// the same in both themes.
abstract final class BirdyConfettiColors {
  /// Rain over a good quiz score.
  static const List<Color> rain = [
    BirdyBrand.oriole,
    BirdyBrand.kingfisher,
    BirdyBrand.lichen,
    Color(0xFFEC7A3C),
    Color(0xFF3B8FDB),
    Color(0xFFE9836B),
  ];

  /// Burst from a bird or an emblem, besides its own colors.
  static const List<Color> burst = [
    BirdyBrand.oriole,
    BirdyBrand.kingfisher,
    BirdyBrand.lichen,
  ];

  /// Golden burst of a confirmed rare bird (J6h).
  static const List<Color> rare = [
    BirdyBrand.oriole,
    Color(0xFFE3A22B),
    Color(0xFFFFE9A0),
    BirdyBrand.kingfisher,
  ];

  // The kingfisher entry of each list is the accent slot: the lists below
  // swap it for the active bird's accent (oriole and lichen stay fixed).
  static List<Color> _follow(List<Color> colors, Color accent) => [
    for (final c in colors) c == BirdyBrand.kingfisher ? accent : c,
  ];

  /// [rain] with the active bird's accent.
  static List<Color> rainOf(BuildContext context) =>
      _follow(rain, BirdyBrandColors.of(context).accent);

  /// [burst] with the active bird's accent.
  static List<Color> burstOf(BuildContext context) =>
      _follow(burst, BirdyBrandColors.of(context).accent);

  /// [rare] with the active bird's accent.
  static List<Color> rareOf(BuildContext context) =>
      _follow(rare, BirdyBrandColors.of(context).accent);
}

/// Colors of the « Qui chante ? » quiz (J6e, Quiz v2 mockup) that are not
/// theme tokens: the equalizer bars on the dark well and the small marks of
/// the round's recap. Its confetti use [BirdyConfettiColors].
abstract final class BirdyQuizColors {
  /// Equalizer bars, from the deepest to the lightest Martin-pêcheur shade.
  static const Color bar1 = Color(0xFF52C0C9);
  static const Color bar2 = Color(0xFF79D0D7);
  static const Color bar3 = Color(0xFFA8E2E6);
  static const Color bar4 = Color(0xFFDDF4F5);

  /// Bars left of the play button, then right of it.
  static const List<Color> barsLeft = [bar1, bar3, BirdyBrand.oriole];
  static const List<Color> barsRight = [bar4, bar2, bar1];

  /// The five bars under the mystery bird on the intro.
  static const List<Color> barsIntro = [
    bar4,
    BirdyBrand.oriole,
    bar3,
    bar2,
    bar1,
  ];

  /// Cross mark of a missed bird in the recap, light and dark.
  static const Color missedLight = Color(0xFF9AA39A);
  static const Color missedDark = Color(0xFF6E7A86);

  /// Knob of the sound switch, and its shadow.
  static const Color knob = Color(0xFFFFFFFF);
  static const Color knobShadow = Color(0x4013233A);

  /// Mystery silhouette brightened as in the mockup (CSS brightness 2.2).
  static const double mysteryBrightness = 2.2;

  /// Sparks, twinkles and star burst particles on the intro hero, the
  /// result and a right reveal (Quiz v2 mockup).
  static const List<Color> sparkColors = [
    BirdyBrand.oriole,
    BirdyBrand.kingfisher,
    BirdyBrand.lichen,
    Color(0xFFEC7A3C),
    Color(0xFF5AA9E6),
    Color(0xFFE9836B),
  ];

  /// Rim of an earned result star (a shaded gold), both themes.
  static const Color starRim = Color(0xFFC49224);
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
    required this.progressTrack,
    required this.dashed,
    required this.text1,
    required this.text2,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.tonal,
    required this.navIndicator,
    required this.glow,
    required this.oriole,
    required this.onOriole,
    required this.orioleText,
    required this.orioleContainer,
    required this.rarityMuted,
    required this.veil,
    required this.sure,
    required this.probable,
    required this.toCheck,
    required this.skeleton,
    required this.skeletonSheen,
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

  /// Empty part of a progress bar and idle step dots. Darker than
  /// [borderStrong] in the dark theme, so the fill keeps 3:1 (WCAG 1.4.11).
  final Color progressTrack;

  /// Mystery cards (1.5 px dashed).
  final Color dashed;

  /// Main text.
  final Color text1;

  /// Secondary text and quiet icons.
  final Color text2;

  /// Fill of actions (the bird theme's brand color, J6i).
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Brand color for text and icons on this theme's surfaces (AA).
  final Color accentText;

  /// Tonal buttons.
  final Color tonal;

  /// Active item of the bottom navigation.
  final Color navIndicator;

  /// Halo under the big « Écouter » buttons: [accent] at 35 %.
  final Color glow;

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

  /// Muted fill of a loading skeleton.
  final Color skeleton;

  /// Light band sweeping over the skeletons (the shimmer, `BirdyShimmer`):
  /// translucent, painted over [skeleton]. Static fill with reduced motion.
  final Color skeletonSheen;

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
  List<BoxShadow> get ctaGlow => [
    BoxShadow(color: glow, offset: const Offset(0, 10), blurRadius: 28),
  ];

  /// Glow of the home « Écouter » button: centered around it and at most
  /// [listenGlowExtent] past its edge, so it fits the equal margins above
  /// the bottom bar without being cut.
  List<BoxShadow> get listenGlow => [
    BoxShadow(color: glow, offset: const Offset(0, 4), blurRadius: 16),
  ];

  /// How far [listenGlow] reaches below the button (offset + blur).
  static const double listenGlowExtent = 20;

  /// Light theme (notebook), SPEC.md 2.3. Accent roles are the Loriot bird's
  /// (the default); [forBird] gives the other birds.
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
    progressTrack: Color(0xFFDCE2DA),
    dashed: Color(0xFFB9C0B5),
    text1: BirdyBrand.ink,
    text2: BirdyBrand.bark,
    accent: BirdyBrand.kingfisher,
    onAccent: BirdyBrand.ink,
    // DESIGN.md's #0E7C86 only reaches 4.3:1 on Brume (J6a decision).
    accentText: Color(0xFF0B6E77),
    tonal: Color(0xFFD6EEF0),
    navIndicator: Color(0xFFD1ECEF),
    glow: Color(0x5919A7B3),
    oriole: BirdyBrand.oriole,
    onOriole: BirdyBrand.ink,
    orioleText: Color(0xFF7A5A00),
    orioleContainer: Color(0xFFFBEFC8),
    rarityMuted: BirdyBrand.bark,
    veil: Color(0xC70C1829),
    skeleton: Color(0xFFD6DCD2),
    skeletonSheen: Color(0x8CFFFFFF),
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
    progressTrack: Color(0x24EEF1EC),
    dashed: Color(0x52EEF1EC),
    text1: BirdyBrand.mist,
    text2: Color(0xFFB4C0CC),
    accent: BirdyBrand.kingfisher,
    onAccent: BirdyBrand.ink,
    accentText: Color(0xFF4FC3CC),
    tonal: Color(0x2919A7B3),
    navIndicator: Color(0xFF213852),
    glow: Color(0x5919A7B3),
    oriole: BirdyBrand.oriole,
    onOriole: BirdyBrand.ink,
    orioleText: BirdyBrand.oriole,
    orioleContainer: Color(0x29F4C542),
    rarityMuted: Color(0xFFC9B8A4),
    veil: Color(0xC70C1829),
    skeleton: Color(0xFF29425F),
    skeletonSheen: Color(0x1FFFFFFF),
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

  /// Tokens of [bird] in [brightness]: [light] or [dark] with the brand
  /// roles (accent, accentText, tonal, navIndicator, glow) of the bird
  /// ([BirdyBrandColors]). Everything else is the same for every bird.
  static BirdyColors forBird(BirdyBird bird, Brightness brightness) {
    final base = brightness == Brightness.dark ? dark : light;
    // Loriot is the original set (a test checks it equals its brand roles).
    if (bird == BirdyBird.loriot) return base;
    return base._withBrand(BirdyBrandColors(bird, brightness));
  }

  BirdyColors _withBrand(BirdyBrandColors b) => BirdyColors(
    brightness: brightness,
    background: background,
    backgroundDeep: backgroundDeep,
    surface1: surface1,
    surface2: surface2,
    surface3: surface3,
    line: line,
    border: border,
    borderStrong: borderStrong,
    progressTrack: progressTrack,
    dashed: dashed,
    text1: text1,
    text2: text2,
    accent: b.accent,
    onAccent: onAccent,
    accentText: b.accentText,
    tonal: b.tonal,
    navIndicator: b.navIndicator,
    glow: b.glow,
    oriole: oriole,
    onOriole: onOriole,
    orioleText: orioleText,
    orioleContainer: orioleContainer,
    rarityMuted: rarityMuted,
    veil: veil,
    sure: sure,
    probable: probable,
    toCheck: toCheck,
    skeleton: skeleton,
    skeletonSheen: skeletonSheen,
  );

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
      progressTrack: c(progressTrack, other.progressTrack),
      dashed: c(dashed, other.dashed),
      text1: c(text1, other.text1),
      text2: c(text2, other.text2),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentText: c(accentText, other.accentText),
      tonal: c(tonal, other.tonal),
      navIndicator: c(navIndicator, other.navIndicator),
      glow: c(glow, other.glow),
      oriole: c(oriole, other.oriole),
      onOriole: c(onOriole, other.onOriole),
      orioleText: c(orioleText, other.orioleText),
      orioleContainer: c(orioleContainer, other.orioleContainer),
      rarityMuted: c(rarityMuted, other.rarityMuted),
      veil: c(veil, other.veil),
      skeleton: c(skeleton, other.skeleton),
      skeletonSheen: c(skeletonSheen, other.skeletonSheen),
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

  /// Small skeleton blocks and inline chips.
  static const double chip = 8;

  /// Tick marks and tiny bars.
  static const double xs = 2;

  /// Small pill ends and thin bars.
  static const double s = 3;

  /// Buttons, chips, badges, pills, rings.
  static const double pill = 999;
}

/// Blur radii of drop shadows.
abstract final class BirdyBlur {
  static const double s = 3;
  static const double m = 8;
  static const double l = 16;
  static const double xl = 18;
}

/// Line and border widths.
abstract final class BirdyStroke {
  static const double hairline = 1;
  static const double thin = 1.5;
  static const double regular = 2;
  static const double medium = 2.5;
  static const double thick = 3;
  static const double chunky = 4;
}

/// Icon glyph and avatar sizes.
abstract final class BirdyGlyph {
  static const double xxs = 12;
  static const double xs = 13;
  static const double s = 14;
  static const double m = 16;
  static const double l = 18;
  static const double xl = 20;
  static const double xxl = 22;
  static const double x3l = 24;
  static const double x4l = 26;
  static const double x5l = 28;
  static const double x6l = 30;

  /// Round icons and avatars, by diameter.
  static const double disc36 = 36;
  static const double disc40 = 40;
  static const double disc44 = 44;
  static const double disc48 = 48;
  static const double disc56 = 56;
  static const double disc72 = 72;
  static const double disc96 = 96;
  static const double disc136 = 136;
}

/// Spacing scale (SPEC.md 2.8).
abstract final class BirdySpace {
  /// Side gutter of the splash footer.
  static const double splashSide = 28;

  /// Half-steps of the scale, from a hairline to the wide gap.
  static const double hairline = 1;
  static const double xxs = 2;
  static const double thin = 3;
  static const double tight = 5;
  static const double snug = 6;
  static const double slim = 7;
  static const double cozy = 10;
  static const double comfy = 14;
  static const double roomy = 18;
  static const double wide = 22;

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Extra gap between the wing icon and the label of « Écouter » buttons,
  /// on top of the 4 to 8 the button already puts (the bars read tight).
  static const double wingLabelGap = s;

  /// Page gutter on light screens.
  static const double gutter = 20;

  /// Header gutter on dark screens.
  static const double gutterDark = 16;

  /// Gutter of the live list.
  static const double gutterLive = 8;

  /// Page margin of the block layout (J6f, « App finale » boards).
  static const double page = 16;

  /// Gap between two blocks (J6f).
  static const double block = 10;
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

  /// « Écouter » disc in the middle of the bar (J6j): its diameter, the rim
  /// in the bar's color around it, and how far it overhangs the bar's top
  /// edge.
  static const double listenDisc = 68;
  static const double listenDiscRim = 4;
  static const double listenDiscLift = 22;

  /// Fade at the bottom of a list that runs behind the bar (J6j).
  static const double listFade = 28;
  static const double topBar = 56;

  /// Disc and icon of an alert block (volume alert, J6h).
  static const double alertDisc = 44;
  static const double alertDiscIcon = 22;

  /// Blur sigma behind the floating volume toast.
  static const double alertBlurSigma = 12;

  /// Minimum height of badges and pills (they grow with text scale).
  static const double pill = 26;

  /// Skeleton tag widths (pill-shaped placeholders in headers).
  static const double skeletonTagS = 64;
  static const double skeletonTagM = 88;
  static const double skeletonTagL = 110;

  /// Sample tile width in the design gallery.
  static const double gallerySample = 140;

  /// Activity bars of the species page: 24 monthly bars and the hourly ones.
  static const double activityBarsWidth = 150;
  static const double activityBarsHeight = 45;
  static const double hourBarsHeight = 52;

  /// Clip spectrogram height in the quick review.
  static const double clipSpectrogram = 80;

  /// Contact map: fit padding (sides, top under the header, bottom) and
  /// cluster bubble size and padding.
  static const double mapFitSide = 48;
  static const double mapFitTop = 120;
  static const double mapFitBottom = 48;
  static const double mapClusterSize = 60;
  static const double mapClusterPadding = 50;

  /// Hero bird of the quiz intro (before the screen-height scale).
  static const double quizIntroBird = 128;

  /// Toggle switch: track size and knob diameter.
  static const double switchWidth = 44;
  static const double switchHeight = 28;
  static const double switchKnob = 22;

  /// Minimum height of a live row, and of a compact row.
  static const double row = 72;

  /// Tinted disc leading a list row (J6h [BirdyListRow]).
  static const double rowDisc = 44;

  /// Bird-choice disc of the onboarding (J6i): the themed logo in a tonal
  /// disc, its white halo, the logo's width inside it, and the smaller disc
  /// of a picker card.
  static const double themeLogoDisc = 132;
  static const double themeLogoHalo = 8;
  static const double themeLogoMark = 88;
  static const double themeCardDisc = 72;
  static const double themeCardMark = 48;

  /// Icon of the onboarding call-to-action, small inline icons (lock, check)
  /// and the logo of the « Mon oiseau » row disc.
  static const double ctaIcon = 24;
  static const double inlineIcon = 16;
  static const double myBirdRowMark = 28;

  /// Launcher-icon preview of the picker, and the logo inside it.
  static const double iconPreview = 60;
  static const double iconPreviewMark = 42;
  static const double iconPreviewRadius = 15;

  /// Ring around the chosen picker card, its check badge and its colour dots.
  static const double themeRing = 3;
  static const double themeCheck = 24;
  static const double themeDot = 14;

  /// White disc of the sound library hero (J6h).
  static const double soundHeroDisc = 76;

  /// Species-tint disc leading a species page block title, and its icon.
  static const double sectionDisc = 36;
  static const double sectionIcon = 20;

  /// Knowledge disc of the species page's « Faire connaissance » block.
  static const double knowledgeDisc = 52;

  /// Ring around the chosen knowledge disc (white gap, then color), each
  /// this wide.
  static const double knowledgeRing = 2;

  /// Read check in the corner of a knowledge disc.
  static const double knowledgeCheck = 18;

  /// Watermark icon of the knowledge card, and the thin segments under it.
  static const double knowledgeWatermark = 88;
  static const double knowledgeSegment = 6;
  static const double rowCompact = 60;

  /// Minimum height of a collection card (notebook grid of 3).
  static const double collectionCard = 168;

  /// Spectrum heights: reduced strip, normal band, expanded plot.
  static const double spectrumReduced = 56;
  static const double spectrumNormal = 120;
  static const double spectrumExpanded = 450;

  /// Progress ring of a block (daily goal), and its stroke.
  static const double ring = 76;

  /// Ring of the daily goal hero (J6h), and the avatar of a list row.
  static const double dailyGoalRing = 120;
  static const double rowAvatar = 48;
  static const double ringStroke = 8;

  /// Progress bar of a block (status, notebook).
  static const double progressBar = 8;

  /// Countdown bar of a first-encounter card (J6h).
  static const double countdownBar = 6;

  /// Current dot of a series (its length), and the icon after a main
  /// button's label (« Espèce suivante »).
  static const double countdownDotActive = 18;
  static const double buttonIcon = 22;

  /// Day dot of the série (7 per week).
  static const double dayDot = 14;

  /// Outline of a day dot without listening.
  static const double dayDotStroke = 2;

  /// Small icon in a block's corner (« À vérifier »).
  static const double blockIcon = 20;

  /// Dashed silhouette slot of a species still to find (daily goal block,
  /// empty live state uses [expectedSlot]).
  static const double goalSlot = 36;

  /// Grey species visual inside a [goalSlot].
  static const double goalSlotVisual = 26;
  static const double expectedSlot = 52;

  /// Tinted species card of a scrolling row (home « Aujourd'hui »).
  static const double speciesChipCard = 92;

  /// Species visual of a [speciesChipCard].
  static const double speciesChipAvatar = 56;

  /// Hero block (« Dernier oiseau entendu »): minimum height, decorative
  /// disc behind the bird, and the bird itself.
  static const double heroMinHeight = 196;
  static const double heroDisc = 176;
  static const double heroBird = 120;

  /// Status disc of the status block.
  static const double statusDisc = 52;

  /// Ring of the home level block (J6g-b), the Profil ring's little sibling.
  static const double homeLevelRing = 72;

  /// Ring of the notebook progress block (J6g-b).
  static const double notebookRing = 88;

  /// Species visual of a notebook card (two-column grid, J6h).
  static const double notebookVisual = 88;

  /// White fade on the right edge of a scrolling chip row (J6h).
  static const double chipFade = 40;

  /// Grey mini-silhouette in the notebook hero caption (J6h).
  static const double notebookHeroSilhouette = 16;

  /// Small icon disc leading a block (weekly challenge).
  static const double blockIconDisc = 40;

  /// Icon of a one-line tip (empty live table).
  static const double tipIcon = 18;

  /// Illustration disc of the « Qui chante ? » block on the Profil, and the
  /// Loriot question mark pinned on its corner.
  static const double quizDisc = 60;
  static const double quizDiscBadge = 24;

  /// The quiz entry's logo (J6f, [QuizLogo]), the Profil quiz row.
  static const double quizLogo = 56;

  /// « Qui chante ? » (J6h): the intro's illustrated zone (the intro fits a
  /// 844 pt phone without scrolling), the mystery bird's « ? » on the wing,
  /// and the [QuizLogo] disc of the « Arrêter la partie ? » sheet.
  static const double quizIntroHero = 210;
  static const double quizIntroHeroFloor = 168;
  static const double quizIntroHeroMin = 150;

  /// Height of the intro besides the illustrated zone and its variable gaps,
  /// at font scale 1 (measured), and a few points of safety.
  static const double quizIntroRest = 358;
  static const double quizIntroSlack = 4;
  static const double quizMark = 30;

  /// Silhouette sizes: the logo's wing shows from this size on a species,
  /// the mystery « ? » from this size on a mystery bird (below, plain).
  static const double silhouetteWingMin = 32;
  static const double silhouetteMarkMin = 20;
  static const double quizSheetDisc = 72;

  /// Level ladder (J6f, Profil « Mon niveau »): emblem, cell and the small
  /// check badge on the current one.
  static const double levelEmblem = 48;
  static const double levelCellMinHeight = 84;

  /// Ladder connector strokes sit between emblems: each is the cell width
  /// minus this inset, and the cell's vertical padding plus half the emblem
  /// centers them on it.
  static const double levelLineInset = 48;
  static const double levelCellPadTop = 8;
  static const double levelLineThick = 4;
  static const double levelLineThin = 2;
  static const double levelCheckBadge = 20;

  /// Icon disc leading the level info box and a weekly challenge inset.
  static const double levelInfoIcon = 44;

  /// A segmented bar's bar height and the gap between bars (level info box,
  /// weekly challenge).
  static const double segmentHeight = 12;
  static const double segmentGap = 3;

  /// Above this many segments, a segmented bar falls back to one continuous
  /// [BirdyProgressBar] (too many slivers to read).
  static const int segmentBarMax = 25;

  /// Minimum height of a badge tile (Profil « À gagner »).
  static const double badgeTile = 136;

  /// Listening logo (J6f, J6h): in the live header, and small in front of
  /// « L'écoute continue » on the first-encounter card.
  static const double liveLogo = 24;
  static const double liveLogoSmall = 18;

  /// Sparkle popping around the bird of a first encounter (J6h).
  static const double sparkle = 20;

  /// Bird picture of the moment cards (first encounter, rare bird).
  static const double momentAvatar = 96;

  /// Room the dotted ring of the rare card leaves around the picture, its
  /// stroke and its dash and gap.
  static const double rareRingGap = 10;
  static const double rareRingStroke = 2.5;
  static const double rareRingDash = 5;
  static const double rareRingDashGap = 4;

  /// Height of the moment area under which a card tightens its gaps.
  static const double momentCompactBelow = 620;

  /// Mode icon inline before the mode word in the live status line (J6f).
  static const double statusModeIcon = 14;
}

/// Text and icon colors of each listening mode (J6f, `lib/fork/listening_mode`),
/// distinct in hue and lightness so the mode reads at a glance: Martin-pêcheur
/// for Normal, a Lichen green for Vent, Loriot for Boost, a rose for Ville.
/// Each value reaches 4.5:1 on the live dark background, the options sheet
/// surfaces (`surface1`-`surface3`) and their light theme counterparts
/// (`test/fork/design/contrast_test.dart`).
abstract final class ListeningModeColors {
  /// Same value as [BirdyColors.accentText] (Loriot bird): Normal is the
  /// plain, always-on setting, so it borrows the app's action color rather
  /// than a new one. The mode's color follows the chosen bird
  /// (`listeningModeColor` reads [BirdyColors.accentText]); these are the
  /// Loriot values, kept for the contrast test.
  static const Color normalLight = Color(0xFF0B6E77);
  static const Color normalDark = Color(0xFF4FC3CC);

  /// Lichen-based green, distinct in hue from Normal's teal.
  static const Color windLight = Color(0xFF4B6023);
  static const Color windDark = Color(0xFFB7CF83);

  /// Same value as [BirdyColors.orioleText]: Boost raises the gain, close
  /// enough to Loriot's "more" meaning.
  static const Color boostLight = Color(0xFF7A5A00);
  static const Color boostDark = Color(0xFFF4C542);

  /// Rose, for Ville: the fourth hue, distinct from teal, green and gold.
  static const Color cityLight = Color(0xFF8A2F45);
  static const Color cityDark = Color(0xFFF0A5AE);
}

/// Opacities of layered block details (J6f). Colors themselves come from
/// [BirdyColors] or the species tint.
abstract final class BirdyAlpha {
  /// Decorative disc of the species accent behind the hero bird.
  static const double heroDisc = 0.18;

  /// White halo around the onboarding's bird disc.
  static const double themeHalo = 0.7;

  /// White fill of a dashed slot on a tonal block.
  static const double slotFill = 0.55;

  /// White track of a bar or ring on a tinted block.
  static const double trackOnTint = 0.8;

  /// Brume track of a bar or ring on a tinted block, dark theme.
  static const double trackOnTintDark = 0.16;

  /// Outline of a day dot without listening (série block).
  static const double dayDotOutline = 0.45;

  /// [BirdyColors.surface1] of an expected species row in the empty live
  /// table (it is not there yet).
  static const double expectedRow = 0.55;

  /// Big watermark icon of the species page's knowledge card.
  static const double knowledgeWatermark = 0.12;

  /// Thin inner white ring on a reached level emblem/ring (J6f).
  static const double emblemInnerRing = 0.5;

  /// Scrim behind the photo credit button on a species photo.
  static const double photoButtonScrim = 0.45;
}

/// Contact map markers (J6g-f). The map tiles stay light in both themes, so
/// the marker disc and its ring do not follow the theme: they must read on
/// any tile, and on the dark placeholder shown before tiles are allowed.
abstract final class BirdyMapStyle {
  /// Radius of a contact point dot on the species mini map.
  static const double pointRadius = 5;

  /// Disc under a species photo and border of the cluster bubble.
  static const Color disc = Color(0xFFFFFFFF);

  /// Soft drop shadow under a marker (Encre at 18 %).
  static const Color shadow = Color(0x2E13233A);

  /// Contact-count badge (Encre with Brume text: 14:1 on any tile).
  static const Color badge = BirdyBrand.ink;
  static const Color onBadge = BirdyBrand.mist;

  /// Text on the Martin-pêcheur cluster disc.
  static const Color onCluster = BirdyBrand.ink;

  /// Species marker: disc, ring, photo and badge height.
  static const double markerDisc = 44;
  static const double markerRing = 3;
  static const double markerPhoto = 34;
  static const double badgeHeight = 22;

  /// Cluster bubble diameter and border.
  static const double cluster = 56;
  static const double clusterBorder = 3;

  /// Unit label (« espèces ») under the count in the cluster bubble.
  static const double clusterLabelSize = 13;

  /// User position dot and its border.
  static const double userDot = 14;
  static const double userDotBorder = 3;

  /// Ring around a species avatar in the map sheets.
  static const double avatarRing = 2;

  /// Shadow lifting a marker off the tiles.
  static List<BoxShadow> get lift => const [
    BoxShadow(color: shadow, offset: Offset(0, 4), blurRadius: 12),
  ];
}
