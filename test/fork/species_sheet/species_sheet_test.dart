import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet_section.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    test('nesting period: optional, ignored when invalid (J7)', () {
      SpeciesSheet sheet(Object? nesting) => SpeciesSheet.fromJson({
        'name': 'x',
        'summary': 'y',
        if (nesting != null) 'nesting': nesting,
      });
      expect(sheet('4-7').nesting, const NestingPeriod(4, 7));
      expect(sheet(' 11 - 2 ').nesting, const NestingPeriod(11, 2));
      expect(sheet(null).nesting, isNull);
      expect(sheet('13-2').nesting, isNull);
      expect(sheet('0-3').nesting, isNull);
      expect(sheet('avril').nesting, isNull);
      expect(sheet(5).nesting, isNull);
      expect(const NestingPeriod(11, 2).includes(12), isTrue);
      expect(const NestingPeriod(11, 2).includes(2), isTrue);
      expect(const NestingPeriod(11, 2).includes(5), isFalse);
      expect(const NestingPeriod(4, 7).includes(8), isFalse);
    });

    test('only for French and English species names', () {
      expect(sheetsApplyTo('fr'), isTrue);
      expect(sheetsApplyTo('fr-CA'), isTrue);
      expect(sheetsApplyTo('en'), isTrue);
      expect(sheetsApplyTo('en-GB'), isTrue);
      expect(sheetsApplyTo('de'), isFalse);
    });

    test('one bundle per language', () {
      expect(speciesSheetsAssetFor('fr'), speciesSheetsAsset);
      expect(speciesSheetsAssetFor('en-GB'), speciesSheetsAssetEn);
      expect(speciesSheetsAssetEn, endsWith('species_sheets_en.json.gz'));
    });

    test('the English bundle is valid and as big as the French one', () {
      final fr = SpeciesSheets.fromGzip(
        File(speciesSheetsAsset).readAsBytesSync(),
      );
      final en = SpeciesSheets.fromGzip(
        File(speciesSheetsAssetEn).readAsBytesSync(),
      );
      expect(en.length, fr.length);
      expect(en['Erithacus rubecula']!.name, 'European Robin');
    });

    test('the provider loads the bundle of the species language', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final loaded = <String>[];
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        loaded.add(key);
        final name = key.contains('_en') ? 'Robin' : 'Rougegorge';
        final bytes = Uint8List.fromList(
          _gzip({
            'version': 1,
            'species': {
              'Erithacus rubecula': {'name': name, 'summary': 'x'},
            },
          }),
        );
        return ByteData.sublistView(bytes);
      });
      addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

      Future<String?> nameFor(String locale) async {
        final container = ProviderContainer(
          overrides: [
            effectiveSpeciesLocaleProvider.overrideWithValue(locale),
          ],
        );
        addTearDown(container.dispose);
        final sheets = await container.read(speciesSheetsProvider.future);
        return sheets['Erithacus rubecula']?.name;
      }

      expect(await nameFor('fr'), 'Rougegorge');
      expect(await nameFor('en'), 'Robin');
      expect(loaded, [speciesSheetsAsset, speciesSheetsAssetEn]);
      loaded.clear();
      // Other languages: no bundle read at all.
      expect(await nameFor('de'), isNull);
      expect(loaded, isEmpty);
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
    expect(find.text('Pour le reconnaître'), findsOneWidget);
    expect(find.text('Un chant flûté.'), findsOneWidget);
    expect(
      find.text('Fiche rédigée par IA : elle peut contenir des erreurs.'),
      findsOneWidget,
    );
  });

  testWidgets('English species page: English sheet and footer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveSpeciesLocaleProvider.overrideWithValue('en'),
          speciesSheetsProvider.overrideWith(
            (ref) async => const SpeciesSheets({
              'Erithacus rubecula': SpeciesSheet(
                name: 'European Robin',
                sections: {
                  SheetSection.summary: 'A small round bird.',
                  SheetSection.byEar: 'A fluty song.',
                },
              ),
            }),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SpeciesSheetSection(scientificName: 'Erithacus rubecula'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A small round bird.'), findsOneWidget);
    expect(find.text('A fluty song.'), findsOneWidget);
    expect(find.text('Written by AI: it may contain mistakes.'), findsOneWidget);
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
