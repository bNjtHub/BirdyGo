import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_list_block.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_list_row.dart';
import 'package:birdnet_live/fork/design/widgets/dashed_border.dart';
import 'package:birdnet_live/fork/home/more_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  Future<void> pumpSheet(
    WidgetTester tester, {
    bool dark = false,
    int? toVerify = 12,
  }) async {
    tester.view.physicalSize = const Size(780, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MoreSheet(
              toVerify: toVerify,
              onOpen: (_) {},
              aruScreen: () => const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BirdyColors colors(WidgetTester tester) =>
      BirdyColors.of(tester.element(find.byType(MoreSheet)));

  Finder row(String label) => find.byKey(ValueKey('more-row-$label'));

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('three groups in order, Carte absent', (tester) async {
    await pumpSheet(tester);
    final groups = [
      for (final k in ['play', 'mine', 'discover'])
        top(tester, find.byKey(ValueKey('more-group-$k'))),
    ];
    expect(groups, orderedEquals([...groups]..sort()));
    expect(find.text(fr.forkMoreGroupPlay), findsOneWidget);
    expect(find.text(fr.forkMoreGroupMine), findsOneWidget);
    expect(find.text(fr.forkMoreGroupDiscover), findsOneWidget);
    expect(find.text(fr.forkMap), findsNothing);
    expect(find.byType(BirdyListBlock), findsNWidgets(3));
    for (final l in [
      fr.forkQuizTitle,
      fr.forkRanking,
      fr.forkQuickReview,
      fr.forkSoundLibrary,
      fr.sessionLibraryTitle,
      fr.forkGardenTitle,
      fr.exploreMode,
    ]) {
      expect(row(l), findsOneWidget, reason: l);
      expect(
        tester.getSize(row(l)).height,
        greaterThanOrEqualTo(BirdySizes.row),
      );
    }
  });

  testWidgets('utility block: Réglages, Aide, À propos, Outils avancés last', (
    tester,
  ) async {
    await pumpSheet(tester);
    final keys = [
      'more-settings',
      'more-help',
      'more-about',
      'more-advanced-toggle',
    ];
    final ys = [for (final k in keys) top(tester, find.byKey(ValueKey(k)))];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(
      top(tester, find.byKey(const ValueKey('more-utility'))),
      greaterThan(
        top(tester, find.byKey(const ValueKey('more-group-discover'))),
      ),
    );
    for (final k in keys) {
      expect(
        tester.getSize(find.byKey(ValueKey(k))).height,
        greaterThanOrEqualTo(BirdySizes.moreCompactRow),
      );
    }
  });

  testWidgets('Outils avancés expands in place and stays last', (tester) async {
    await pumpSheet(tester);
    final toolKey = find.byKey(ValueKey('more-tool-${fr.aruMode}'));
    expect(toolKey, findsNothing);
    await tester.tap(find.byKey(const ValueKey('more-advanced-toggle')));
    await tester.pumpAndSettle();
    expect(toolKey, findsOneWidget);
    expect(
      top(tester, toolKey),
      greaterThan(
        top(tester, find.byKey(const ValueKey('more-advanced-toggle'))),
      ),
    );
    for (final l in [
      fr.pointCountMode,
      fr.surveyMode,
      fr.aruMode,
      fr.forkPracticeMenu,
      fr.fileAnalysisMode,
    ]) {
      expect(find.byKey(ValueKey('more-tool-$l')), findsOneWidget, reason: l);
    }
    await tester.tap(find.byKey(const ValueKey('more-advanced-toggle')));
    await tester.pumpAndSettle();
    expect(toolKey, findsNothing);
  });

  testWidgets('Revue rapide subtitle follows toVerify', (tester) async {
    await pumpSheet(tester, toVerify: 12);
    expect(find.text(fr.forkMoreReviewSub(12)), findsOneWidget);
    await pumpSheet(tester, toVerify: 0);
    expect(find.text(fr.forkMoreReviewDone), findsOneWidget);
  });

  testWidgets('Revue rapide before the Accueil loads: no « sorted »', (
    tester,
  ) async {
    await pumpSheet(tester, toVerify: null);
    expect(find.text(fr.forkMoreReviewDone), findsNothing);
    expect(find.textContaining('à vérifier'), findsNothing);
    final unknown = tester.getSize(find.text(fr.forkQuickReview)).height;
    expect(unknown, greaterThan(0));
    final rowH =
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(fr.forkQuickReview),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .height;
    await pumpSheet(tester, toVerify: 12);
    final loadedH =
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(fr.forkQuickReview),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .height;
    expect(rowH, loadedH);
  });

  for (final dark in [false, true]) {
    testWidgets('discs are tinted (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pumpSheet(tester, dark: dark);
      final c = colors(tester);
      final tints = <String, Color>{
        fr.forkQuizTitle: c.orioleContainer,
        fr.forkRanking: c.orioleContainer,
        fr.forkSoundLibrary: c.tonal,
        fr.sessionLibraryTitle: c.tonal,
        fr.forkGardenTitle: c.sure.background,
        fr.exploreMode: c.tonal,
      };
      for (final e in tints.entries) {
        expect(
          tester.widget<BirdyListRow>(row(e.key)).discColor,
          e.value,
          reason: e.key,
        );
      }
      // Revue rapide: white disc with the dashed toCheck outline.
      expect(
        find.descendant(
          of: row(fr.forkQuickReview),
          matching: find.byWidgetPredicate(
            (w) =>
                w is CustomPaint && w.foregroundPainter is DashedBorderPainter,
          ),
        ),
        findsOneWidget,
      );
    });
  }
}
