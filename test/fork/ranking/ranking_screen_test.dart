import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_filter_chip.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_switch.dart';
import 'package:birdnet_live/fork/ranking/ranking_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SpeciesTally _tally(String name, int contacts, int days) => SpeciesTally(
  scientificName: name,
  commonName: name,
  contacts: contacts,
  days: days,
  first: DateTime(2025, 10, 4, 7),
  last: DateTime.now(),
);

class _FakeIndex implements ObservationIndex {
  _FakeIndex(this.tallies);

  final List<SpeciesTally> tallies;
  final calls = <({bool confirmedOnly, RankingOrder order})>[];

  @override
  Future<List<SpeciesTally>> speciesRanking({
    DateTime? from,
    DateTime? to,
    bool confirmedOnly = false,
    RankingOrder order = RankingOrder.contacts,
    int? limit,
  }) async {
    calls.add((confirmedOnly: confirmedOnly, order: order));
    final sorted = [...tallies];
    if (order == RankingOrder.days) {
      sorted.sort((a, b) => b.days.compareTo(a.days));
    }
    return sorted;
  }

  @override
  Future<Set<String>> speciesFirstHeardSince(DateTime since) async => {
    'Upupa epops',
  };

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

void main() {
  late SharedPreferences prefs;
  late _FakeIndex index;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    index = _FakeIndex([
      _tally('Erithacus rubecula', 58, 20),
      _tally('Turdus merula', 41, 25),
      _tally('Parus major', 37, 12),
      _tally('Troglodytes troglodytes', 29, 10),
      _tally('Upupa epops', 3, 2),
    ]);
  });

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double textScale = 1,
    Size size = const Size(390, 844),
    String locale = 'fr',
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
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
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: const RankingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('header, podium and the rows under it', (tester) async {
    await pump(tester);
    expect(find.text('Palmarès'), findsOneWidget);
    // Header count and rank 5.
    expect(find.text('5'), findsNWidgets(2));
    expect(find.text('espèces en 30 jours'), findsOneWidget);
    expect(find.textContaining('1 nouvelle en '), findsOneWidget);
    expect(find.textContaining(' · du '), findsOneWidget);
    // Podium: the first three with their counts.
    for (final (name, n) in [
      ('Erithacus rubecula', '58'),
      ('Turdus merula', '41'),
      ('Parus major', '37'),
    ]) {
      expect(find.text(name), findsOneWidget);
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('contacts'), findsNWidgets(3));
    // Rows 4 and 5, the hoopoe new this year.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Troglodytes troglodytes'), findsOneWidget);
    expect(find.text('Upupa epops'), findsOneWidget);
    expect(find.text('Nouveau cette année'), findsOneWidget);
    expect(find.text('par contacts'), findsOneWidget);
  });

  testWidgets('confirmed only and the period go to the index', (tester) async {
    await pump(tester);
    expect(index.calls.last.confirmedOnly, isFalse);
    await tester.tap(find.byType(BirdySwitch));
    await tester.pumpAndSettle();
    expect(index.calls.last.confirmedOnly, isTrue);

    await tester.tap(find.text('Tout'));
    await tester.pumpAndSettle();
    expect(find.text('espèces depuis le début'), findsOneWidget);
    expect(find.textContaining('depuis le 4 octobre 2025'), findsOneWidget);
  });

  testWidgets('sort by days from the sort button sheet', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Trier et filtrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jours'));
    await tester.pumpAndSettle();
    expect(index.calls.last.order, RankingOrder.days);
    expect(find.text('par jours'), findsOneWidget);
    // Merle first with 25 days.
    expect(find.text('25'), findsOneWidget);
    expect(find.text('jours'), findsNWidgets(3));
  });

  testWidgets('the « par contacts » control opens the same sheet', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('par contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Dernière écoute'), findsOneWidget);
    expect(find.text('Oiseaux seulement'), findsOneWidget);
  });

  testWidgets('period chip selection: the chosen one is in ink', (
    tester,
  ) async {
    await pump(tester);
    final c = BirdyColors.of(tester.element(find.byType(RankingScreen)));
    Color fillOf(String label) =>
        tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.ancestor(
                      of: find.text(label),
                      matching: find.byType(BirdyFilterChip),
                    ),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color!;
    expect(fillOf('30 jours'), c.text1);
    expect(fillOf('Tout'), c.surface1);
    await tester.tap(find.text('Tout'));
    await tester.pumpAndSettle();
    expect(fillOf('Tout'), c.text1);
    expect(fillOf('30 jours'), c.surface1);
  });

  testWidgets('no floating options row, Podium and Classement blocks', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('ranking-options')), findsNothing);
    expect(find.byType(PopupMenuButton<Object>), findsNothing);
    expect(find.text('Podium'), findsOneWidget);
    expect(find.text('Classement'), findsOneWidget);
    expect(find.text('Confirmées'), findsOneWidget);
    expect(find.byType(BirdySwitch), findsOneWidget);
  });

  testWidgets('one or two species: a smaller podium', (tester) async {
    index = _FakeIndex([_tally('Erithacus rubecula', 3, 1)]);
    await pump(tester);
    expect(find.text('espèce en 30 jours'), findsOneWidget);
    expect(find.text('Erithacus rubecula'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty period', (tester) async {
    index = _FakeIndex([]);
    await pump(tester);
    expect(find.textContaining('Aucun oiseau sur cette période'), findsOne);
  });

  testWidgets('English strings', (tester) async {
    await pump(tester, locale: 'en');
    expect(find.text('species in 30 days'), findsOneWidget);
    expect(find.text('by contacts'), findsOneWidget);
  });

  for (final (label, dark, scale, size) in [
    ('light', false, 1.0, const Size(390, 844)),
    ('dark at 130 %', true, 1.3, const Size(390, 844)),
    ('small phone at 130 %', false, 1.3, const Size(320, 640)),
  ]) {
    testWidgets('lays out without overflow: $label', (tester) async {
      await pump(tester, dark: dark, textScale: scale, size: size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'BirdyOverlayHeader shows the back button and the title at 130 % text',
    (tester) async {
      await pump(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.text('Palmarès'), findsOneWidget);
      expect(find.byTooltip('Retour'), findsOneWidget);
    },
  );
}
