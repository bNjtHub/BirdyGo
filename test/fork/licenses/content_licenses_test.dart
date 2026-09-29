import 'dart:io';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/licenses/content_licenses_screen.dart';
import 'package:birdnet_live/fork/licenses/licenses_model.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Fake taxonomy: no real model or bundle involved.
const _csv =
    '''birdnet_id,scientific_name,common_name,taxon_group,image_author,image_license,image_source,common_name_fr
BN00001,Parus major,Great Tit,Aves,Ann,cc-by,iNaturalist 11,Mésange charbonnière
BN00002,Turdus merula,Eurasian Blackbird,Aves,Bob,cc-by-sa,iNaturalist 12,Merle noir
BN00003,Erithacus rubecula,European Robin,Aves,Cy,cc-by-nc,iNaturalist 13,Rouge-gorge familier
BN00004,Sitta europaea,Nuthatch,Aves,Di,cc0,iNaturalist 14,Sittelle torchepot
BN00005,Pica pica,Magpie,Aves,Ed,© Macaulay Library,Macaulay Library ML5,Pie bavarde
BN00006,Not bundled,Ghost,Aves,Fy,cc-by,iNaturalist 16,Fantôme''';

const _assets = [
  'assets/species_images/BN00001.webp',
  'assets/species_images/BN00002.webp',
  'assets/species_images/BN00003.webp',
  'assets/species_images/BN00004.webp',
  'assets/species_images/BN00005.webp',
  'assets/species_images/dummy.webp',
];

void main() {
  final service = TaxonomyService()..loadFromCsv(_csv);
  final ids = bundledImageIds(_assets);

  test('only bundled images are listed, dummy ignored', () {
    expect(ids, {'BN00001', 'BN00002', 'BN00003', 'BN00004', 'BN00005'});
    final photos = licensedPhotos(service.allSpecies, ids, locale: 'fr');
    expect(photos.length, 5);
    expect(photos.any((p) => p.birdnetId == 'BN00006'), isFalse);
  });

  test('families group licenses', () {
    final photos = licensedPhotos(service.allSpecies, ids, locale: 'fr');
    final groups = groupByFamily(photos);
    expect(groups.keys.toList(), [
      LicenseFamily.by,
      LicenseFamily.bySa,
      LicenseFamily.byNc,
      LicenseFamily.cc0,
      LicenseFamily.reserved,
    ]);
    expect(LicenseFamily.of('cc-by-nc-sa-4.0'), LicenseFamily.byNc);
    expect(LicenseFamily.of('cc-by-nd'), LicenseFamily.byNd);
    expect(LicenseFamily.of('pd'), LicenseFamily.publicDomain);
    expect(LicenseFamily.of(''), isNull);
  });

  test('search ignores accents and matches any language', () {
    final photos = licensedPhotos(service.allSpecies, ids, locale: 'fr');
    expect(groupByFamily(photos, query: 'merle').values.single.single.birdnetId,
        'BN00002');
    expect(groupByFamily(photos, query: 'MESANGE').length, 1);
    expect(groupByFamily(photos, query: 'blackbird').length, 1);
    expect(groupByFamily(photos, query: 'zzz'), isEmpty);
  });

  Future<void> pump(WidgetTester tester, {Set<String>? bundled}) async {
    tester.view.physicalSize = const Size(780, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taxonomyServiceProvider.overrideWith((ref) async => service),
          bundledImageIdsProvider.overrideWith((ref) async => bundled ?? ids),
        ],
        child: MaterialApp(
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ContentLicensesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows grouped entries and other contents', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('licenses-by')), findsOneWidget);
    expect(find.byKey(const ValueKey('licenses-bySa')), findsOneWidget);
    expect(find.byKey(const ValueKey('licenses-photo-BN00002')), findsOneWidget);
    expect(find.byKey(const ValueKey('licenses-photo-BN00006')), findsNothing);
    expect(find.textContaining('Bob'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('licenses-other')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('licenses-code')), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('licenses-search')),
      'merle',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('licenses-photo-BN00002')), findsOneWidget);
    expect(find.byKey(const ValueKey('licenses-photo-BN00001')), findsNothing);
    expect(find.byKey(const ValueKey('licenses-by')), findsNothing);
  });

  testWidgets('no bundled photo shows a note', (tester) async {
    await pump(tester, bundled: <String>{});
    expect(find.text('Le pack de photos n\'est pas installé : aucune photo à créditer.'),
        findsOneWidget);
  });

  test('no "BirdNET Live" left in fr/en arb values except credits', () {
    const credits = {
      'aboutCreditsDescription',
      'aboutFundingDescription',
      'forkModifiedVersion',
    };
    for (final lang in ['fr', 'en']) {
      final lines = File('lib/l10n/app_$lang.arb').readAsLinesSync();
      for (final l in lines) {
        final m = RegExp(r'^\s*"([A-Za-z0-9_]+)":\s*"').firstMatch(l);
        if (m == null || credits.contains(m[1])) continue;
        if (l.contains('BirdNET Live')) {
          // Translator notes (@keys) are not user-visible.
          expect(m[1]!.startsWith('@'), isTrue, reason: '$lang ${m[1]}');
        }
      }
    }
  });
}
