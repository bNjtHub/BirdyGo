import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/species_photo/inat_photo_service.dart';
import 'package:birdnet_live/fork/species_photo/photo_credit.dart';
import 'package:birdnet_live/fork/species_photo/species_photo.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_config.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_providers.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/models/taxonomy_species.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A 1×1 PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

const _robin = TaxonomySpecies(
  scientificName: 'Erithacus rubecula',
  commonName: 'European Robin',
  birdnetId: 'BN00001',
  inatId: 13094,
  imageAuthor: 'Ryan Schain',
  imageLicense: '© Macaulay Library',
  imageSource: 'Macaulay Library ML44599871',
);

const _onlineCredit = PhotoCredit(
  author: 'Ann',
  license: 'cc-by-sa',
  source: 'iNaturalist',
  pageUrl: 'https://www.inaturalist.org/photos/2',
);

class _FakePhotoService extends InatPhotoService {
  _FakePhotoService(this.photo)
    : super(
        client: MockClient((_) async => http.Response('', 500)),
        cacheDir: () async => Directory.systemTemp,
      );

  final OnlinePhoto? photo;
  final calls = <int>[];

  @override
  Future<OnlinePhoto?> photoFor(int inatId) async {
    calls.add(inatId);
    return photo;
  }
}

Future<void> _pumpPhoto(
  WidgetTester tester, {
  required bool allowed,
  required InatPhotoService service,
}) async {
  SharedPreferences.setMockInitialValues({kOnlinePhotosPref: allowed});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        inatPhotoServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: AspectRatio(
                aspectRatio: kSpeciesPhotoAspectRatio,
                child: SpeciesPhoto(species: _robin),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Lets real file reads and image decoding run until [done], then draws.
Future<void> _loadImagesUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switch off: no request, the bundled credit on a tap', (
    tester,
  ) async {
    final service = _FakePhotoService(null);
    await _pumpPhoto(tester, allowed: false, service: service);
    expect(service.calls, isEmpty);

    await tester.tap(find.byType(SpeciesPhoto));
    await tester.pumpAndSettle();
    expect(find.text('Crédit photo'), findsOneWidget);
    expect(find.text('Photo : Ryan Schain'), findsOneWidget);
    expect(find.text('Licence : Tous droits réservés'), findsOneWidget);
    expect(find.text('Source : Macaulay Library ML44599871'), findsOneWidget);
    expect(find.text('Voir la photo en ligne'), findsOneWidget);
  });

  testWidgets('turning the switch on in the credit sheet asks for the photo', (
    tester,
  ) async {
    final service = _FakePhotoService(null);
    await _pumpPhoto(tester, allowed: false, service: service);

    await tester.tap(find.byTooltip('Crédit photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photos en grand (en ligne)'));
    await tester.pumpAndSettle();
    expect(service.calls, [13094]);
  });

  testWidgets('the online photo fades in without moving, with its credit', (
    tester,
  ) async {
    final file =
        (await tester.runAsync(() async {
          final dir = await Directory.systemTemp.createTemp('species_photo_');
          final file = File('${dir.path}/13094_1.photo');
          await file.writeAsBytes(base64Decode(_png));
          return file;
        }))!;
    addTearDown(() => file.parent.deleteSync(recursive: true));
    final service = _FakePhotoService(OnlinePhoto(file, _onlineCredit));

    await _pumpPhoto(tester, allowed: true, service: service);
    final size = tester.getSize(find.byType(SpeciesPhoto));
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(opacity(), 0);
    await _loadImagesUntil(tester, () => opacity() == 1);

    expect(service.calls, [13094]);
    expect(opacity(), 1);
    expect(tester.getSize(find.byType(SpeciesPhoto)), size);

    await tester.tap(find.byType(SpeciesPhoto));
    await tester.pumpAndSettle();
    expect(find.text('Photo : Ann'), findsOneWidget);
    expect(find.text('Licence : CC BY-SA'), findsOneWidget);
    expect(find.text('Source : iNaturalist'), findsOneWidget);
  });
}
