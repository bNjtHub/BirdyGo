import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/fork/species_photo/inat_photo_service.dart';
import 'package:birdnet_live/fork/species_photo/species_photo.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_config.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_providers.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_viewer.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/models/taxonomy_species.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

// The bundled photo is iNaturalist photo 2.
const _robin = TaxonomySpecies(
  scientificName: 'Erithacus rubecula',
  commonName: 'European Robin',
  birdnetId: 'BN00001',
  inatId: 13094,
  imageAuthor: 'Bundled Author',
  imageLicense: 'cc-by',
  imageSource: 'iNaturalist 2',
);

Map<String, dynamic> _photo(int id, String license) => {
  'id': id,
  'license_code': license,
  'attribution': '(c) Author $id, some rights reserved (CC BY)',
  'url': 'https://photos.example/$id/square.jpg',
  'original_dimensions': {'width': 2000, 'height': 1300},
};

/// 1 is not free to adapt, 2 is the bundled photo, 5 has no licence,
/// 8 would be a fifth extra.
final _taxon = {
  'id': 13094,
  'taxon_photos': [
    for (final (id, license) in [
      (1, 'cc-by-nd'),
      (2, 'cc-by'),
      (3, 'cc0'),
      (4, 'cc-by-sa'),
      (5, ''),
      (6, 'cc-by-nc'),
      (7, 'cc-by'),
      (8, 'cc-by'),
    ])
      {'photo': _photo(id, license)},
  ],
};

class _Service extends InatPhotoService {
  _Service(http.Client client, Directory dir)
    : super(client: client, cacheDir: () async => dir);

  @override
  Future<OnlinePhoto?> photoFor(int inatId) async => null;
}

class _Net {
  int apiCalls = 0;
  int obsCalls = 0;

  /// `results` of /v2/observations per "term:value" query (male "9:11",
  /// female "9:10", juvenile "1:8"); empty means the taxon photos fill in.
  Map<String, List<Map<String, dynamic>>> observations = {};
  final dir = Directory.systemTemp.createTempSync('gallery_');
  int downloads = 0;
  bool apiFails = false;

  /// When set, the API answers only once it completes.
  Completer<void>? gate;
  final agents = <String?>{};

