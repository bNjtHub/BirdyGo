import 'dart:async';
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

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

const _robin = TaxonomySpecies(
  scientificName: 'Erithacus rubecula',
  commonName: 'European Robin',
  birdnetId: 'BN00001',
  inatId: 13094,
);

GalleryPhoto _photo(int i) => GalleryPhoto(
  base64Decode(_png),
  PhotoCredit(
    author: 'A$i',
    license: 'cc-by',
    source: 'iNaturalist',
    pageUrl: 'https://www.inaturalist.org/photos/$i',
  ),
);

List<GalleryPhoto> _n(int n) => [for (var i = 1; i <= n; i++) _photo(i)];

class _Service extends InatPhotoService {
  _Service(this.stream)
    : super(
        client: MockClient((_) async => http.Response('', 500)),
        cacheDir: () async => Directory.systemTemp,
      );

  final Stream<List<GalleryPhoto>> stream;

  @override
  Future<OnlinePhoto?> photoFor(int inatId) async => null;

  @override
  Stream<List<GalleryPhoto>> galleryFor(
    int inatId, {
    Set<String> exclude = const {},
  }) => stream;
}

Future<void> _pump(
  WidgetTester tester,
  Stream<List<GalleryPhoto>> stream,
) async {
  SharedPreferences.setMockInitialValues({kOnlinePhotosPref: true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        inatPhotoServiceProvider.overrideWithValue(_Service(stream)),
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

/// Number of page dots on screen (0 when none).
int _dotCount(WidgetTester tester) =>
    [
      for (var d = 0; d < 8; d++)
        if (find.byKey(ValueKey('photo-dot-$d')).evaluate().isNotEmpty) d,
    ].length;

int _pageCount(WidgetTester tester) {
  final view = find.byType(PageView);
  if (view.evaluate().isEmpty) return 1;
  return tester.widget<PageView>(view).childrenDelegate.estimatedChildCount!;
}

Future<void> _emit(
  WidgetTester tester,
  StreamController<List<GalleryPhoto>> c,
  int n,
) async {
  c.add(_n(n));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('1,2,4,5 emissions: bundled, then directly 5 pages', (
    tester,
  ) async {
    final c = StreamController<List<GalleryPhoto>>();
    addTearDown(() => c.close().ignore());
    await _pump(tester, c.stream);
    final seen = <int>{};
    for (final n in [1, 2, 3, 4]) {
      await _emit(tester, c, n);
      seen.add(_dotCount(tester));
      expect(_pageCount(tester), 1, reason: 'hidden while loading ($n)');
    }
    unawaited(c.close());
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      seen.add(_dotCount(tester));
    }
    expect(seen.difference({0, 5}), isEmpty);
    expect(_pageCount(tester), 5);
    expect(_dotCount(tester), 5);
  });

  testWidgets('emissions after the reveal are ignored for this visit', (
    tester,
  ) async {
    final c = StreamController<List<GalleryPhoto>>.broadcast();
    addTearDown(() => c.close().ignore());
    await _pump(tester, c.stream);
    await _emit(tester, c, 3);
    await tester.pump(kCarouselRevealTimeout + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_pageCount(tester), 4);
    await _emit(tester, c, 4);
    await _emit(tester, c, 5);
    unawaited(c.close());
    await tester.pumpAndSettle();
    expect(_pageCount(tester), 4);
    expect(_dotCount(tester), 4);
  });

  testWidgets('complete gallery: frozen, a later refresh is ignored', (
    tester,
  ) async {
    // Cache hit: the whole list at once, then the stream ends; nothing the
    // provider could add afterwards changes the page count.
    final c = StreamController<List<GalleryPhoto>>();
    addTearDown(() => c.close().ignore());
    await _pump(tester, c.stream);
    await _emit(tester, c, 4);
    unawaited(c.close());
    await tester.pumpAndSettle();
    expect(_pageCount(tester), 5);
    expect(find.byKey(const ValueKey('photo-loader')), findsNothing);
  });
}
