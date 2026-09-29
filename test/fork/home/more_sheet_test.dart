import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_block.dart';
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

  Future<void> pumpSheet(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(780, 1688);
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
              onOpen: (_) {},
              aruScreen: () => const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  BirdyColors colors(WidgetTester tester) =>
      BirdyColors.of(tester.element(find.byType(MoreSheet)));

  /// The circular 40 disc inside [tile].
  Container discOf(WidgetTester tester, Finder tile) {
    final discs = find.descendant(
      of: tile,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(discs, findsOneWidget);
    return tester.widget<Container>(discs);
  }

  Finder tile(String label) => find.byKey(ValueKey('more-tile-$label'));

  Finder dashedIn(Finder of) => find.descendant(
    of: of,
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.foregroundPainter is DashedBorderPainter,
    ),
  );

  for (final dark in [false, true]) {
    group(dark ? 'dark' : 'light', () {
      testWidgets('tiles are Brume, only the disc is tinted', (tester) async {
        await pumpSheet(tester, dark: dark);
        final c = colors(tester);
        final tints = <String, Color>{
          fr.forkRanking: c.orioleContainer,
          fr.forkMap: c.tonal,
          fr.forkQuickReview: c.surface1,
          fr.forkSoundLibrary: c.tonal,
          fr.forkGardenTitle: c.sure.background,
          fr.exploreMode: c.tonal,
          fr.sessionLibraryTitle: c.tonal,
          fr.helpTitle: c.surface1,
        };
        for (final e in tints.entries) {
          await show(tester, tile(e.key));
          final block = tester.widget<BirdyBlock>(tile(e.key));
          expect(block.color, c.background, reason: e.key);
          final disc = discOf(tester, tile(e.key));
          expect((disc.decoration! as BoxDecoration).color, e.value);
          expect(disc.constraints?.maxWidth, BirdySizes.blockIconDisc);
        }
      });

      testWidgets('Revue rapide disc has the dashed toCheck outline', (
        tester,
      ) async {
        await pumpSheet(tester, dark: dark);
        await show(tester, tile(fr.forkQuickReview));
        expect(dashedIn(tile(fr.forkQuickReview)), findsOneWidget);
        await show(tester, tile(fr.forkMap));
        expect(dashedIn(tile(fr.forkMap)), findsNothing);
      });
    });
  }

  testWidgets('Réglages and À propos share one Brume block, white discs', (
    tester,
  ) async {
    await pumpSheet(tester);
    final c = colors(tester);
    await show(tester, find.byKey(const ValueKey('more-about')));
    final block = find.byKey(const ValueKey('more-links'));
    expect(tester.widget<BirdyListBlock>(block).color, c.background);
    expect(
      find.descendant(of: block, matching: find.byType(BirdyListRow)),
      findsNWidgets(2),
    );
    for (final key in ['more-settings', 'more-about']) {
      final row = tester.widget<BirdyListRow>(find.byKey(ValueKey(key)));
      expect(row.discColor, c.surface1);
    }
    expect(find.byType(BirdyListBlock), findsOneWidget);
  });

  testWidgets('every tap target is at least 48', (tester) async {
    await pumpSheet(tester);
    final targets = [
      for (final l in [
        fr.forkRanking,
        fr.forkMap,
        fr.forkQuickReview,
        fr.forkSoundLibrary,
        fr.forkGardenTitle,
        fr.exploreMode,
        fr.sessionLibraryTitle,
        fr.helpTitle,
      ])
        tile(l),
      find.byKey(const ValueKey('more-advanced-toggle')),
      find.byKey(const ValueKey('more-settings')),
      find.byKey(const ValueKey('more-about')),
    ];
    for (final t in targets) {
      await show(tester, t);
      final size = tester.getSize(t);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });
}
