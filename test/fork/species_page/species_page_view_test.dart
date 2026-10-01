/// Widget tests for a few `species_page_view.dart` blocks, isolated from the
/// full page (J6f-b fix).
library;

import 'package:birdnet_live/fork/species_page/species_page_view.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 220}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: width, child: Center(child: child)),
        ),
      ),
    );

void main() {
  group('LinksBlock', () {
    final links = <SpeciesLink>[
      (label: 'eBird', iconAsset: 'assets/images/icon-ebird.png', url: 'a'),
      (
        label: 'iNaturalist',
        iconAsset: 'assets/images/icon-inat.png',
        url: 'b',
      ),
      (label: 'Wikipedia', iconAsset: 'assets/images/icon-wikipedia.png', url: 'c'),
    ];

    testWidgets(
      'the pills sit in one scrolling row, not wrapped on two lines '
      '(J6f-b fix)',
      (tester) async {
        await _pump(
          tester,
          LinksBlock(links: links, onOpen: (_) {}),
          width: 220,
        );

        // One horizontal scroll view, and every pill on it (a `Wrap` would
        // have pushed the third pill to a second line instead).
        final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(scroll.scrollDirection, Axis.horizontal);
        expect(find.text('eBird'), findsOneWidget);
        expect(find.text('iNaturalist'), findsOneWidget);
        expect(find.text('Wikipedia'), findsOneWidget);

        // The row is wider than the 220 px viewport: it only fits by
        // scrolling, not by wrapping.
        final row = tester.getRect(find.byType(Row).first);
        expect(row.width, greaterThan(220));

        // All three pills sit on the very same y (one row, one line each).
        final tops = [
          tester.getTopLeft(find.text('eBird')).dy,
          tester.getTopLeft(find.text('iNaturalist')).dy,
          tester.getTopLeft(find.text('Wikipedia')).dy,
        ];
        expect(tops.toSet().length, 1);
      },
    );

    testWidgets('dragging the row scrolls to the last pill (J6f-b fix)', (
      tester,
    ) async {
      await _pump(tester, LinksBlock(links: links, onOpen: (_) {}), width: 220);
      expect(
        tester.getTopLeft(find.text('Wikipedia')).dx,
        greaterThan(220),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-400, 0),
      );
      await tester.pump();

      expect(tester.getTopLeft(find.text('Wikipedia')).dx, lessThan(220));
    });
  });

  group('SongBlock', () {
    testWidgets('title, short reference button, by ear text (J7)', (
      tester,
    ) async {
      await _pump(
        tester,
        SongBlock(
          byEar: 'Un filet de notes perlées.',
          clips: const [],
          favorites: const {},
          playing: null,
          lineOf: (_) => '',
          onPlay: (_) {},
          onFavorite: (_, _) {},
          onReference: () {},
        ),
        width: 360,
      );
      expect(find.text('Son chant'), findsOneWidget);
      expect(find.text('Référence'), findsOneWidget);
      expect(find.text('Chant de référence'), findsNothing);
      expect(find.text('Un filet de notes perlées.'), findsOneWidget);
    });

    testWidgets('no reference, no by ear: only the title', (tester) async {
      await _pump(
        tester,
        SongBlock(
          clips: const [],
          favorites: const {},
          playing: null,
          lineOf: (_) => '',
          onPlay: (_) {},
          onFavorite: (_, _) {},
        ),
        width: 360,
      );
      expect(find.text('Son chant'), findsOneWidget);
      expect(find.text('Référence'), findsNothing);
    });
  });

  group('GoFurtherBlock', () {
    testWidgets('one title, 48 dp pills', (tester) async {
      await _pump(
        tester,
        GoFurtherBlock(
          links: const [
            (label: 'eBird', iconAsset: 'assets/images/icon-ebird.png', url: 'a'),
            (
              label: 'Wikipedia',
              iconAsset: 'assets/images/icon-wikipedia.png',
              url: 'c',
            ),
          ],
          onOpen: (_) {},
        ),
        width: 360,
      );
      expect(find.text('Pour aller plus loin'), findsOneWidget);
      expect(find.text('En savoir plus sur cette espèce'), findsNothing);
      final pill = find.ancestor(
        of: find.text('eBird'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(pill.first).height, greaterThanOrEqualTo(48));
    });
  });
}
