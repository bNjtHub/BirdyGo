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
}
