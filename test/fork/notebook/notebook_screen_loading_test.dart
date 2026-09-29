/// Loading skeleton of the notebook (fix/j6f-b-notebook-loading): the
/// screen's layout must be settled from the first frame, most importantly
/// the « N sur M » progress block, whose total (the geo-model's expected
/// count) resolves after the rest of the screen.
library;

import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/inference/geo_abundance.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_block.dart'
    show BirdyProgressRing;
import 'package:birdnet_live/fork/notebook/notebook_loader.dart';
import 'package:birdnet_live/fork/notebook/notebook_model.dart';
import 'package:birdnet_live/fork/notebook/notebook_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/fonts.dart';

/// `heard()` and `expected()` resolve only when their completer is told to,
/// so a test can control exactly when each of the two async sources lands.
class _DelayedLoader implements NotebookLoader {
  _DelayedLoader({required this.heardResult, required this.expectedResult});

  final List<HeardSpecies> heardResult;
  final List<ExpectedSpecies>? expectedResult;

  final _heardGate = Completer<void>();
  final _expectedGate = Completer<void>();

  void resolveHeard() => _heardGate.complete();
  void resolveExpected() => _expectedGate.complete();

  @override
  Future<List<HeardSpecies>> heard() async {
    await _heardGate.future;
    return heardResult;
  }

  @override
  Future<List<ExpectedSpecies>?> expected() async {
    await _expectedGate.future;
    return expectedResult;
  }

  @override
  Future<Set<String>> reviewKeysFor(String scientificName) async => {};
}

class _PendingIndex extends ObservationIndexService {
  _PendingIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

// Fake scientific names, unknown to the real (bundled) taxonomy: `nameOf`
// then falls back to the short common name given here directly, instead of
// the real, possibly long, official name — keeping the first grid cell to
// one line, so its rect is a fair, deterministic comparison and not at the
// mercy of a species with a long enough name to wrap regardless of loading.
const _heard = [
  HeardSpecies(
    scientificName: 'Testus fakeprimus',
    commonName: 'Merle',
    contacts: 3,
    verified: true,
    inQueue: 0,
  ),
];

const _expected = [
  ExpectedSpecies(
    scientificName: 'Testus fakeprimus',
    commonName: 'Merle',
    score: 0.9,
    tier: ExploreTier.abundant,
  ),
  ExpectedSpecies(
    scientificName: 'Testus fakesecundus',
    commonName: 'Pie',
    score: 0.8,
    tier: ExploreTier.abundant,
  ),
];

/// Rects of every element the loading skeleton must reserve exactly: they
/// must be identical before and after the data lands.
class _Snapshot {
  _Snapshot(WidgetTester tester)
    : header = tester.getRect(find.byKey(const ValueKey('notebook-header'))),
      progressBlock = tester.getRect(
        find.byKey(const ValueKey('notebook-progress-block')),
      ),
      toDiscoverBlock = tester.getRect(
        find.byKey(const ValueKey('notebook-count-toDiscover')),
      ),
      rareBlock = tester.getRect(
        find.byKey(const ValueKey('notebook-count-rare')),
      ),
      filterChips = tester.getRect(
        find.byKey(const ValueKey('notebook-filter-chips')),
      ),
      firstGridCell = tester.getRect(
        find.byKey(const ValueKey('notebook-grid-cell-0')),
      );

  final Rect header;
  final Rect progressBlock;
  final Rect toDiscoverBlock;
  final Rect rareBlock;
  final Rect filterChips;
  final Rect firstGridCell;

