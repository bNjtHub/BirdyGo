import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import '../helpers/home_theme_harness.dart';

/// Goldens of the Accueil in the four bird themes, light and dark (J6i).
///
/// The clock of the Accueil is fixed, so the date and the greeting are stable
/// and the comparison is exact. The references are rasterised on Windows, so
/// the pixel comparison runs only there (CI is Linux; the smoke test in
/// `home_themes_smoke_test.dart` covers the themes everywhere). Regenerate
/// with `flutter test --update-goldens test/fork/goldens` on Windows.
void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'Accueil ${bird.name} $mode',
        (tester) async {
          await pumpHome(tester, bird, dark);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('home_${bird.name}_$mode.png'),
          );
        },
        tags: ['golden'],
        skip:
            !Platform
                .isWindows, // goldens generated on Windows; font rasterisation differs
      );
    }
  }
}
