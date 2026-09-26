/// BirdyGo typography (J6a): Fraunces for titles and species names,
/// Atkinson Hyperlegible Next for the interface and numbers.
///
/// Both fonts are variable and bundled in assets/fonts/ (OFL). Weight goes
/// through [TextStyle.fontWeight], which drives the `wght` axis; never put a
/// `wght` [FontVariation] in a style, it would override every later
/// `fontWeight` (bold in upstream screens included). Fraunces also needs
/// `SOFT` and `opsz`, which Flutter does not set on its own.
library;

import 'package:flutter/material.dart';

/// Font family names declared in pubspec.yaml.
abstract final class BirdyFonts {
  static const String serif = 'Fraunces';
  static const String sans = 'AtkinsonHyperlegibleNext';
}

/// Text styles of the scale 34, 26, 20, 17, 15, 13 (SPEC.md 2.9).
///
/// Styles carry no color: they inherit it from the surrounding
/// [DefaultTextStyle], or take one from [BirdyColors].
abstract final class BirdyText {
  /// Display 34, Fraunces.
  static const TextStyle display = TextStyle(
    fontFamily: BirdyFonts.serif,
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 34)],
  );

  /// Title 26, Fraunces.
  static const TextStyle title = TextStyle(
    fontFamily: BirdyFonts.serif,
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 26)],
  );

  /// Heading 20, Fraunces: section titles, card titles, top bar.
  static const TextStyle heading = TextStyle(
    fontFamily: BirdyFonts.serif,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 20)],
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

  /// Latin name in headers, Fraunces italic 17.
  static const TextStyle latin = TextStyle(
    fontFamily: BirdyFonts.serif,
    fontSize: 17,
    height: 1.2,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 17)],
  );

  /// Latin name in lists, Fraunces italic 15.
  static const TextStyle latinCompact = TextStyle(
    fontFamily: BirdyFonts.serif,
    fontSize: 15,
    height: 1.2,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 15)],
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

  /// Label of main buttons, Atkinson bold 17.
  static const TextStyle label = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w700,
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

  /// Number XL 34, tabular figures.
  static const TextStyle numberXL = TextStyle(
    fontFamily: BirdyFonts.sans,
    fontSize: 34,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
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