  void expectUnchanged(_Snapshot other) {
    expect(other.header, header, reason: 'header');
    expect(other.progressBlock, progressBlock, reason: 'progress block');
    expect(other.toDiscoverBlock, toDiscoverBlock, reason: 'à trouver block');
    expect(other.rareBlock, rareBlock, reason: 'rares block');
    expect(other.filterChips, filterChips, reason: 'filter chips');
    expect(other.firstGridCell, firstGridCell, reason: 'first grid cell');
  }
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
    loader = _DelayedLoader(heardResult: _heard, expectedResult: _expected);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notebookLoaderProvider.overrideWithValue(loader),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
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
          builder:
              (context, app) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reducedMotion,
                ),
                child: app!,
              ),
          home: const NotebookScreen(),
        ),
      ),
    );
  }

  Future<void> expectStableLayout(WidgetTester tester) async {
    // First frame: nothing has resolved yet.
    await tester.pump();
    final firstFrame = _Snapshot(tester);

    // The rest of the screen (index, taxonomy) lands...
    loader.resolveHeard();
    await tester.pump();
    await tester.pump();
    firstFrame.expectUnchanged(_Snapshot(tester));

    // ...well before the geo-model's total (SPEC.md's "N sur M").
    loader.resolveExpected();
    await tester.pumpAndSettle();
    firstFrame.expectUnchanged(_Snapshot(tester));

    // The real numbers did take over.
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('2 oiseaux vivent'), findsOneWidget);
  }

  testWidgets('light, 100 %: no layout shift as heard then expected land', (
    tester,
  ) async {
    await pump(tester);
    await expectStableLayout(tester);
  });

  testWidgets('dark, 130 %: no layout shift as heard then expected land', (
    tester,
  ) async {
    await pump(tester, dark: true, textScale: 1.3);
    await expectStableLayout(tester);
  });

  testWidgets(
    'the total arriving after the discovered count does not resize the '
    'progress block',
    (tester) async {
      await pump(tester);
      await tester.pump();
      final loading = tester.getRect(
        find.byKey(const ValueKey('notebook-progress-block')),
      );

      // Heard-based numbers (the header's "N oiseaux dans ton carnet") land
      // first; the progress block ("N sur M") must still be a skeleton, at
      // its final height, since M (the geo-model's total) is not in yet.
      loader.resolveHeard();
      await tester.pump();
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('notebook-progress-block'))),
        loading,
      );
      expect(find.text('1 oiseau dans ton carnet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notebook-progress-skeleton')),
        findsOneWidget,
      );

      // The total lands: same block, same rect, real numbers fade in.
      loader.resolveExpected();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('notebook-progress-block'))),
        loading,
      );
      expect(find.textContaining('2 oiseaux vivent'), findsOneWidget);
    },
  );

  testWidgets(
    'the found count sits in the middle of the progress ring, loaded and '
    'while the skeleton is up',
    (tester) async {
      await pump(tester);
      await tester.pump();
      final block = find.byKey(const ValueKey('notebook-progress-block'));
      // While loading, the ring and the caption are skeletons (real glyphs
      // painted invisible over a filled background).
      expect(
        find.descendant(
          of: block,
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.style?.color == Colors.transparent,
          ),
        ),
        findsWidgets,
      );

      loader.resolveHeard();
      loader.resolveExpected();
      await tester.pumpAndSettle();

      final ring = find.descendant(
        of: block,
        matching: find.byType(BirdyProgressRing),
      );
      expect(ring, findsOneWidget);
      final number = find.descendant(of: ring, matching: find.text('1'));
      expect(number, findsOneWidget);
      expect(
        tester.getCenter(number).dx,
        closeTo(tester.getCenter(ring).dx, 0.5),
      );
      expect(
        tester.getCenter(number).dy,
        closeTo(tester.getCenter(ring).dy, 0.5),
      );
      expect(
        find.bySemanticsLabel('1 sur 2 espèces attendues trouvées'),
        findsOneWidget,
      );
    },
  );

  testWidgets('reduced motion: nothing animates while loading', (tester) async {
    await pump(tester, reducedMotion: true);
    await tester.pump();
    final before = tester.getRect(
      find.byKey(const ValueKey('notebook-progress-block')),
    );
    // A few frames of "loading": the static skeleton must not move or
    // change size on its own (no shimmer, no pulse: DESIGN.md forbids
    // animation loops).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey('notebook-progress-block'))),
        before,
      );
    }
    loader.resolveHeard();
    loader.resolveExpected();
    await tester.pumpAndSettle();
    expect(find.textContaining('2 oiseaux vivent'), findsOneWidget);
  });

  testWidgets('the loading state is announced once, skeletons excluded', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.pump();

    final data = tester.getSemantics(find.byType(NotebookScreen));
    String allLabels(SemanticsNode node) {
      final buffer = StringBuffer(node.label);
      node.visitChildren((child) {
        buffer.write(' ');
        buffer.write(allLabels(child));
        return true;
      });
      return buffer.toString();
    }

    expect(allLabels(data), contains('Chargement du carnet'));
    // The skeleton bars themselves carry no semantic label (their glyphs
    // are invisible placeholders, excluded from the tree).
    expect(allLabels(data), isNot(contains('00000000')));

    loader.resolveHeard();
    loader.resolveExpected();
    await tester.pumpAndSettle();
    final loaded = tester.getSemantics(find.byType(NotebookScreen));
    expect(allLabels(loaded), isNot(contains('Chargement du carnet')));
    handle.dispose();
  });
}
