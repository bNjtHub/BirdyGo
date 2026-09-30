/// « Fais sa connaissance » (J6h): Suivant/Revoir, read checks and hidden
/// sections.
library;

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/species_page/meet_species_block.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, SpeciesSheet sheet) async {
  tester.view.physicalSize = const Size(1170, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MeetSpeciesBlock(sheet: sheet, onQuizTap: () {}),
        ),
      ),
    ),
  );
}

const _all = SpeciesSheet(
  name: 'Merle noir',
  sections: {
    SheetSection.summary: 'Un chanteur du soir.',
    SheetSection.byEar: 'Phrases flûtées.',
    SheetSection.size: 'Vingt-cinq centimètres.',
    SheetSection.behaviour: 'Fouille le sol.',
    SheetSection.migration: 'Reste toute l\'année.',
    SheetSection.anecdote: 'Il chante dès la fin de l\'hiver.',
  },
);

void main() {
  testWidgets('starts on the first section, 1/5 discovered', (tester) async {
    await _pump(tester, _all);
    expect(find.text('Comment le reconnaître'), findsOneWidget);
    expect(find.text('Phrases flûtées.'), findsOneWidget);
    expect(find.text('1/5 découverts'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
  });

  testWidgets('Suivant walks the sections, then becomes Revoir', (
    tester,
  ) async {
    await _pump(tester, _all);
    for (final hook in [
      'Sa taille',
      'Ce qu\'il fait',
      'Où il passe l\'année',
      'Le savais-tu ?',
    ]) {
      await tester.tap(find.byKey(const ValueKey('meet-next')));
      await tester.pumpAndSettle();
      expect(find.text(hook), findsOneWidget);
    }
    expect(find.text('Revoir'), findsOneWidget);
    expect(find.text('Suivant'), findsNothing);
    expect(find.text('5/5 découverts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meet-next')));
    await tester.pumpAndSettle();
    expect(find.text('Comment le reconnaître'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
  });

  testWidgets('a read section gets a check, the current one is counted', (
    tester,
  ) async {
    await _pump(tester, _all);
    expect(find.byKey(const ValueKey('meet-read-size')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meet-disc-migration')));
    await tester.pumpAndSettle();
    expect(find.text('Où il passe l\'année'), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-read-by_ear')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-read-migration')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-read-size')), findsNothing);
    expect(find.text('2/5 découverts'), findsOneWidget);
  });

  testWidgets('sections without content are hidden, count is N/available', (
    tester,
  ) async {
    await _pump(
      tester,
      const SpeciesSheet(
        name: 'x',
        sections: {
          SheetSection.byEar: 'A.',
          SheetSection.anecdote: 'B.',
          SheetSection.confusions: 'Not one of the five.',
        },
      ),
    );
    expect(find.byKey(const ValueKey('meet-disc-by_ear')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-disc-anecdote')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-disc-size')), findsNothing);
    expect(find.byKey(const ValueKey('meet-disc-migration')), findsNothing);
    expect(find.text('1/2 découverts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meet-next')));
    await tester.pumpAndSettle();
    expect(find.text('Revoir'), findsOneWidget);
  });

  testWidgets('shows the quiz link', (tester) async {
    await _pump(tester, _all);
    expect(find.text('Qui chante ?'), findsOneWidget);
  });

  testWidgets('whyHere and confusions stay visible as their own blocks', (
    tester,
  ) async {
    await _pump(
      tester,
      const SpeciesSheet(
        name: 'Merle noir',
        sections: {
          SheetSection.byEar: 'Phrases flûtées.',
          SheetSection.whyHere: 'Il aime les jardins.',
          SheetSection.confusions: 'Le merle à plastron.',
        },
      ),
    );
    expect(find.byKey(const ValueKey('meet-extra-why_here')), findsOneWidget);
    expect(find.text('Il aime les jardins.'), findsOneWidget);
    expect(find.text('Le merle à plastron.'), findsOneWidget);
    expect(find.text('Pourquoi il est là'), findsOneWidget);
    expect(find.text('Confusions possibles'), findsOneWidget);
  });

  group('six sections (Ennemis)', () {
    const six = SpeciesSheet(
      name: 'Merle noir',
      sections: {
        SheetSection.byEar: 'Phrases flûtées.',
        SheetSection.size: 'Vingt-cinq centimètres.',
        SheetSection.behaviour: 'Fouille le sol.',
        SheetSection.migration: 'Reste toute l\'année.',
        SheetSection.enemies: 'L\'épervier et le chat.',
        SheetSection.anecdote: 'Il chante dès la fin de l\'hiver.',
      },
    );
    const keys = [
      'by_ear',
      'size',
      'behaviour',
      'migration',
      'enemies',
      'anecdote',
    ];

    test('order of the six sections', () {
      expect(meetAvailable(six), [
        SheetSection.byEar,
        SheetSection.size,
        SheetSection.behaviour,
        SheetSection.migration,
        SheetSection.enemies,
        SheetSection.anecdote,
      ]);
    });

    testWidgets('six discs, Habitudes label, counter 1/6', (tester) async {
      await _pump(tester, six);
      for (final k in keys) {
        expect(find.byKey(ValueKey('meet-disc-$k')), findsOneWidget);
      }
      expect(find.text('Habitudes'), findsOneWidget);
      expect(find.text('Comportement'), findsNothing);
      expect(find.text('Ennemis'), findsOneWidget);
      expect(find.text('1/6 découverts'), findsOneWidget);
    });

    testWidgets('Ennemis shows its kicker and text', (tester) async {
      await _pump(tester, six);
      await tester.tap(find.byKey(const ValueKey('meet-disc-enemies')));
      await tester.pumpAndSettle();
      expect(find.text('Qui le chasse'), findsOneWidget);
      expect(find.text('L\'épervier et le chat.'), findsOneWidget);
      expect(find.text('2/6 découverts'), findsOneWidget);
    });

    testWidgets('Ennemis is hidden without text, counter is n/5', (
      tester,
    ) async {
      await _pump(tester, _all);
      expect(find.byKey(const ValueKey('meet-disc-enemies')), findsNothing);
      expect(find.text('1/5 découverts'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('labels never overflow at 320 dp, text x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(960, 3000);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: MeetSpeciesBlock(sheet: six, onQuizTap: () {}),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final k in keys) {
          final disc = tester.getRect(find.byKey(ValueKey('meet-disc-$k')));
          final label = tester.getRect(
            find.descendant(
              of: find.byKey(ValueKey('meet-disc-$k')),
              matching: find.byType(Text),
            ),
          );
          expect(label.left, greaterThanOrEqualTo(disc.left - 0.5));
          expect(label.right, lessThanOrEqualTo(disc.right + 0.5));
        }
      });
    }
  });
  group('bundled Ennemis section', () {
    late SpeciesSheets sheets;

    setUpAll(() {
      sheets = SpeciesSheets.fromGzip(
        File(speciesSheetsAsset).readAsBytesSync(),
      );
    });

    test('at least 80 bundled sheets have a non-empty Ennemis text', () {
      final json =
          jsonDecode(
                utf8.decode(
                  gzip.decode(File(speciesSheetsAsset).readAsBytesSync()),
                ),
              )
              as Map<String, dynamic>;
      var count = 0;
      for (final key in (json['species'] as Map<String, dynamic>).keys) {
        final text = sheets[key]!.sections[SheetSection.enemies];
        if (text != null && text.trim().isNotEmpty) count++;
      }
      expect(count, greaterThanOrEqualTo(80));
    });

    testWidgets('shows six sections for a species with enemies', (
      tester,
    ) async {
      final sheet = sheets['Accipiter nisus']!;
      expect(meetAvailable(sheet), kMeetSections);
      await _pump(tester, sheet);
      expect(find.text('1/6 découverts'), findsOneWidget);
    });
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x$scale (J7)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: MeetSpeciesBlock(sheet: _all, onQuizTap: () {}),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('découverts'), findsOneWidget);
      });
    }
  }
}
