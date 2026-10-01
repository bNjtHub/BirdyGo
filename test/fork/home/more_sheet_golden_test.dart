import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/home/more_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

/// Goldens of the « Plus » sheet in the four bird themes, light and dark (M).
/// Same mechanism as `goldens/home_themes_golden_test.dart`: the references
/// are rasterised on Windows, so the pixel comparison runs only there.
/// Regenerate with
/// `flutter test --update-goldens test/fork/home/more_sheet_golden_test.dart`.
void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'Plus ${bird.name} $mode',
        (tester) async {
          tester.view.physicalSize = const Size(390, 900);
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
                home: Scaffold(
                  body: SafeArea(
                    child: MoreSheet(
                      toVerify: 12,
                      onOpen: (_) {},
                      aruScreen: () => const SizedBox(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/more_${bird.name}_$mode.png'),
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
