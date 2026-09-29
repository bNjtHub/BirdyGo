/// Loading skeleton of the home screen (J6f skeletons): the hero, the goal
/// / série / à vérifier grid, the status block and « Aujourd'hui » must all
/// keep their final layout from the first frame, whether or not the user
/// turns out to have a last bird, a running série or anything to check.
library;

import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_providers.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/home/fork_home.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/home/home_model.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/fonts.dart';

/// `load()` resolves only when told to, so a test can control exactly when
/// the snapshot lands, independently from the game progress below.
class _DelayedLoader implements HomeLoader {
  _DelayedLoader(this.snapshot);

  final HomeSnapshot snapshot;
  final _gate = Completer<void>();

  void resolve() => _gate.complete();

  @override
  Future<HomeSnapshot> load() async {
    await _gate.future;
    return snapshot;
  }

  @override
  Future<String?> placeName() async => null;

  @override
  Future<DateTime?> sunrise() async => null;

  @override
  Future<DateTime?> sunset() async => null;
}

Streak _streak({int current = 9}) {
  final monday = DateTime(2026, 9, 14);
  return Streak(
    current: current,
    record: 12,
    calendar: [
      for (var i = 0; i < 14; i++)
        StreakDay(
          date: DateTime(monday.year, monday.month, monday.day + i),
          state: i == 13 ? StreakDayState.open : StreakDayState.listened,
          isToday: i == 13,
        ),
    ],
  );
}

GameProgress _game({Streak? streak}) => GameProgress(
  GameFacts(
    verifiedBirds: {for (var i = 0; i < 24; i++) 'Species $i'},
    dawnChoruses: 0,
    earlyStarts: 0,
    reviewed: 0,
    migrants: const {},
    streak: streak ?? _streak(),
  ),
);

const _today = DaySummary(
  species: 13,
  contacts: 52,
  newSpecies: 1,
  heard: [
    DaySpecies(
      scientificName: 'Erithacus rubecula',
      commonName: 'Rougegorge familier',
      contacts: 30,
    ),
    DaySpecies(
      scientificName: 'Parus major',
      commonName: 'Mésange charbonnière',
      contacts: 12,
    ),
  ],
);

HomeSnapshot _morning({int toVerify = 12}) => HomeSnapshot(
  today: _today,
  last: LastBird(
    detection: IndexedDetection(
      key: 'k',
      sessionId: 's',
      position: 0,
      scientificName: 'Erithacus rubecula',
      commonName: 'Rougegorge familier',
      start: DateTime.now().subtract(const Duration(minutes: 1)),
      end: null,
      confidence: 0.97,
      reviewStatus: ReviewStatus.unreviewed,
      latitude: 46.7,
      longitude: 1.2,
      clipPath: '/clips/robin.wav',
    ),
    level: ReliabilityLevel.sure,
    unexpected: false,
    total: 142,
  ),
  toVerify: toVerify,
);

class _PendingIndex extends ObservationIndexService {
  _PendingIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

/// Rects of every block the loading skeleton must reserve exactly: they
/// must be identical before and after the data lands.
class _Snapshot {
  _Snapshot(WidgetTester tester)
    : header = tester.getRect(find.byKey(const ValueKey('home-greeting'))),
      hero = tester.getRect(find.byKey(const ValueKey('home-last'))),
      grid = tester.getRect(find.byKey(const ValueKey('home-grid'))),
      status = tester.getRect(find.byKey(const ValueKey('home-status'))),
      today = tester.getRect(find.byKey(const ValueKey('home-today')));

  final Rect header;
  final Rect hero;
  final Rect grid;
  final Rect status;
  final Rect today;

  void expectUnchanged(_Snapshot other) {
    expect(other.header, header, reason: 'header');
    expect(other.hero, hero, reason: 'hero');
    expect(other.grid, grid, reason: 'grid');
    expect(other.status, status, reason: 'status');
    expect(other.today, today, reason: 'today');
  }
}

void main() {
  setUpAll(loadAppFonts);

  late SharedPreferences prefs;
  late _DelayedLoader loader;
  late Completer<GameProgress> gameGate;

  Future<void> pump(
    WidgetTester tester, {
    HomeSnapshot? snapshot,
    bool dark = false,
    double textScale = 1,
    double width = 390,
    bool reducedMotion = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Tall enough that every block is built and laid out without
    // scrolling, even in dark at 130 %: `ListView`'s `SliverList` only
    // builds children within the viewport (plus cache extent), and an
    // off-screen block would not be found by its key otherwise.
    tester.view.physicalSize = Size(width, 2400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    loader = _DelayedLoader(snapshot ?? _morning());
    gameGate = Completer<GameProgress>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeLoaderProvider.overrideWithValue(loader),
          gameProgressProvider.overrideWith((ref) => gameGate.future),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith(
            (ref) => _PendingIndex(prefs),
          ),
          dailyGoalProgressProvider.overrideWith((ref) async => const {}),
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
          home: const ForkHome(),
        ),
      ),
    );
  }

