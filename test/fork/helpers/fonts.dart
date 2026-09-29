import 'package:flutter/services.dart' show FontLoader, rootBundle;

/// Loads the app's real bundled fonts into the test engine.
///
/// The default test font is a rough substitute with different metrics, so
/// tests that compare wrapped text or take goldens need the real ones.
/// Fonts the app does not bundle (yet) are skipped. With [icons] the
/// Material Symbols fonts are loaded too, so goldens draw real icons.
Future<void> loadAppFonts({bool icons = false}) async {
  Future<void> load(String family, String asset) async {
    try {
      final loader = FontLoader(family)..addFont(rootBundle.load(asset));
      await loader.load();
    } catch (_) {
      // Not bundled in this build of the app.
    }
  }

  await load('Fraunces', 'assets/fonts/Fraunces-Variable.ttf');
  await load(
    'AtkinsonHyperlegibleNext',
    'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
  );
  await load('Nunito', 'assets/fonts/Nunito-Variable.ttf');
  if (icons) {
    for (final style in ['Outlined', 'Rounded']) {
      await load(
        'packages/material_symbols_icons/MaterialSymbols$style',
        'packages/material_symbols_icons/lib/fonts/MaterialSymbols$style.ttf',
      );
    }
  }
}
