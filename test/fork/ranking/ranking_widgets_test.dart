/// Podium and row visuals of the palmarès (J6f-f, `AppPalmares` mockup):
/// visual order 2-1-3, the medal metals, the proportional bar and the
/// "new this year" pill.
library;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_pill.dart';
import 'package:birdnet_live/fork/ranking/ranking_widgets.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RankedSpecies _species(String name, int value, {bool isNew = false}) =>
    RankedSpecies(
      scientificName: name,
      name: name,
      value: value,
      unit: 'contacts',
      isNew: isNew,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder:
          (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: app!,
          ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('RankingPodium', () {
    final top = [
      _species('Erithacus rubecula', 58),
      _species('Turdus merula', 41),
      _species('Parus major', 37),
    ];

    testWidgets('visual order is 2nd, 1st, 3rd', (tester) async {
      await _pump(
        tester,
        RankingPodium(top: top, onOpen: (_) {}),
      );
      await tester.pumpAndSettle();

      double left(String name) => tester.getTopLeft(find.text(name)).dx;
      expect(left('Turdus merula'), lessThan(left('Erithacus rubecula')));
      expect(left('Erithacus rubecula'), lessThan(left('Parus major')));
    });

    testWidgets('each step shows its rank on a medal', (tester) async {
      await _pump(tester, RankingPodium(top: top, onOpen: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('tapping a step opens that species', (tester) async {
      RankedSpecies? opened;
      await _pump(
        tester,
        RankingPodium(top: top, onOpen: (s) => opened = s),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Erithacus rubecula'));
      await tester.pumpAndSettle();
      expect(opened?.scientificName, 'Erithacus rubecula');
    });

    testWidgets('one species: no overflow, no crash', (tester) async {
      await _pump(
        tester,
        RankingPodium(top: [top.first], onOpen: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('RankingRow', () {
    testWidgets('the bar grows to the value over the leader', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: RankingRow(
            rank: 4,
            species: _species('Fringilla coelebs', 25),
            fraction: 0.5,
            index: 0,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.5, 1e-9));
    });

    testWidgets('a tiny fraction still shows a sliver of bar', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: RankingRow(
            rank: 12,
            species: _species('Upupa epops', 1),
            fraction: 1 / 58,
            index: 0,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(bar.widthFactor, greaterThanOrEqualTo(0.02));
    });

    testWidgets('reduced motion: the bar is at its target right away', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: RankingRow(
            rank: 4,
            species: _species('Fringilla coelebs', 25),
            fraction: 0.4,
            index: 3,
            onTap: () {},
          ),
        ),
        reducedMotion: true,
      );
      // No settle: with reduced motion the value is set synchronously in
      // didChangeDependencies, before any staggered timer would fire.
      await tester.pump();

      final bar = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.4, 1e-9));
    });

    testWidgets('new this year shows the pill, with its semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: RankingRow(
            rank: 4,
            species: _species('Fringilla coelebs', 76, isNew: true),
            fraction: 1,
            index: 0,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoveltyPill), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '4. Fringilla coelebs, 76 contacts, nouveau cette année',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('not new: no pill, no mention in the semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: RankingRow(
            rank: 5,
            species: _species('Parus major', 40),
            fraction: 1,
            index: 1,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoveltyPill), findsNothing);
      expect(
        find.bySemanticsLabel('5. Parus major, 40 contacts'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
