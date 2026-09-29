/// BirdyGo typography (J6a, J6i): Nunito for titles and big numbers,
/// Fraunces for species names, Atkinson Hyperlegible Next for the interface,
/// the latin names (italic) and the other numbers.
///
/// All fonts are variable and bundled in assets/fonts/ (OFL). Weight goes
/// through [TextStyle.fontWeight], which drives the `wght` axis; never put a
/// `wght` [FontVariation] in a style, it would override every later
/// `fontWeight` (bold in upstream screens included). Fraunces also needs
/// `SOFT` and `opsz`, which Flutter does not set on its own. Nunito and
/// Atkinson only need the weight.
library;

import 'package:flutter/material.dart';

/// Font family names declared in pubspec.yaml.
abstract final class BirdyFonts {
  /// Species names (and the mystery « ? »).
  static const String serif = 'Fraunces';

  /// Titles and big numbers.
  static const String rounded = 'Nunito';

  static const String sans = 'AtkinsonHyperlegibleNext';
}

/// Tracking of the large Nunito sizes (>= 26): -1 % of the font size.
const double _kLargeTracking = -0.01;

/// Text styles of the scale 34, 26, 20, 17, 15, 13 (SPEC.md 2.9).
///
/// Styles carry no color: they inherit it from the surrounding
/// [DefaultTextStyle], or take one from [BirdyColors].
abstract final class BirdyText {
  /// Font sizes of the few inline overrides (caption, emphasis, call-to-action).
  static const double captionSize = 13;
  static const double emphasisSize = 15;
  static const double ctaSize = 20;

  /// Display 34, Nunito 800.
  static const TextStyle display = TextStyle(
    fontFamily: BirdyFonts.rounded,
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: _kLargeTracking * 34,
  );

  /// Title 26, Nunito 800.
  static const TextStyle title = TextStyle(
    fontFamily: BirdyFonts.rounded,
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: _kLargeTracking * 26,
  );

  /// Heading 20, Nunito 800: section titles, card titles, top bar.
  static const TextStyle heading = TextStyle(
    fontFamily: BirdyFonts.rounded,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  /// Species name in lists, Fraunces 17.
  static const TextStyle species = TextStyle(
    fontFamily: BirdyFonts.serif,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 17)],
  );

  /// Species name in grid cards and compact rows, Fraunces 15.
  static const TextStyle speciesCompact = TextStyle(
    fontFamily: BirdyFonts.serif,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 15)],
  );

  /// Latin name in headers, Atkinson italic 17.
  static const TextStyle latin = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 17,
    height: 1.2,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Latin name in lists, Atkinson italic 15.
  static const TextStyle latinCompact = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 15,
    height: 1.2,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Body 17, Atkinson.
  static const TextStyle body = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 17,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Body 15, Atkinson.
  static const TextStyle bodyCompact = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Caption 13, Atkinson (use with text2).
  static const TextStyle caption = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// [caption] with tabular figures, for counters that tick (J6h).
  static const TextStyle captionTabular = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Label of main buttons, Atkinson bold 17.
  static const TextStyle label = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Label of the onboarding call-to-action, Atkinson bold 20 (J6i).
  static const TextStyle labelLarge = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Text typed in the onboarding name field, Atkinson bold 26 (J6i).
  static const TextStyle inputLarge = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Bird name on a picker card, Nunito 800 17 (J6i).
  static const TextStyle headingSmall = TextStyle(
    fontFamily: BirdyFonts.rounded,
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  /// Label of tonal buttons and chips, Atkinson bold 15.
  static const TextStyle labelCompact = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Badges and pills, Atkinson bold 13.
  static const TextStyle badge = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 13,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Axis labels of the charts (months, hours), Atkinson 12: the smallest
  /// size of the scale.
  static const TextStyle axisLabel = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Hero number 64, tabular figures: one per screen at most (the quiz
  /// score).
  static const TextStyle numberHero = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 64,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Number XL 34, Nunito 800, tabular figures.
  static const TextStyle numberXL = TextStyle(
    fontFamily: BirdyFonts.rounded,
    fontSize: 34,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: _kLargeTracking * 34,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Number L 26, tabular figures.
  static const TextStyle numberL = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 26,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Number M 20, tabular figures (session counter of a row).
  static const TextStyle numberM = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 20,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Material text roles mapped on the BirdyGo scale, so upstream screens
  /// pick up the fonts too.
  static const TextTheme textTheme = TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: display,
    headlineMedium: title,
    headlineSmall: heading,
    titleLarge: heading,
    titleMedium: species,
    titleSmall: labelCompact,
    bodyLarge: body,
    bodyMedium: bodyCompact,
    bodySmall: caption,
    labelLarge: labelCompact,
    labelMedium: badge,
    labelSmall: TextStyle(
      fontFamily: BirdyFonts.sans,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
  );
}
