/// `NeverHeardBlock` (J7): texts, tap target and goldens. Goldens are
/// Windows only; regenerate with
/// `flutter test --update-goldens test/fork/species_page/never_heard_block_test.dart`.
library;

import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/species_page/never_heard_block.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool dark = false,
  String lang = 'fr',
  VoidCallback? onListen,
}) async {
  tester.view.physicalSize = const Size(412, 300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder:
            (context) => Scaffold(
              backgroundColor: BirdyColors.of(context).background,
              body: Padding(
                padding: const EdgeInsets.all(BirdySpace.l),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: NeverHeardBlock(onListen: onListen ?? () {}),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await loadAppFonts(icons: true);
  });

  testWidgets('shows title, text and button in French', (tester) async {
    await _pump(tester);
    expect(find.text('Pas encore dans ton carnet'), findsOneWidget);
    expect(find.text("Tu ne l'as pas encore entendu."), findsOneWidget);
    expect(find.text('Écouter pour le trouver'), findsOneWidget);
  });

  testWidgets('shows English strings', (tester) async {
    await _pump(tester, lang: 'en');
    expect(find.text('Not in your notebook yet'), findsOneWidget);
    expect(find.text('Listen to find it'), findsOneWidget);
  });

  testWidgets('tapping the button calls onListen, target is 56 high', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, onListen: () => taps++);
    final button = find.byType(FilledButton);
    expect(tester.getSize(button).height, BirdySizes.mainAction);
    await tester.tap(button);
    expect(taps, 1);
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'golden $mode',
      (tester) async {
        await _pump(tester, dark: dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('never_heard_block_$mode.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isWindows,
    );
  }
}
