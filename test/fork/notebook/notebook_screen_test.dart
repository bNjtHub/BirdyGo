import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/inference/geo_abundance.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/notebook/notebook_loader.dart';
import 'package:birdnet_live/fork/notebook/notebook_model.dart';
import 'package:birdnet_live/fork/notebook/notebook_screen.dart';
import 'package:birdnet_live/fork/notebook/notebook_seen_store.dart';
import 'package:birdnet_live/fork/ranking/ranking_screen.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/fork/species_page/species_page_screen.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLoader implements NotebookLoader {
  _FakeLoader(this.species, this.expectedHere);

  final List<HeardSpecies> species;
  final List<ExpectedSpecies>? expectedHere;

  @override
  Future<List<HeardSpecies>> heard() async => species;

  @override
  Future<List<ExpectedSpecies>?> expected() async => expectedHere;

  @override
  Future<Set<String>> reviewKeysFor(String scientificName) async => {
    'key-$scientificName',
  };
}

/// Index that never opens and never notifies.
class _PendingIndex extends ObservationIndexService {
  _PendingIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

const _heard = [
  HeardSpecies(
    scientificName: 'Erithacus rubecula',
    commonName: 'Rougegorge familier',
    contacts: 142,
    verified: true,
    inQueue: 0,
  ),
  HeardSpecies(
    scientificName: 'Dendrocopos major',
    commonName: 'Pic épeiche',
    contacts: 2,
    verified: true,
    inQueue: 0,
  ),
  HeardSpecies(
    scientificName: 'Upupa epops',
    commonName: 'Huppe fasciée',
    contacts: 1,
    verified: false,
    inQueue: 1,
  ),
];

const _expected = [
  ExpectedSpecies(
    scientificName: 'Erithacus rubecula',
    commonName: 'Rougegorge familier',
    score: 0.9,
    tier: ExploreTier.abundant,
  ),
  ExpectedSpecies(
    scientificName: 'Dendrocopos major',
    commonName: 'Pic épeiche',
    score: 0.5,
    tier: ExploreTier.common,
  ),
  ExpectedSpecies(
    scientificName: 'Troglodytes troglodytes',
    commonName: 'Troglodyte mignon',
    score: 0.8,
    tier: ExploreTier.abundant,
  ),
  ExpectedSpecies(
    scientificName: 'Upupa epops',
    commonName: 'Huppe fasciée',
    score: 0.04,
    tier: ExploreTier.rare,
  ),
];

void main() {
  late SharedPreferences prefs;

  Future<_Pushes> pump(
    WidgetTester tester, {
    Map<String, Object> stored = const {},
    List<ExpectedSpecies>? expected = _expected,
    List<HeardSpecies> heard = _heard,
    bool dark = false,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final pushes = _Pushes();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notebookLoaderProvider.overrideWithValue(
            _FakeLoader(heard, expected),
          ),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          speciesSheetsProvider.overrideWith(
            (ref) async => const SpeciesSheets({
              'Troglodytes troglodytes': SpeciesSheet(
                name: 'Troglodyte mignon',
                sections: {},
                hint: 'Chante très fort pour sa petite taille.',
              ),
            }),
          ),
          effectiveSpeciesLocaleProvider.overrideWith((ref) => 'fr'),
          observationIndexServiceProvider.overrideWith(
            (ref) => _PendingIndex(prefs),
          ),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [pushes],
          builder:
              (context, app) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: app!,
              ),
          home: const NotebookScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pushes;
  }

  Future<Widget> pushedScreen(WidgetTester tester, _Pushes pushes) async {
    final route = pushes.routes.last as MaterialPageRoute<void>;
    final screen = route.builder(tester.element(find.byType(NotebookScreen)));
    await tester.pumpWidget(const SizedBox());
    return screen;
  }

  testWidgets('collection, progress and a mystery that keeps its secret', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Mon carnet'), findsOneWidget);
    expect(find.text('2 espèces découvertes'), findsOneWidget);
    expect(
      find.text('2 sur 4 espèces attendues ici cette semaine'),
      findsOneWidget,
    );
    expect(find.text('Rougegorge familier'), findsOneWidget);
    expect(find.text('142 fois'), findsOneWidget);
    expect(find.text('Huppe fasciée'), findsOneWidget);
    expect(find.text('À confirmer'), findsOneWidget);
    expect(
      find.text('Chante très fort pour sa petite taille.'),
      findsOneWidget,
    );
    expect(find.text('Troglodyte mignon'), findsNothing);
    // First opening: species found before the notebook are not « new ».
    expect(find.text('Nouveau'), findsNothing);
    expect(prefs.getStringList(kNotebookSeenPref), hasLength(2));
  });

  testWidgets('« Nouveau » stays until the card is opened', (tester) async {
    final pushes = await pump(
      tester,
      stored: {
        kNotebookSeenPref: ['Erithacus rubecula'],
      },
    );
    expect(find.text('Nouveau'), findsOneWidget);
    await tester.tap(find.text('Pic épeiche'));
    await tester.pump();
    expect(find.text('Nouveau'), findsNothing);
    expect(
      prefs.getStringList(kNotebookSeenPref),
      contains('Dendrocopos major'),
    );
    expect(await pushedScreen(tester, pushes), isA<SpeciesPage>());
  });

  testWidgets('a species to confirm opens its detections in the review', (
    tester,
  ) async {
    final pushes = await pump(tester);
    await tester.tap(find.text('Huppe fasciée'));
    await tester.pump();
    final screen = await pushedScreen(tester, pushes);
    expect(screen, isA<QuickReviewScreen>());
    expect((screen as QuickReviewScreen).onlyKeys, {'key-Upupa epops'});
  });

  testWidgets('filters', (tester) async {
    await pump(tester);
    Future<void> pick(String label) async {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await pick('À découvrir');
    expect(find.text('Rougegorge familier'), findsNothing);
    expect(find.text('Huppe fasciée'), findsOneWidget);
    expect(
      find.text('Chante très fort pour sa petite taille.'),
      findsOneWidget,
    );

    await pick('Rares');
    expect(find.text('Huppe fasciée'), findsOneWidget);
    expect(find.text('Pic épeiche'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Rare ici')), findsOneWidget);
  });

  testWidgets('without a place: no silhouettes, a note instead', (
    tester,
  ) async {
    await pump(tester, expected: null);
    expect(
      find.text('Sans ta position, les oiseaux attendus ici restent cachés.'),
      findsOneWidget,
    );
    expect(find.textContaining('attendues ici'), findsNothing);
    expect(find.text('Chante très fort pour sa petite taille.'), findsNothing);
  });

  testWidgets('empty notebook', (tester) async {
    await pump(tester, heard: const [], expected: null);
    expect(find.text("Ton carnet t'attend"), findsOneWidget);
  });

  testWidgets('the podium opens the Palmarès', (tester) async {
    final pushes = await pump(tester);
    await tester.tap(find.byTooltip('Palmarès'));
    expect(await pushedScreen(tester, pushes), isA<RankingScreen>());
  });

  testWidgets('dark at 130 % on a small phone: no overflow', (tester) async {
    await pump(tester, dark: true, textScale: 1.3);
    tester.view.physicalSize = const Size(320, 640) * 2;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mon carnet'), findsOneWidget);
  });
}