  late final client = MockClient((request) async {
    agents.add(request.headers['User-Agent']);
    if (request.url.host == 'api.inaturalist.org') {
      apiCalls++;
      await gate?.future;
      if (apiFails) return http.Response('', 500);
      if (request.url.path == '/v2/observations') {
        obsCalls++;
        return http.Response(
          jsonEncode({
            'results':
                observations['${request.url.queryParameters['term_id']}:'
                    '${request.url.queryParameters['term_value_id']}'] ??
                const [],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'results': [_taxon],
        }),
        200,
      );
    }
    downloads++;
    return http.Response.bytes(
      _png,
      200,
      headers: {'content-type': 'image/png'},
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool allowed,
  required _Net net,
}) async {
  SharedPreferences.setMockInitialValues({kOnlinePhotosPref: allowed});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        inatPhotoServiceProvider.overrideWithValue(
          _Service(net.client, net.dir),
        ),
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
  await _settle(tester);
}

/// The gallery reads and writes files: real time must pass between pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    if (i > 5 &&
        find.byKey(const ValueKey('photo-loader')).evaluate().isEmpty) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Finder _dots() => find.byKey(const ValueKey('photo-dot-0'));

void main() {
  testWidgets('switch off: one photo, no dots, no request', (tester) async {
    final net = _Net();
    await _pump(tester, allowed: false, net: net);
    expect(_dots(), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(net.apiCalls + net.downloads, 0);
  });

  testWidgets('switch on: free licences, no duplicate, 4 extras, credit '
      'follows the page', (tester) async {
    final net = _Net();
    await _pump(tester, allowed: true, net: net);

    // 3, 4, 6, 7: no nd, no bundled photo (2), no unlicensed, max 4.
    expect(net.apiCalls, 4); // 3 targeted queries (none), then the taxon
    expect(net.downloads, 4);
    expect(net.agents, {AppConstants.networkUserAgent});
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('photo-dot-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('photo-dot-5')), findsNothing);
    expect(find.bySemanticsLabel('Photo 1 sur 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Crédit photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo : Bundled Author'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // close the sheet
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Crédit photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo : Author 3'), findsOneWidget);
    expect(find.text('Licence : CC0 1.0'), findsOneWidget);
    expect(find.text('Source : iNaturalist'), findsOneWidget);
  });

  testWidgets('tap opens the viewer on the page tapped; the carousel follows '
      'the page it closes on', (tester) async {
    final net = _Net();
    await _pump(tester, allowed: true, net: net);

    // Page 1 (bundled): the viewer opens on it, with its credit.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesPhotoViewer), findsOneWidget);
    expect(find.text('Bundled Author · CC BY · iNaturalist'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewer-close')));
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesPhotoViewer), findsNothing);

    // Swipe the carousel to page 2, tap: the viewer opens on page 2.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Photo 2 sur 5'), findsWidgets);
    expect(find.text('Author 3 · CC0 1.0 · iNaturalist'), findsOneWidget);

    // Swipe to page 3 inside the viewer, close: the carousel is on page 3.
    await tester.fling(
      find.descendant(
        of: find.byType(SpeciesPhotoViewer),
        matching: find.byType(PageView),
      ),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('viewer-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Crédit photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo : Author 4'), findsOneWidget);
  });

  testWidgets('switch off: tap opens the viewer on the bundled photo, '
      '(i) still opens the credit sheet', (tester) async {
    final net = _Net();
    await _pump(tester, allowed: false, net: net);
    await tester.tapAt(tester.getCenter(find.byType(SpeciesPhoto)));
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesPhotoViewer), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-dot-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('viewer-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Crédit photo'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesPhotoViewer), findsNothing);
    expect(find.text('Photo : Bundled Author'), findsOneWidget);
  });

  testWidgets('API failure: just the bundled photo', (tester) async {
    final net = _Net()..apiFails = true;
    await _pump(tester, allowed: true, net: net);
    expect(net.apiCalls, 4);
    expect(_dots(), findsNothing);
    expect(find.byType(PageView), findsNothing);
  });
  group('loading indicator', () {
    final loader = find.byKey(const ValueKey('photo-loader'));

    testWidgets('shown while pending (alone), gone after completion', (
      tester,
    ) async {
      final net = _Net()..gate = Completer<void>();
      await _pump(tester, allowed: true, net: net);
      expect(loader, findsOneWidget);
      expect(_dots(), findsNothing);
      expect(find.bySemanticsLabel('Chargement des photos'), findsOneWidget);

      net.gate!.complete();
      await _settle(tester);
      expect(loader, findsNothing);
      expect(_dots(), findsOneWidget);
    });

    testWidgets('gone after failure', (tester) async {
      final net =
          _Net()
            ..apiFails = true
            ..gate = Completer<void>();
      await _pump(tester, allowed: true, net: net);
      expect(loader, findsOneWidget);
      net.gate!.complete();
      await _settle(tester);
      expect(loader, findsNothing);
      expect(_dots(), findsNothing);
    });

    testWidgets('absent when the switch is off', (tester) async {
      await _pump(tester, allowed: false, net: _Net());
      expect(loader, findsNothing);
    });
  });
  group('labels', () {
    Map<String, dynamic> obs(int id, int? stage, {int? sex}) => {
      'annotations': [
        if (stage != null)
          {
            'controlled_attribute_id': 1,
            'controlled_value_id': stage,
            'vote_score': 1,
          },
        if (sex != null)
          {
            'controlled_attribute_id': 9,
            'controlled_value_id': sex,
            'vote_score': 0,
          },
      ],
      'photos': [_photo(id, 'cc-by')],
    };

    testWidgets('targeted queries: adults first, labels shown, no taxon '
        'request', (tester) async {
      final net =
          _Net()
            ..observations = {
              '9:11': [obs(21, 2, sex: 11), obs(22, 2, sex: 11)],
              '9:10': [obs(23, 2, sex: 10)],
              '1:8': [obs(20, 8)],
            };
      await _pump(tester, allowed: true, net: net);
      expect(net.obsCalls, 3);
      expect(net.apiCalls, 3); // 4 labelled picks: no taxon request
      // Order: 21 (male), 23 (female), 22 (spare adult), juvenile 20.
      expect(find.byKey(const ValueKey('photo-dot-5')), findsNothing);
      expect(find.byKey(const ValueKey('photo-dot-4')), findsOneWidget);
      // The first page is the bundled photo: no label.
      expect(find.byKey(const ValueKey('photo-label')), findsNothing);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Adulte · mâle'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Photo 2 sur 5, adulte · mâle'),
        findsWidgets,
      );
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Adulte · femelle'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Adulte'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Juvénile'), findsOneWidget);

      // The viewer shows the same label.
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SpeciesPhotoViewer),
          matching: find.text('Juvénile'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('observations request fails: taxon photos, no label', (
      tester,
    ) async {
      final net = _Net();
      // Fail only the observations request.
      final failing = MockClient((request) async {
        if (request.url.path == '/v2/observations') {
          net.obsCalls++;
          return http.Response('', 500);
        }
        return net.client
            .get(request.url, headers: request.headers)
            .then((r) => r);
      });
      SharedPreferences.setMockInitialValues({kOnlinePhotosPref: true});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inatPhotoServiceProvider.overrideWithValue(
              _Service(failing, net.dir),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 200,
                child: SpeciesPhoto(species: _robin),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(net.obsCalls, 3);
      expect(find.byKey(const ValueKey('photo-dot-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-label')), findsNothing);
    });
  });
}
