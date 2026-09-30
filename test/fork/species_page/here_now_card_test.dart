/// `HereNowCard` (J7 fix): the compact month chart beside the sentence
/// (the sentence itself comes from the 48 weeks) has no overflow at any
/// phone size or text scale, and stays tappable. Goldens are
/// Windows only, like the other fork goldens; regenerate with
/// `flutter test --update-goldens test/fork/species_page/here_now_card_test.dart`.
library;

import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/ranking/activity_bars.dart';
import 'package:birdnet_live/fork/species_page/species_page_model.dart';
import 'package:birdnet_live/fork/species_page/species_page_view.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

/// A migrant: present weeks 8 to 35, peaking around week 18.
YearPresence _year() => YearPresence.fromWeeks([
  for (var w = 0; w < 48; w++)
    (w >= 8 && w <= 35)
        ? 0.2 + 0.8 * (1 - ((w - 18).abs() / 12)).clamp(0.0, 1.0)
        : 0.0,
]);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  bool dark = false,
  String? rareNote,
}) async {
  tester.view.physicalSize = Size(width, 420);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
      home: Builder(
        builder:
            (context) => Scaffold(
              backgroundColor: BirdyColors.of(context).background,
              body: Padding(
                padding: const EdgeInsets.all(BirdySpace.l),
                child: SingleChildScrollView(
                  child: HereNowCard(
                    year: _year(),
                    sentence: 'Arrive début mars · repart fin septembre.',
                    currentMonth: 5,
                    rareNote: rareNote,
                  ),
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

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x$scale', (
        tester,
      ) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          rareNote: 'Le chant ressemble bien, mais le lieu surprend.',
        );
        expect(tester.takeException(), isNull);
        final bars = tester.widget<ActivityBars>(find.byType(ActivityBars));
        expect(bars.values.length, 12);
        expect(bars.highlightIndex, 4);
        expect(find.byKey(const ValueKey('fiche-nesting')), findsNothing);
      });
    }
  }

  testWidgets('tap on a bar shows its month', (tester) async {
    await _pump(tester, width: 412);
    final rect = tester.getRect(find.byType(ActivityBars));
    await tester.tapAt(Offset(rect.left + rect.width / 12 * 2.5, rect.top + 5));
    await tester.pump();
    expect(find.textContaining('du pic'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'golden $mode',
      (tester) async {
        await _pump(tester, width: 412, dark: dark);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('here_now_card_$mode.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isWindows,
    );
  }
}
