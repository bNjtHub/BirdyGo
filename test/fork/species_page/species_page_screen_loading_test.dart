/// Loading skeleton of the fiche espèce (J6f skeletons): the counters, the
/// recordings list and the activity/map area all wait on the loader's
/// `record()`, which resolves after the first frame. The photo and names
/// (`SpeciesPageHeader`) never wait on anything, so they are not covered
/// here.
library;

import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/species_page/species_clip_player.dart';
import 'package:birdnet_live/fork/species_page/species_page_loader.dart';
import 'package:birdnet_live/fork/species_page/species_page_model.dart';
import 'package:birdnet_live/fork/species_page/species_page_screen.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
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
import '../helpers/fonts.dart';

const _robin = 'Erithacus rubecula';

IndexedDetection _clip(String key, double score) => IndexedDetection(
  key: key,
  sessionId: 's',
  position: 0,
  scientificName: _robin,
  commonName: 'Rougegorge familier',
  start: DateTime.now().subtract(const Duration(hours: 1)),
  end: null,
  confidence: score,
  reviewStatus: ReviewStatus.unreviewed,
  latitude: 46.7,
  longitude: 1.2,
  clipPath: '/clips/$key.wav',
);

SpeciesRecord _heard() => SpeciesRecord(
  tally: SpeciesTally(
    scientificName: _robin,
    commonName: 'Rougegorge familier',
    contacts: 142,
    days: 38,
    first: DateTime(2026, 3, 1),
    last: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  confirmed: 37,
  reviewed: 38,
  verified: true,
  clips: [_clip('a', 0.97), _clip('b', 0.95)],
  clipCount: 9,
  favorites: const {'a'},
  hours: [for (var h = 0; h < 24; h++) h == 7 ? 10 : h % 3],
  spots: const [(latitude: 46.7, longitude: 1.2)],
);

/// `record()` resolves only once told to; `presence()`/`unexpectedNow()`
/// resolve at once, like the real screen's independent `_loadYear`.
class _DelayedLoader implements SpeciesPageLoader {
  _DelayedLoader(this._recordValue);

  final SpeciesRecord _recordValue;
  final _gate = Completer<void>();

  void resolve() => _gate.complete();

  @override
  Future<SpeciesRecord> record(String scientificName) async {
    await _gate.future;
    return _recordValue;
  }

  @override
  Future<YearPresence?> presence(String scientificName) async => null;

  @override
  Future<bool> unexpectedNow(String scientificName, {required DateTime now}) async =>
      false;

  @override
  Future<String?> lastConfirmedSession(String scientificName) async => null;

  @override
  Future<void> setFavorite(String key, {required bool favorite}) async {}
}

class _FakePlayer implements SpeciesClipPlayer {
  final _playing = ValueNotifier<String?>(null);

  @override
  ValueListenable<String?> get playing => _playing;

  @override
  Future<void> play(String clipPath) async => _playing.value = clipPath;

  @override
  Future<void> stop() async => _playing.value = null;
}

class _QuietIndex extends ObservationIndexService {
  _QuietIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() => Completer<ObservationIndex>().future;
}

class _NoDescriptions extends SpeciesDescriptionService {
  @override
  Future<String?> getDescription(String scientificName, String locale) async =>
      null;
}

void main() {
  setUpAll(loadAppFonts);

  late SharedPreferences prefs;
  late _DelayedLoader loader;

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    loader = _DelayedLoader(_heard());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // No geo-model in these tests: the world map block stays hidden.
          worldMapPredictProvider.overrideWith((ref) async => null),
          gbifIndexProvider.overrideWith((ref) async => null),
          gbifMetaProvider.overrideWith((ref) async => null),
          taxonomyServiceProvider.overrideWith((ref) async => TaxonomyService()),
          effectiveSpeciesLocaleProvider.overrideWithValue('fr'),
          speciesSheetsProvider.overrideWith((ref) async => SpeciesSheets({})),
          speciesDescriptionServiceProvider.overrideWithValue(_NoDescriptions()),
          speciesPageLoaderProvider.overrideWithValue(loader),
          speciesClipPlayerProvider.overrideWithValue(_FakePlayer()),
          speciesMiniMapTilesProvider.overrideWithValue(null),
          observationIndexServiceProvider.overrideWith((ref) => _QuietIndex(prefs)),
          liveStateProvider.overrideWith((ref) => LiveState.ready),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, app) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reducedMotion,
                ),
                child: app!,
              ),
          home: SpeciesPage(
            scientificName: _robin,
            commonName: 'Rougegorge familier',
          ),
        ),
      ),
    );
  }

  Future<void> expectStableLayout(WidgetTester tester) async {
    await tester.pump();
    final heard = tester.getRect(find.byKey(const ValueKey('fiche-heard')));
    final sounds = tester.getRect(find.byKey(const ValueKey('fiche-sounds')));

    loader.resolve();
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey('fiche-heard'))),
      heard,
      reason: 'counters block',
    );
    // The recordings list keeps its top; its bottom can settle once the
    // real recording count (2, not however many the skeleton reserved)
    // lands.
    final loadedSounds = tester.getRect(
      find.byKey(const ValueKey('fiche-sounds')),
    );
    expect(loadedSounds.top, sounds.top, reason: 'sounds block top');
    expect(loadedSounds.left, sounds.left, reason: 'sounds block left');
    expect(loadedSounds.right, sounds.right, reason: 'sounds block right');
    expect(find.text('Rougegorge familier'), findsOneWidget);
  }

  testWidgets('light, 100 %: no layout shift as the record lands', (
    tester,
  ) async {
    await pump(tester);
    await expectStableLayout(tester);
  });

  testWidgets('dark, 130 %: no layout shift as the record lands', (
    tester,
  ) async {
    await pump(tester, dark: true, textScale: 1.3);
    await expectStableLayout(tester);
  });

  testWidgets('reduced motion: nothing animates while loading', (
    tester,
  ) async {
    await pump(tester, reducedMotion: true);
    await tester.pump();
    final before = tester.getRect(
      find.byKey(const ValueKey('fiche-heard')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey('fiche-heard'))),
        before,
      );
    }
    loader.resolve();
    await tester.pumpAndSettle();
    expect(find.text('Rougegorge familier'), findsOneWidget);
  });
}
