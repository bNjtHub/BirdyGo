/// Loading skeleton of the palmarès (J6f skeletons): the header count and
/// the list both wait on `_load()` (the index plus the "new this year" set),
/// which resolves after the first frame; the header and chips
/// above the list must not move once it lands.
library;

import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/ranking/ranking_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadRealFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load(asset).then((d) => d));
    await loader.load();
  }

  await load('Fraunces', 'assets/fonts/Fraunces-Variable.ttf');
  await load('Nunito', 'assets/fonts/Nunito-Variable.ttf');
  await load(
    'AtkinsonHyperlegibleNext',
    'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
  );
}

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

  @override
  Future<List<SpeciesTally>> speciesRanking({
    DateTime? from,
    DateTime? to,
    bool confirmedOnly = false,
    RankingOrder order = RankingOrder.contacts,
    int? limit,
  }) async => tallies;

  @override
  Future<Set<String>> speciesFirstHeardSince(DateTime since) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `ensureReady()` resolves only once told to: the screen's `_load()` awaits
/// it before the ranking, its header count and its list can settle.
class _DelayedIndexService extends ObservationIndexService {
  _DelayedIndexService(SharedPreferences prefs, this._index)
    : super(repository: SessionRepository(), prefs: prefs);

  final _FakeIndex _index;
  final _gate = Completer<void>();

  void resolve() => _gate.complete();

  @override
  Future<ObservationIndex> ensureReady() async {
    await _gate.future;
    return _index;
  }
}

void main() {
  setUpAll(_loadRealFonts);

  late SharedPreferences prefs;
  late _DelayedIndexService service;

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final index = _FakeIndex([
      _tally('Erithacus rubecula', 58, 20),
      _tally('Turdus merula', 41, 25),
      _tally('Parus major', 37, 12),
    ]);
    service = _DelayedIndexService(prefs, index);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith((ref) => service),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, app) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: app!,
              ),
          home: const RankingScreen(),
        ),
      ),
    );
  }

  Future<void> expectStableLayout(WidgetTester tester) async {
    await tester.pump();
    final header = tester.getRect(find.byKey(const ValueKey('ranking-header')));
    final chips = tester.getRect(find.byKey(const ValueKey('ranking-chips')));

    service.resolve();
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey('ranking-header'))),
      header,
      reason: 'header',
    );
    // The count's caption (period + new-this-year, capped at 2 lines in
    // `RankingHeader`) can settle at 1 line instead of the skeleton's 2 once
    // the real sentence turns out short enough for this text scale: the
    // chips then sit a little higher than reserved, never lower.
    final loadedChips = tester.getRect(
      find.byKey(const ValueKey('ranking-chips')),
    );
    expect(loadedChips.left, chips.left, reason: 'chips left');
    expect(loadedChips.right, chips.right, reason: 'chips right');
    expect(
      loadedChips.top,
      lessThanOrEqualTo(chips.top),
      reason: 'chips must not move past where the skeleton reserved',
    );
    expect(
      chips.top - loadedChips.top,
      lessThan(24),
      reason: 'chips should not settle by more than one caption line',
    );
    expect(find.textContaining('espèces en 30 jours'), findsOneWidget);
  }

  testWidgets('light, 100 %: no layout shift as the ranking lands', (
    tester,
  ) async {
    await pump(tester);
    await expectStableLayout(tester);
  });

  testWidgets('dark, 130 %: no layout shift as the ranking lands', (
    tester,
  ) async {
    await pump(tester, dark: true, textScale: 1.3);
    await expectStableLayout(tester);
  });

  testWidgets('the loading state is announced once, skeletons excluded', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.pump();

    final data = tester.getSemantics(find.byType(RankingScreen));
    String allLabels(SemanticsNode node) {
      final buffer = StringBuffer(node.label);
      node.visitChildren((child) {
        buffer.write(' ');
        buffer.write(allLabels(child));
        return true;
      });
      return buffer.toString();
    }

    expect(allLabels(data), contains('Chargement du palmarès'));

    service.resolve();
    await tester.pumpAndSettle();
    final loaded = tester.getSemantics(find.byType(RankingScreen));
    expect(allLabels(loaded), isNot(contains('Chargement du palmarès')));
    handle.dispose();
  });
}
