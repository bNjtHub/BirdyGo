import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import '../helpers/home_theme_harness.dart';

/// Platform-independent smoke test of the Accueil in the four bird themes,
/// light and dark: it builds without exception and takes the theme accent.
/// Runs everywhere, unlike the pixel goldens (Windows only).
void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('Accueil ${bird.name} $mode builds with theme accent', (
        tester,
      ) async {
        await pumpHome(tester, bird, dark);
        expect(tester.takeException(), isNull);
        expect(find.byType(ListenButton), findsOneWidget);
        final context = tester.element(find.byType(ListenButton));
        final brand = BirdyBrandColors(
          bird,
          dark ? Brightness.dark : Brightness.light,
        );
        expect(Theme.of(context).colorScheme.primary, brand.accentText);
      });
    }
  }
}
