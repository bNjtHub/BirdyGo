import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/shell/fork_nav_bar.dart';
import 'package:birdnet_live/fork/shell/fork_shell.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

/// Goldens of the bottom bar alone, with its « Écouter » disc, in the four
/// bird themes, light and dark (J6j). Windows only, like the Accueil goldens
/// (fonts rasterise differently elsewhere). Regenerate with
/// `flutter test --update-goldens test/fork/shell/fork_nav_bar_golden_test.dart`.
void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'nav bar ${bird.name} $mode',
        (tester) async {
          tester.view.physicalSize = const Size(390, 140);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme:
                    dark
                        ? BirdyTheme.dark(bird: bird)
                        : BirdyTheme.light(bird: bird),
                locale: const Locale('fr'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder:
                    (context, app) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(disableAnimations: true),
                      child: app!,
                    ),
                home: Builder(
                  builder:
                      (context) => Scaffold(
                        backgroundColor: BirdyColors.of(context).background,
                        body: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ForkNavBar(
                                selected: ForkTab.notebook,
                                onSelect: (_) {},
                                onListen: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          );
          await tester.pump();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('fork_nav_bar_${bird.name}_$mode.png'),
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
