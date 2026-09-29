import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_filter_chip.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_headers.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_list_block.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_list_row.dart';
import 'package:birdnet_live/fork/design/widgets/clip_play_button.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/sound_library/sound_library_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

IndexedDetection _clip(String key, double score, DateTime start) =>
    IndexedDetection(
      key: key,
      sessionId: 's',
      position: 0,
      scientificName: 'Erithacus rubecula',
      commonName: 'Rougegorge familier',
      start: start,
      end: null,
      confidence: score,
      reviewStatus: ReviewStatus.unreviewed,
      latitude: 47.21,
      longitude: -1.55,
      clipPath: '/clips/$key.wav',
    );

class _FakeIndex implements ObservationIndex {
  final favorites = <String>{'b'};
  final clips = [
    _clip('a', 0.91, DateTime(2026, 9, 20, 7)),
    _clip('b', 0.62, DateTime(2026, 9, 25, 8)),
  ];
  final asked = <({bool byDate, bool favoritesOnly})>[];

  /// Extra species without any favorite recording.
  bool withSecondSpecies = false;

  @override
  Future<
    List<({String scientificName, String commonName, int clips, int favorites})>
  >
  speciesWithClips() async => [
    (
      scientificName: 'Erithacus rubecula',
      commonName: 'Rougegorge familier',
      clips: 2,
      favorites: favorites.length,
    ),
    if (withSecondSpecies)
      (
        scientificName: 'Parus major',
        commonName: 'Mésange charbonnière',
        clips: 3,
        favorites: 0,
      ),
  ];

  @override
  Future<List<IndexedDetection>> clipsForSpecies(
    String scientificName, {
    bool byDate = false,
    bool favoritesOnly = false,
  }) async {
    asked.add((byDate: byDate, favoritesOnly: favoritesOnly));
    final list = [
      for (final c in clips)
        if (!favoritesOnly || favorites.contains(c.key)) c,
    ];
    if (byDate) list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  @override
  Future<Set<String>> favoriteKeys() async => {...favorites};

  @override
  Future<void> setFavorite(String key, {required bool favorite}) async =>
      favorite ? favorites.add(key) : favorites.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _IndexService extends ObservationIndexService {
  _IndexService(SharedPreferences prefs, this.index)
    : super(repository: SessionRepository(), prefs: prefs);

  final _FakeIndex index;

  @override
  Future<ObservationIndex> ensureReady() async => index;
}

class _NoGeo implements GeoPresenceService {
  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async => null;
}

void main() {
  late SharedPreferences prefs;
  late _FakeIndex index;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    index = _FakeIndex();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double textScale = 1,
    bool settle = true,
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith(
            (ref) => _IndexService(prefs, index),
          ),
          geoPresenceServiceProvider.overrideWithValue(_NoGeo()),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: const SoundLibraryScreen(),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('species list, then the clips of a species', (tester) async {
    await pump(tester);
    expect(find.text('Sonothèque'), findsOneWidget);
    expect(find.text('Rougegorge familier'), findsOneWidget);
    expect(find.text('2 enregistrements · 1 ★'), findsOneWidget);

    await tester.tap(find.text('Rougegorge familier'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipPlayButton), findsNWidgets(2));
    expect(find.textContaining('Score 0,91'), findsOneWidget);
    expect(find.textContaining('47.21° N, 1.55° O'), findsNWidgets(2));
    expect(find.text('Meilleur score'), findsOneWidget);
    expect(find.text('Plus récents'), findsOneWidget);
  });

  testWidgets('sort by date, favorites only, star a clip', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Rougegorge familier'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plus récents'));
    await tester.pumpAndSettle();
    expect(index.asked.last.byDate, isTrue);

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    expect(index.favorites, {'a', 'b'});

    await tester.tap(find.text('Favoris seulement'));
    await tester.pumpAndSettle();
    expect(index.asked.last.favoritesOnly, isTrue);
    expect(find.byTooltip('Retirer des favoris'), findsNWidgets(2));
  });

  testWidgets('empty library', (tester) async {
    index.clips.clear();
    index.favorites.clear();
    await pump(tester);
    // The fake still lists the species; the clips screen shows the message.
    await tester.tap(find.text('Rougegorge familier'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Pas encore d'enregistrement"), findsOneWidget);
  });

  testWidgets('dark at 130 %: no overflow', (tester) async {
    await pump(tester, dark: true, textScale: 1.3);
    await tester.tap(find.text('Rougegorge familier'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlay header, skeleton while loading, no spinner', (
    tester,
  ) async {
    await pump(tester, settle: false);
    expect(find.byType(BirdyOverlayHeader), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('soundLibrarySkeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('soundLibrarySkeleton')), findsNothing);
  });

  testWidgets('sort and favorites chips are BirdyFilterChips that toggle', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Rougegorge familier'));
    await tester.pumpAndSettle();
    BirdyFilterChip chip(String label) => tester.widget<BirdyFilterChip>(
      find.widgetWithText(BirdyFilterChip, label),
    );
    expect(chip('Meilleur score').selected, isTrue);
    expect(chip('Plus récents').selected, isFalse);
    await tester.tap(find.text('Plus récents'));
    await tester.pumpAndSettle();
    expect(chip('Plus récents').selected, isTrue);
    expect(chip('Favoris seulement').selected, isFalse);
    await tester.tap(find.text('Favoris seulement'));
    await tester.pumpAndSettle();
    expect(chip('Favoris seulement').selected, isTrue);
  });

  testWidgets('small phone, 130 %, dark: no overflow', (tester) async {
    await pump(tester, dark: true, textScale: 1.3, size: const Size(320, 640));
    await tester.tap(find.text('Rougegorge familier'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero counts recordings, species and favorites', (tester) async {
    index.withSecondSpecies = true;
    await pump(tester);
    final hero = find.byKey(const ValueKey('soundLibraryHero'));
    expect(hero, findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('5')), findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.text('enregistrements')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('2 espèces · 1 ★ favori')),
      findsOneWidget,
    );
  });

  testWidgets('species sit in one block, one row each', (tester) async {
    index.withSecondSpecies = true;
    await pump(tester);
    expect(find.byType(BirdyListBlock), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BirdyListBlock),
        matching: find.byType(BirdyListRow),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('favorites filter also applies to the species list', (
    tester,
  ) async {
    index.withSecondSpecies = true;
    await pump(tester);
    BirdyFilterChip chip(String label) => tester.widget<BirdyFilterChip>(
      find.widgetWithText(BirdyFilterChip, label),
    );
    expect(chip('Toutes').selected, isTrue);
    expect(find.text('Mésange charbonnière'), findsOneWidget);

    await tester.tap(find.text('Favoris seulement'));
    await tester.pumpAndSettle();
    expect(chip('Favoris seulement').selected, isTrue);
    expect(find.text('Rougegorge familier'), findsOneWidget);
    expect(find.text('Mésange charbonnière'), findsNothing);
    // The hero keeps the whole library's counts.
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('Toutes'));
    await tester.pumpAndSettle();
    expect(find.text('Mésange charbonnière'), findsOneWidget);
  });

  testWidgets('favorites filter without any favorite shows the empty state', (
    tester,
  ) async {
    index.favorites.clear();
    await pump(tester);
    await tester.tap(find.text('Favoris seulement'));
    await tester.pumpAndSettle();
    expect(find.text('Pas encore de favori'), findsOneWidget);
    expect(find.byType(BirdyListBlock), findsNothing);
    await tester.tap(find.text('Tous les enregistrements'));
    await tester.pumpAndSettle();
    expect(find.byType(BirdyListBlock), findsOneWidget);
  });
}
