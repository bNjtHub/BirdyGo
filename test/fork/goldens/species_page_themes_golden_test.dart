import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import '../helpers/species_page_harness.dart';

/// Goldens of the species page (J7, 7 blocks) in the four bird themes, light
/// and dark, plus the never-heard state. The page's clock is fixed, so the
/// dates and the highlighted month are stable. Windows only, like the other
/// fork goldens; regenerate with
/// `flutter test --update-goldens test/fork/goldens/species_page_themes_golden_test.dart`.
void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'Fiche espèce ${bird.name} $mode',
        (tester) async {
          await pumpSpeciesPage(tester, bird, dark);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('species_page_${bird.name}_$mode.png'),
          );
        },
        tags: ['golden'],
        skip: !Platform.isWindows,
      );
    }
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'Fiche espèce jamais entendue $mode',
      (tester) async {
        await pumpSpeciesPage(
          tester,
          BirdyBird.loriot,
          dark,
          heard: false,
          size: const Size(412, 1900),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('species_page_never_heard_$mode.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isWindows,
    );
  }
}
