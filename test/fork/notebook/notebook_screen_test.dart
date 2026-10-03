import 'dart:async';

import 'dart:io' show Platform;

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/inference/geo_abundance.dart';
import 'package:birdnet_live/fork/design/birdy_icons.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdygo_silhouette.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_block.dart'
    show BirdyProgressRing;
import 'package:birdnet_live/fork/design/widgets/birdy_pill.dart'
    show NoveltyPill;
import 'package:birdnet_live/fork/design/widgets/species_avatar.dart';
import 'package:birdnet_live/fork/design/widgets/species_card.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart' show SegmentedBar;
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_filter_chip.dart';
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

import '../helpers/fonts.dart';

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
    String lang = 'fr',
    String hint = 'Chante très fort pour sa petite taille.',
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    // Tall enough for the whole two-column grid (the sliver is lazy).
    tester.view.physicalSize = const Size(390, 1500) * 2;
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
            (ref) async => SpeciesSheets({
              'Troglodytes troglodytes': SpeciesSheet(
                name: 'Troglodyte mignon',
                sections: {},
                hint: hint,
              ),
            }),
          ),
          effectiveSpeciesLocaleProvider.overrideWith((ref) => lang),
          observationIndexServiceProvider.overrideWith(
            (ref) => _PendingIndex(prefs),
          ),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: Locale(lang),
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
    expect(find.text('2 oiseaux dans ton carnet'), findsOneWidget);
    final progressBlock = find.byKey(const ValueKey('notebook-progress-block'));
    expect(
      find.descendant(of: progressBlock, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: progressBlock,
        matching: find.textContaining('4 oiseaux vivent près de chez toi'),
      ),
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
    // The mystery card (Troglodyte mignon) draws the BirdyGo bird
    // silhouette, never a species-giving icon.
    // (Plus the mini one of the hero caption.)
    expect(find.byType(BirdyGoSilhouetteIcon), findsNWidgets(2));
    // The mystery card shows the « ? » (the 16 px hero one stays plain).
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('the mystery hint comes from the English bundle in English', (
    tester,
  ) async {
    await pump(tester, lang: 'en', hint: 'Sings very loudly for its size.');
    await tester.pumpAndSettle();
    expect(find.text('Sings very loudly for its size.'), findsOneWidget);
    expect(find.text('Chante très fort pour sa petite taille.'), findsNothing);
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
      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byType(BirdyFilterChip),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await pick('À trouver');
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

  testWidgets('the discovered filter is now labelled « Mes découvertes »', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Découvertes'), findsNothing);
    final chip = find.ancestor(
      of: find.text('Mes découvertes'),
      matching: find.byType(BirdyFilterChip),
    );
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Rougegorge familier'), findsOneWidget);
    expect(find.text('Huppe fasciée'), findsNothing);
  });

  testWidgets('the à découvrir and rares blocks pick their filter', (
    tester,
  ) async {
    await pump(tester);
    // 1 species to confirm (Huppe fasciée) + 1 mystery (Troglodyte mignon).
    await tester.tap(find.bySemanticsLabel('2 à trouver'));
    await tester.pumpAndSettle();
    expect(find.text('Rougegorge familier'), findsNothing);
    expect(find.text('Huppe fasciée'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('1 oiseau rare'));
    await tester.pumpAndSettle();
    expect(find.text('Huppe fasciée'), findsOneWidget);
    expect(find.text('Pic épeiche'), findsNothing);
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

  group('tile states (J6g-b)', () {
    testWidgets('discovered, to confirm and mystery look different', (
      tester,
    ) async {
      await pump(tester);
      final discovered = find.byKey(
        const ValueKey('notebook-discovered-Erithacus rubecula'),
      );
      final toConfirm = find.byKey(
        const ValueKey('notebook-toConfirm-Upupa epops'),
      );
      final mystery = find.byKey(
        const ValueKey('notebook-mystery-Troglodytes troglodytes'),
      );
      expect(discovered, findsOneWidget);
      expect(toConfirm, findsOneWidget);
      expect(mystery, findsOneWidget);
      // A check badge on a discovery, a question mark to confirm, the BirdyGo
      // silhouette (no badge) for a mystery.
      expect(
        find.descendant(of: discovered, matching: find.byIcon(BirdyIcons.tick)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toConfirm,
          matching: find.byIcon(BirdyIcons.help),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: mystery,
          matching: find.byType(BirdyGoSilhouetteIcon),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: mystery, matching: find.byIcon(BirdyIcons.tick)),
        findsNothing,
      );
      // Spoken states.
      expect(
        find.bySemanticsLabel('Rougegorge familier. Découverte. 142 fois'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Huppe fasciée. À confirmer. 1 fois')),
        findsOneWidget,
      );
    });

    testWidgets('a rare discovery wears a gold ring, a common one none', (
      tester,
    ) async {
      await pump(
        tester,
        expected: const [
          ExpectedSpecies(
            scientificName: 'Erithacus rubecula',
            commonName: 'Rougegorge familier',
            score: 0.04,
            tier: ExploreTier.rare,
          ),
          ExpectedSpecies(
            scientificName: 'Dendrocopos major',
            commonName: 'Pic épeiche',
            score: 0.5,
            tier: ExploreTier.common,
          ),
        ],
      );
      final robin = find.byKey(
        const ValueKey('notebook-discovered-Erithacus rubecula'),
      );
      final woodpecker = find.byKey(
        const ValueKey('notebook-discovered-Dendrocopos major'),
      );
      expect(
        find.descendant(
          of: robin,
          matching: find.byKey(const ValueKey('notebook-metal-ring')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: woodpecker,
          matching: find.byKey(const ValueKey('notebook-metal-ring')),
        ),
        findsNothing,
      );
    });

    testWidgets('the progress block is a ring and a segmented bar', (
      tester,
    ) async {
      await pump(tester);
      final block = find.byKey(const ValueKey('notebook-progress-block'));
      expect(
        find.descendant(of: block, matching: find.byType(BirdyProgressRing)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: block, matching: find.byType(SegmentedBar)),
        findsOneWidget,
      );
    });

    testWidgets('small phone, 130 %, dark: tiles and header do not overflow', (
      tester,
    ) async {
      await pump(tester, dark: true, textScale: 1.3);
      tester.view.physicalSize = const Size(320, 640) * 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('notebook-progress-block')),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(NotebookScreen)).width, 320);
    });
  });

  group('Carnet J6h', () {
    const heard = [
      HeardSpecies(
        scientificName: 'Erithacus rubecula',
        commonName: 'Rougegorge familier',
        contacts: 3,
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
        scientificName: 'Parus major',
        commonName: 'Mésange charbonnière',
        contacts: 1,
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
    const expected = [
      ExpectedSpecies(
        scientificName: 'Erithacus rubecula',
        commonName: 'Rougegorge familier',
        score: 0.2,
        tier: ExploreTier.scarce,
      ),
      ExpectedSpecies(
        scientificName: 'Dendrocopos major',
        commonName: 'Pic épeiche',
        score: 0.1,
        tier: ExploreTier.rare,
      ),
      ExpectedSpecies(
        scientificName: 'Upupa epops',
        commonName: 'Huppe fasciée',
        score: 0.9,
        tier: ExploreTier.abundant,
      ),
      ExpectedSpecies(
        scientificName: 'Troglodytes troglodytes',
        commonName: 'Troglodyte mignon',
        score: 0.8,
        tier: ExploreTier.abundant,
      ),
    ];

    testWidgets('rarity is written in words at the bottom of the card', (
      tester,
    ) async {
      await pump(tester, heard: heard, expected: expected);
      // Scarce = Peu commun, rare = Rare, absent from the geo-model's list
      // = Exceptionnel. « Nouveau » is not shown (first opening seeds).
      expect(find.text('Peu commun'), findsOneWidget);
      expect(find.text('Rare'), findsOneWidget);
      expect(find.text('Exceptionnel'), findsOneWidget);
      expect(find.byIcon(AppIcons.visibility), findsOneWidget);
      expect(find.byIcon(AppIcons.diamond), findsOneWidget);
      expect(find.byIcon(AppIcons.star), findsOneWidget);
      // No separate legend.
      expect(find.text('Peu commun ici'), findsNothing);
    });

    testWidgets('the grid has two columns', (tester) async {
      await pump(tester, heard: heard, expected: expected);
      // Order: Huppe (to confirm), Rougegorge | Pic, mystery | Mésange.
      Rect rect(String kind, String name) =>
          tester.getRect(find.byKey(ValueKey('notebook-$kind-$name')));
      final huppe = rect('toConfirm', 'Upupa epops');
      final robin = rect('discovered', 'Erithacus rubecula');
      final woodpecker = rect('discovered', 'Dendrocopos major');
      final tit = rect('discovered', 'Parus major');
      expect(robin.top, huppe.top);
      expect(robin.left, greaterThan(huppe.right));
      expect(woodpecker.top, greaterThan(huppe.top));
      expect(woodpecker.left, huppe.left);
      expect(tit.top, greaterThan(woodpecker.top));
      expect(tit.left, huppe.left);
    });

    testWidgets('« À trouver » counts and keeps mysteries and to-confirm', (
      tester,
    ) async {
      await pump(tester, heard: heard, expected: expected);
      // Huppe (to confirm) + Troglodyte (mystery).
      final count = find.byKey(const ValueKey('notebook-count-toDiscover'));
      expect(
        find.descendant(of: count, matching: find.text('2')),
        findsOneWidget,
      );
      await tester.tap(count);
      await tester.pumpAndSettle();
      expect(find.text('Huppe fasciée'), findsOneWidget);
      expect(find.text('Oiseau mystère'), findsOneWidget);
      expect(find.text('Rougegorge familier'), findsNothing);
      expect(find.text('2 cartes'), findsOneWidget);
    });

    testWidgets('the collection block carries its title and card count', (
      tester,
    ) async {
      await pump(tester, heard: heard, expected: expected);
      expect(find.text('Ma collection'), findsOneWidget);
      expect(find.text('5 cartes'), findsOneWidget);
      expect(find.byKey(const ValueKey('notebook-chips-fade')), findsOneWidget);
    });
  });
  group('uniform grid', () {
    setUpAll(() async {
      await loadAppFonts(icons: true);
    });

    const names = [
      ('Sp one', 'Pie', 1),
      ('Sp two', 'Rougegorge familier', 42),
      ('Sp three', 'Gobemouche à collier des jardins', 142),
      ('Sp four', 'Mésange à longue queue', 1234),
      ('Sp five', 'Roitelet huppé', 7),
      ('Sp six', 'Bergeronnette des ruisseaux', 99),
      ('Sp seven', 'Grimpereau des jardins', 3),
    ];
    final heard = [
      for (final (sci, common, n) in names)
        HeardSpecies(
          scientificName: sci,
          commonName: common,
          contacts: n,
          verified: sci != 'Sp six',
          inQueue: sci == 'Sp six' ? 1 : 0,
        ),
    ];
    final expected = [
      for (var i = 0; i < names.length; i++)
        ExpectedSpecies(
          scientificName: names[i].$1,
          commonName: names[i].$2,
          score: [0.9, 0.5, 0.04, 0.8, 0.02, 0.3, 0.6][i],
          tier: ExploreTier.values[i % ExploreTier.values.length],
        ),
      const ExpectedSpecies(
        scientificName: 'Sp mystery',
        commonName: 'Mystery',
        score: 0.7,
        tier: ExploreTier.common,
      ),
    ];
    // Only some species are already « seen », so the others wear « Nouveau ».
    final stored = <String, Object>{
      kNotebookSeenPref: ['Sp one', 'Sp three', 'Sp five'],
    };

    Future<void> pumpGrid(WidgetTester tester, {bool dark = false}) => pump(
      tester,
      heard: heard,
      expected: expected,
      stored: stored,
      dark: dark,
    );

    testWidgets('same size, same caption spot, centered visual', (
      tester,
    ) async {
      await pumpGrid(tester);
      final cards = find.byType(SpeciesCard);
      expect(cards.evaluate().length, greaterThanOrEqualTo(8));
      // Pills in some cards, none in others: the mix the grid must absorb.
      expect(find.byType(NoveltyPill), findsWidgets);
      final first = tester.getRect(cards.first);
      final firstAvatarDy =
          tester
              .getRect(
                find
                    .descendant(
                      of: cards.first,
                      matching: find.byType(SpeciesAvatar),
                    )
                    .first,
              )
              .center
              .dy -
          first.top;
      for (var i = 0; i < cards.evaluate().length; i++) {
        final card = cards.at(i);
        final rect = tester.getRect(card);
        expect(rect.size, first.size, reason: 'card $i size');
        // The visual is centered horizontally in its card.
        final avatar = find.descendant(
          of: card,
          matching: find.byType(SpeciesAvatar),
        );
        expect(
          tester.getRect(avatar.first).center.dx,
          closeTo(rect.center.dx, 0.5),
          reason: 'card $i visual',
        );
        // Same vertical spot too (ring or not, the visual box is the same).
        expect(
          tester.getRect(avatar.first).center.dy - rect.top,
          closeTo(firstAvatarDy, 0.5),
          reason: 'card $i visual top',
        );
        // The caption (« N fois », « À confirmer » or the hint) starts at
        // the same offset in every card.
        final caption = find.descendant(
          of: card,
          matching: find.byType(DefaultTextStyle),
        );
        expect(caption, findsWidgets);
      }
    });

    testWidgets('« N fois » sits at the same offset in every card', (
      tester,
    ) async {
      await pumpGrid(tester);
      final cards = find.byType(SpeciesCard);
      Offset? reference;
      var counted = 0;
      for (var i = 0; i < cards.evaluate().length; i++) {
        final card = cards.at(i);
        final times = find.descendant(
          of: card,
          matching: find.textContaining(RegExp(r'\d+ fois?$')),
        );
        if (times.evaluate().isEmpty) continue;
        counted++;
        final offset = tester.getTopLeft(times.first) - tester.getTopLeft(card);
        reference ??= offset;
        expect(offset, reference, reason: 'card $i');
      }
      expect(counted, greaterThanOrEqualTo(5));
    });

    testWidgets('all rows are as tall as each other, gaps are equal', (
      tester,
    ) async {
      await pumpGrid(tester);
      final cards = find.byType(SpeciesCard);
      final rects = [
        for (var i = 0; i < cards.evaluate().length; i++)
          tester.getRect(cards.at(i)),
      ];
      for (var i = 2; i < rects.length; i++) {
        expect(
          rects[i].top - rects[i - 2].bottom,
          closeTo(rects[2].top - rects[0].bottom, 0.01),
          reason: 'row gap before card $i',
        );
      }
      expect(
        rects[1].left - rects[0].right,
        closeTo(rects[2].top - rects[0].bottom, 0.01),
      );
    });

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'golden $mode',
        (tester) async {
          await pumpGrid(tester, dark: dark);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../goldens/notebook_grid_$mode.png'),
          );
        },
        tags: ['golden'],
        skip: !Platform.isWindows,
      );
    }
  });
}
