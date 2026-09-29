/// « Fais sa connaissance » (J6h): Suivant/Revoir, read checks and hidden
/// sections.
library;

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

  testWidgets('Suivant walks the sections, then becomes Revoir', (tester) async {
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
}