  Future<void> expectStableLayout(WidgetTester tester) async {
    // First frame: nothing has resolved yet. `pumpAndSettle` (not a bare
    // `pump`) so the blocks' entrance (BirdyEntrance.staggered, a slide +
    // scale) finishes before the comparison: it is a fixed-duration
    // animation with no pending future, so it settles on its own even
    // though the loader and the game progress are still pending.
    await tester.pump(const Duration(seconds: 1));
    final firstFrame = _Snapshot(tester);

    // The saved-session snapshot lands...
    loader.resolve();
    await tester.pump(const Duration(seconds: 1));
    firstFrame.expectUnchanged(_Snapshot(tester));

    // ...well before the game progress.
    gameGate.complete(_game());
    await tester.pump(const Duration(seconds: 1));
    firstFrame.expectUnchanged(_Snapshot(tester));

    // The real content did take over.
    expect(find.text('9'), findsWidgets); // série
    expect(find.text('12'), findsWidgets); // à vérifier
  }

  testWidgets('320 dp, 130 %: Nunito titles do not overflow', (tester) async {
    await pump(tester, textScale: 1.3, width: 320);
    loader.resolve();
    gameGate.complete(_game());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('light, 100 %: no layout shift as snapshot then game land', (
    tester,
  ) async {
    await pump(tester);
    await expectStableLayout(tester);
  });

  testWidgets('dark, 130 %: no layout shift as snapshot then game land', (
    tester,
  ) async {
    await pump(tester, dark: true, textScale: 1.3);
    await expectStableLayout(tester);
  });

  testWidgets(
    'the game progress arriving after the snapshot does not resize the '
    'grid or the status block',
    (tester) async {
      await pump(tester);
      await tester.pump(const Duration(seconds: 1));
      final grid = tester.getRect(find.byKey(const ValueKey('home-grid')));
      final status = tester.getRect(find.byKey(const ValueKey('home-status')));

      // The snapshot (hero, à vérifier) lands first; the série cell and
      // the status block must still be skeletons, at their final size,
      // since the game progress is not in yet.
      loader.resolve();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getRect(find.byKey(const ValueKey('home-grid'))), grid);
      expect(tester.getRect(find.byKey(const ValueKey('home-status'))), status);

      // The game progress lands: same blocks, same rects, real content
      // fades in.
      gameGate.complete(_game());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getRect(find.byKey(const ValueKey('home-grid'))), grid);
      expect(tester.getRect(find.byKey(const ValueKey('home-status'))), status);
    },
  );

  testWidgets('reduced motion: nothing animates while loading', (tester) async {
    await pump(tester, reducedMotion: true);
    await tester.pump();
    final before = tester.getRect(find.byKey(const ValueKey('home-today')));
    // A few frames of "loading": the static skeleton must not move or
    // change size on its own (no shimmer, no pulse: DESIGN.md forbids
    // animation loops).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(find.byKey(const ValueKey('home-today'))), before);
    }
    loader.resolve();
    gameGate.complete(_game());
    await tester.pump(const Duration(seconds: 1));
    // The real block took over (its numbers are split across several
    // `TextSpan`s, so a plural label alone, not the whole "13 espèces",
    // is what a single `Text` finder can match).
    expect(find.byKey(const ValueKey('home-today-real')), findsOneWidget);
    expect(find.textContaining('espèces'), findsWidgets);
  });

  testWidgets('the loading state is announced once, skeletons excluded', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    // `pumpAndSettle`, not a bare `pump`: at opacity 0 (the entrance's
    // first frame), a node is excluded from the semantics tree, which
    // would hide the header long before anything is actually loaded.
    await tester.pump(const Duration(seconds: 1));

    final data = tester.getSemantics(find.byType(ForkHome));
    String allLabels(SemanticsNode node) {
      final buffer = StringBuffer(node.label);
      node.visitChildren((child) {
        buffer.write(' ');
        buffer.write(allLabels(child));
        return true;
      });
      return buffer.toString();
    }

    expect(allLabels(data), contains("Chargement de l'accueil"));
    // The skeleton bars themselves carry no semantic label (their glyphs
    // are invisible placeholders, excluded from the tree).
    expect(allLabels(data), isNot(contains('00000000')));

    loader.resolve();
    gameGate.complete(_game());
    await tester.pump(const Duration(seconds: 1));
    final loaded = tester.getSemantics(find.byType(ForkHome));
    expect(allLabels(loaded), isNot(contains("Chargement de l'accueil")));
    handle.dispose();
  });

  testWidgets(
    'the rare case (no last bird, no série, 0 to check) collapses without '
    'crashing once loaded',
    (tester) async {
      await pump(tester, snapshot: const HomeSnapshot(today: DaySummary.empty));
      await tester.pump();
      loader.resolve();
      gameGate.complete(_game(streak: _streak(current: 0)));
      await tester.pump(const Duration(seconds: 1));

      // The hero and the grid's two right-hand cells are gone; the goal
      // cell alone still spans the grid's width.
      expect(find.byKey(const ValueKey('home-last')), findsNothing);
      expect(find.byKey(const ValueKey('home-streak-real')), findsNothing);
      expect(find.byKey(const ValueKey('home-to-check-real')), findsNothing);
      // The status block, on the other hand, is always shown once the
      // game progress resolves.
      expect(find.byKey(const ValueKey('home-status-real')), findsOneWidget);
    },
  );
}
