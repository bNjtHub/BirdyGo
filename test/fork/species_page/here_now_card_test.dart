/// `HereNowCard` (J7 fix): the 48-week chart keeps a readable width at
/// every phone size, with no overflow, and stays tappable. Goldens are
/// Windows only, like the other fork goldens; regenerate with
/// `flutter test --update-goldens test/fork/species_page/here_now_card_test.dart`.
library;

import 'dart:io' show Platform;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/ranking/activity_bars.dart';
import 'package:birdnet_live/fork/species_page/species_page_model.dart';
import 'package:birdnet_live/fork/species_page/species_page_view.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
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
  NestingPeriod? nesting = const NestingPeriod(4, 7),
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
                    currentWeek: 18,
                    nesting: nesting,
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
    for (final scale in [1.0, 1.3]) {
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
        final chart = find.byType(ActivityBars);
        final w = tester.getSize(chart).width;
        // 48 bars: at least 4 dp per slot, all 12 month initials.
        expect(w / 48, greaterThanOrEqualTo(4));
        final bars = tester.widget<ActivityBars>(chart);
        expect(bars.values.length, 48);
        expect(bars.labels.length, 12);
        expect(bars.highlightIndex, 17);
        // The band spans the chart's width.
        final band = tester.getSize(
          find.byKey(const ValueKey('fiche-nesting')),
        );
        expect(band.width, w);
      });
    }
  }

  testWidgets('quarterly labels at 200 % text, still no overflow', (
    tester,
  ) async {
    await _pump(tester, width: 360, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.widget<ActivityBars>(find.byType(ActivityBars)).labels.length, 4);
  });

  testWidgets('tap on a bar shows its month', (tester) async {
    await _pump(tester, width: 412);
    final rect = tester.getRect(find.byType(ActivityBars));
    await tester.tapAt(
      Offset(rect.left + rect.width / 48 * 18.5, rect.top + 5),
    );
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
