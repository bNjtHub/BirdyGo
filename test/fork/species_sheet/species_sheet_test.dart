import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet_section.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _gzip(Map<String, dynamic> json) =>
    gzip.encode(utf8.encode(jsonEncode(json)));

void main() {
  group('SpeciesSheets', () {
    test('parses the bundle and drops empty sections', () {
      final sheets = SpeciesSheets.fromGzip(
        _gzip({
          'version': 1,
          'species': {
            'Erithacus rubecula': {
              'name': 'Rougegorge familier',
              'summary': 'Un petit oiseau.',
              'anecdote': 'Il chante la nuit.',
              'size': '  ',
              'hint': 'Plastron orange',
            },
          },
        }),
      );
      final robin = sheets['Erithacus rubecula']!;
      expect(sheets.length, 1);
      expect(robin.name, 'Rougegorge familier');
      expect(robin.sections.keys, [
        SheetSection.summary,
        SheetSection.anecdote,
      ]);
      expect(robin.hint, 'Plastron orange');
      expect(sheets['Turdus merula'], isNull);
    });

    test('only for French species names', () {
      expect(sheetsApplyTo('fr'), isTrue);
      expect(sheetsApplyTo('fr-CA'), isTrue);
      expect(sheetsApplyTo('en'), isFalse);
    });

    test('the bundled asset is valid', () {
      final sheets = SpeciesSheets.fromGzip(
        File(speciesSheetsAsset).readAsBytesSync(),
      );
      for (final name in _bundledNames()) {
        final sheet = sheets[name]!;
        expect(sheet.name, isNotEmpty, reason: name);
        expect(sheet.sections, isNotEmpty, reason: name);
      }
    });
  });

  testWidgets('shows the summary first, titled sections and the footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: SpeciesSheetView(
              sheet: SpeciesSheet(
                name: 'Rougegorge familier',
                sections: {
                  SheetSection.summary: 'Un petit oiseau.',
                  SheetSection.byEar: 'Un chant flûté.',
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Un petit oiseau.'), findsOneWidget);
    expect(find.text('En bref'), findsNothing);
    expect(find.text("À l'oreille"), findsOneWidget);
    expect(find.text('Un chant flûté.'), findsOneWidget);
    expect(
      find.text('Fiche rédigée par IA : elle peut contenir des erreurs.'),
      findsOneWidget,
    );
  });
}

/// Scientific names in the bundled asset.
Iterable<String> _bundledNames() {
  final json =
      jsonDecode(
            utf8.decode(
              gzip.decode(File(speciesSheetsAsset).readAsBytesSync()),
            ),
          )
          as Map<String, dynamic>;
  return (json['species'] as Map<String, dynamic>).keys;
}
