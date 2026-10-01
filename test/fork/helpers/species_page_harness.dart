import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/species_page/species_clip_player.dart';
import 'package:birdnet_live/fork/species_page/species_page_loader.dart';
import 'package:birdnet_live/fork/species_page/species_page_model.dart';
import 'package:birdnet_live/fork/species_page/species_page_screen.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/world_map/world_regions.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/species_description_service.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared harness of the species page theme tests (goldens and contrast):
/// fixed clock, fake loader, player and index, one pump helper.
const String harnessRobin = 'Erithacus rubecula';

/// The page's clock in these tests.
final DateTime harnessNow = DateTime(2026, 9, 29, 9, 30);

class _Loader implements SpeciesPageLoader {
  _Loader({required this.recordValue, required this.year});

  final SpeciesRecord recordValue;
  final YearPresence? year;

  @override
  Future<SpeciesRecord> record(String scientificName) async => recordValue;

  @override
  Future<YearPresence?> presence(String scientificName) async => year;

  @override
  Future<bool> unexpectedNow(
    String scientificName, {
    required DateTime now,
  }) async => false;

  @override
  Future<bool> uncommonNow(
    String scientificName, {
    required DateTime now,
  }) async => true;

  @override
  Future<String?> lastConfirmedSession(String scientificName) async => null;

  @override
  Future<void> setFavorite(String key, {required bool favorite}) async {}
}

class _Player implements SpeciesClipPlayer {
  final _playing = ValueNotifier<String?>(null);

  @override
  ValueListenable<String?> get playing => _playing;

  @override
  Future<void> play(String clipPath) async {}

  @override
  Future<void> stop() async {}
}

class _PendingIndex extends ObservationIndexService {
  _PendingIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

class _Descriptions extends SpeciesDescriptionService {
  @override
  Future<String?> getDescription(String scientificName, String locale) async =>
      'Description upstream.';
}

IndexedDetection _clip(String key, double score, DateTime start) =>
    IndexedDetection(
      key: key,
      sessionId: 's',
      position: 0,
      scientificName: harnessRobin,
      commonName: 'Rougegorge familier',
      start: start,
      end: null,
      confidence: score,
      reviewStatus: ReviewStatus.unreviewed,
      latitude: 46.7,
      longitude: 1.2,
      clipPath: '/clips/$key.wav',
    );

/// A heard species: tally, two clips, hours, one spot.
SpeciesRecord harnessHeardRecord() => SpeciesRecord(
  tally: SpeciesTally(
    scientificName: harnessRobin,
    commonName: 'Rougegorge familier',
    contacts: 142,
    days: 38,
    first: DateTime(2026, 3, 1),
    last: DateTime(2026, 9, 28, 7, 42),
  ),
  confirmed: 37,
  reviewed: 38,
  verified: true,
  clips: [
    _clip('a', 0.97, DateTime(2026, 9, 28, 7, 42)),
    _clip('b', 0.95, DateTime(2026, 9, 20, 8, 5)),
  ],
  clipCount: 9,
  favorites: const {'a'},
  hours: [for (var h = 0; h < 24; h++) h == 7 ? 10 : (h > 4 && h < 11 ? 4 : h % 3)],
  spots: const [(latitude: 46.7, longitude: 1.2)],
);

final SpeciesSheet harnessSheet = SpeciesSheet.fromJson({
  'name': 'Rougegorge familier',
  'summary': 'Le petit oiseau à la gorge orange des jardins.',
  'size': '14 cm, à peu près comme un moineau.',
  'behaviour': 'Posé bas, il guette les vers dans la terre retournée.',
  'why_here': 'Les jardins et les lisières lui offrent des insectes toute l’année.',
  'enemies': 'Le chat, l’épervier et la pie.',
  'confusions': 'La gorgebleue à miroir, qui a le plastron bleu.',
  'migration': 'Une partie des oiseaux du nord passe l’hiver chez nous.',
  'anecdote': 'Il chante parfois la nuit, près des lampadaires.',
  'by_ear': 'Un filet de notes perlées, tristes et fines.',
});

/// Pumps the whole species page in the theme of [bird]. [heard] false shows
/// the never-heard state.
Future<void> pumpSpeciesPage(
  WidgetTester tester,
  BirdyBird bird,
  bool dark, {
  bool heard = true,
  Size size = const Size(412, 2700),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final loader = _Loader(
    recordValue: heard ? harnessHeardRecord() : SpeciesRecord.empty,
    year: YearPresence.fromWeeks([
      for (var w = 0; w < 48; w++)
        (w >= 8 && w <= 40)
            ? 0.2 + 0.8 * (1 - ((w - 20).abs() / 14)).clamp(0.0, 1.0)
            : 0.0,
    ]),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        worldMapPredictProvider.overrideWith((ref) async => null),
        worldRangesProvider.overrideWith((ref) async => null),
        worldRegionsProvider.overrideWith(
          (ref) async => WorldRegions(const [], const []),
        ),
        taxonomyServiceProvider.overrideWith(
          (ref) async =>
              TaxonomyService()..loadFromCsv(
                'scientific_name,common_name,ebird_code,inat_id\n'
                '$harnessRobin,Rougegorge familier,eurrob1,12716',
              ),
        ),
        effectiveSpeciesLocaleProvider.overrideWithValue('fr'),
        speciesSheetsProvider.overrideWith(
          (ref) async => SpeciesSheets({harnessRobin: harnessSheet}),
        ),
        speciesDescriptionServiceProvider.overrideWithValue(_Descriptions()),
        speciesPageLoaderProvider.overrideWithValue(loader),
        speciesClipPlayerProvider.overrideWithValue(_Player()),
        speciesMiniMapTilesProvider.overrideWithValue(null),
        observationIndexServiceProvider.overrideWith(
          (ref) => _PendingIndex(prefs),
        ),
        liveStateProvider.overrideWith((ref) => LiveState.ready),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? BirdyTheme.dark(bird: bird) : BirdyTheme.light(bird: bird),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
        home: SpeciesPage(
          scientificName: harnessRobin,
          commonName: 'Rougegorge familier',
          clock: () => harnessNow,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
