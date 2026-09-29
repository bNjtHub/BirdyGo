import 'dart:io';

import 'package:birdnet_live/fork/design/birdy_typography.dart';
import 'package:birdnet_live/fork/design/font_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _files = {
  BirdyFonts.rounded: ['assets/fonts/Nunito-Variable.ttf'],
  BirdyFonts.serif: ['assets/fonts/Fraunces-Variable.ttf'],
  BirdyFonts.sans: [
    'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
    'assets/fonts/AtkinsonHyperlegibleNext-Italic-Variable.ttf',
  ],
};

Future<void> _loadFonts() async {
  for (final MapEntry(key: family, value: paths) in _files.entries) {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

double _width(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  test('pubspec declares every bundled font and license', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: ${BirdyFonts.rounded}'));
    expect(pubspec, contains('family: ${BirdyFonts.serif}'));
    expect(pubspec, contains('family: ${BirdyFonts.sans}'));
    for (final path in [
      ..._files.values.expand((paths) => paths),
      ...kForkFontLicenses.values,
    ]) {
      expect(pubspec, contains(path));
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    for (final path in kForkFontLicenses.values) {
      expect(File(path).readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    }
  });

  // The typography relies on fontWeight driving the variable wght axis, and
  // on an explicit wght variation overriding it (so styles never set one).
  test('fontWeight drives the wght axis of the variable fonts', () {
    const sans = TextStyle(fontFamily: BirdyFonts.sans, fontSize: 20);
    const sample = 'Rougegorge familier';
    final regular = _width(sample, sans);
    final bold = _width(sample, sans.copyWith(fontWeight: FontWeight.w800));
    expect(bold, greaterThan(regular));
    final pinned = _width(
      sample,
      sans.copyWith(
        fontWeight: FontWeight.w800,
        fontVariations: const [FontVariation('wght', 400)],
      ),
    );
    expect(pinned, regular);

    final heading = _width(sample, BirdyText.heading);
    final black = _width(
      sample,
      BirdyText.heading.copyWith(fontWeight: FontWeight.w900),
    );
    expect(heading, lessThan(black));
  });

  test('titles are Nunito 800, tracked -1 % from 26 up', () {
    for (final style in [
      BirdyText.display,
      BirdyText.title,
      BirdyText.heading,
      BirdyText.numberXL,
    ]) {
      expect(style.fontFamily, BirdyFonts.rounded);
      expect(style.fontWeight, FontWeight.w800);
      expect(
        style.letterSpacing,
        style.fontSize! >= 26 ? closeTo(-0.01 * style.fontSize!, 1e-9) : 0,
      );
    }
    // Nunito is really loaded and heavier at 800 than at 400.
    const sample = 'Première rencontre';
    final base = BirdyText.heading.copyWith(fontWeight: FontWeight.w400);
    expect(
      _width(sample, BirdyText.heading),
      greaterThan(_width(sample, base)),
    );
    // The text scale still applies, and Nunito is not the fallback font.
    expect(
      _width(sample, BirdyText.heading),
      isNot(_width(sample, BirdyText.heading.copyWith(fontFamily: 'Fraunces'))),
    );
  });

  test('latin names use the Atkinson italic file, not a synthetic slant', () {
    const sample = 'Erithacus rubecula';
    final upright = BirdyText.latin.copyWith(fontStyle: FontStyle.normal);
    expect(_width(sample, BirdyText.latin), isNot(_width(sample, upright)));
  });

  test('numbers use tabular figures', () {
    expect(
      _width('1111', BirdyText.numberM),
      closeTo(_width('0000', BirdyText.numberM), 0.01),
    );
    const proportional = TextStyle(
      fontFamily: BirdyFonts.sans,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );
    expect(
      _width('1111', proportional),
      lessThan(_width('0000', proportional)),
    );
  });

  test('font licenses are registered', () async {
    registerForkFontLicenses();
    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }
    expect(packages, containsAll(kForkFontLicenses.keys));
  });
}
