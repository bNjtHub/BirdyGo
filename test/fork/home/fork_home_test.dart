import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_screen.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_block.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_providers.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_screen.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_buttons.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_headers.dart';
import 'package:birdnet_live/fork/design/widgets/birdygo_wordmark.dart';
import 'package:birdnet_live/fork/design/widgets/entrance.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/home/fork_home.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/home/home_model.dart';
import 'package:birdnet_live/fork/home/home_widgets.dart';
import 'package:birdnet_live/fork/profile/profile_screen.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loader with a fixed snapshot, place and sunrise.
class _FakeLoader implements HomeLoader {
  _FakeLoader(this.snapshot, {this.place, this.sunriseAt});

  final HomeSnapshot snapshot;
  final String? place;
  final DateTime? sunriseAt;

  @override
  Future<HomeSnapshot> load() async => snapshot;

  @override
  Future<String?> placeName() async => place;

  @override
  Future<DateTime?> sunrise() async => sunriseAt;
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
    DaySpecies(
      scientificName: 'Dendrocopos major',
      commonName: 'Pic épeiche',
      contacts: 10,
    ),
  ],
);

HomeSnapshot _morning({
  int toVerify = 12,
  bool withToday = true,
  String? clipPath = '/clips/robin.wav',
}) => HomeSnapshot(
  today: withToday ? _today : DaySummary.empty,
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
      clipPath: clipPath,
    ),
    level: ReliabilityLevel.sure,
    unexpected: false,
    total: 142,
  ),
  toVerify: toVerify,
);

/// This week (Monday 21 to Sunday 27 September 2026): six days of
/// listening, Sunday still open.
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

void main() {
  late SharedPreferences prefs;
  final fr = lookupAppLocalizations(const Locale('fr'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_Pushes> pump(
    WidgetTester tester, {
    HomeSnapshot? snapshot,
    String? place = 'Beaulieu-sur-Brenne',
    DateTime? sunrise,
    GameProgress? game,
    bool withGame = true,
    bool dark = false,
    double textScale = 1,
    Size size = const Size(390, 844),
    bool withGoal = false,
    bool reducedMotion = false,
    bool settle = true,
  }) async {
    if (withGoal) {
      await DailyGoalStore(prefs).save(
        DailyGoal.create(
          day: DateTime.now(),
          latitude: 46.7,
          longitude: 1.2,
          candidates: [
            for (var i = 0; i < 8; i++)
              DailyGoalSpecies(
                scientificName: 'Species $i',
                commonName: 'Bird $i',
                geoScore: .8 - i * .01,
                unexpected: false,
              ),
          ],
        ),
      );
    }
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final pushes = _Pushes();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeLoaderProvider.overrideWithValue(
            _FakeLoader(
              snapshot ?? _morning(),
              place: place,
              sunriseAt: sunrise,
            ),
          ),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith(
            (ref) => _PendingIndex(prefs),
          ),
          dailyGoalProgressProvider.overrideWith(
            (ref) async => {for (var i = 0; i < 5; i++) 'Species $i'},
          ),
          if (withGame)
            gameProgressProvider.overrideWith((ref) async => game ?? _game()),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [pushes],
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
    if (settle) await tester.pumpAndSettle();
    return pushes;
  }

  /// Pushed screens are not built: the tree is dropped before the next
  /// frame (they need the real app's services).
  Future<Widget> pushedScreen(WidgetTester tester, _Pushes pushes) async {
    final route = pushes.routes.last as MaterialPageRoute<void>;
    final screen = route.builder(tester.element(find.byType(ForkHome)));
    await tester.pumpWidget(const SizedBox());
    return screen;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the morning overview, block by block', (tester) async {
    await pump(tester, sunrise: DateTime(2026, 9, 26, 7, 36), withGoal: true);
    // Small logo row above the header, and the menu in the header's actions.
    expect(find.byType(BirdyGoWordmark), findsOneWidget);
    expect(find.bySemanticsLabel('BirdyGo'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(
      find.textContaining('· Beaulieu-sur-Brenne · lever du soleil 07:36'),
      findsOneWidget,
    );
    // Hero.
    expect(find.textContaining('Dernier oiseau entendu · '), findsOneWidget);
    expect(find.text('Erithacus rubecula'), findsOneWidget);
    expect(find.text('Sûr'), findsOneWidget);
    expect(find.text('142 au total'), findsOneWidget);
    expect(find.bySemanticsLabel('Réécouter'), findsOneWidget);
    // Grid.
    expect(find.text('Objectif du jour'), findsOneWidget);
    expect(find.bySemanticsLabel('5/8 espèces entendues'), findsOneWidget);
    expect(find.text('Encore 3 espèces'), findsOneWidget);
    for (final bird in ['Bird 5', 'Bird 6', 'Bird 7']) {
      expect(
        find.bySemanticsLabel('$bird : pas encore entendu'),
        findsOneWidget,
      );
    }
    expect(
      find.bySemanticsLabel(
        '9 jours de suite. Écoute 6 jours sur les 7 derniers',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('12 détections à vérifier, 2 min de revue'),
      findsOneWidget,
    );
    // Status, today, « Écouter ».
    await scrollTo(tester, find.byKey(const ValueKey('home-status-block')));
    expect(
      find.bySemanticsLabel(RegExp('24 espèces découvertes')),
      findsOneWidget,
    );
    await scrollTo(tester, find.text("Aujourd'hui"));
    expect(
      find.text('13 espèces · 52 contacts · 1 nouvelle', findRichText: true),
      findsOneWidget,
    );
    await scrollTo(tester, find.bySemanticsLabel('Pic épeiche'));
    expect(find.bySemanticsLabel('Mésange charbonnière'), findsOneWidget);
    expect(find.text('Écouter'), findsOneWidget);
  });

  testWidgets('no position: no sunrise in the date line', (tester) async {
    await pump(tester, place: null);
    expect(find.textContaining('lever du soleil'), findsNothing);
  });

  testWidgets('no clip: no « Réécouter »', (tester) async {
    await pump(tester, snapshot: _morning(clipPath: null));
    expect(find.bySemanticsLabel('Réécouter'), findsNothing);
    expect(find.text('142 au total'), findsOneWidget);
  });

  testWidgets('« Écouter » starts listening at once', (tester) async {
    final pushes = await pump(tester);
    await tester.tap(find.text('Écouter'));
    final screen = await pushedScreen(tester, pushes);
    expect(screen, isA<LiveScreen>());
    expect((screen as LiveScreen).forceAutoStart, isTrue);
  });

  testWidgets('the to-check block opens the quick review', (tester) async {
    final pushes = await pump(tester);
    await scrollTo(tester, find.byKey(const ValueKey('home-to-check')));
    await tester.tap(find.byKey(const ValueKey('home-to-check')));
    final screen = await pushedScreen(tester, pushes);
    expect(screen, isA<QuickReviewScreen>());
    expect((screen as QuickReviewScreen).onlyKeys, isNull);
  });

  testWidgets('the série block opens the profile', (tester) async {
    final pushes = await pump(tester);
    await scrollTo(tester, find.byKey(const ValueKey('home-streak')));
    await tester.tap(find.byKey(const ValueKey('home-streak')));
    expect(await pushedScreen(tester, pushes), isA<ProfileScreen>());
  });

  testWidgets('the goal block opens the listening checklist', (tester) async {
    final pushes = await pump(tester);
    await scrollTo(tester, find.text('Objectif du jour'));
    await tester.tap(find.text('Objectif du jour'));
    expect(await pushedScreen(tester, pushes), isA<DailyGoalScreen>());
  });

  testWidgets('no goal yet: an invitation in the goal block', (tester) async {
    await pump(tester);
    expect(find.text(fr.forkDailyGoalInvite), findsOneWidget);
    expect(find.text(fr.forkDailyGoalStart), findsOneWidget);
  });

  testWidgets('nothing to check, no série: the goal takes the full width', (
    tester,
  ) async {
    await pump(
      tester,
      snapshot: _morning(toVerify: 0),
      game: _game(streak: _streak(current: 0)),
      withGoal: true,
    );
    expect(find.byKey(const ValueKey('home-to-check')), findsNothing);
    expect(find.byKey(const ValueKey('home-streak')), findsNothing);
    expect(
      tester.getSize(find.byType(DailyGoalBlock)).width,
      390 - 2 * BirdySpace.page,
    );
  });

  testWidgets('no bird today: an invitation, the last bird stays', (
    tester,
  ) async {
    await pump(tester, snapshot: _morning(withToday: false), place: null);
    await scrollTo(tester, find.textContaining('Aucun oiseau pour l'));
    expect(find.text("Aujourd'hui"), findsNothing);
    expect(find.text('Rougegorge familier'), findsOneWidget);
    expect(find.textContaining('Beaulieu'), findsNothing);
  });

  testWidgets('first launch: nothing yet, « Écouter » still there', (
    tester,
  ) async {
    await pump(tester, snapshot: const HomeSnapshot(), withGame: false);
    expect(find.textContaining('Aucun oiseau'), findsOneWidget);
    expect(find.textContaining('Dernier oiseau entendu'), findsNothing);
    expect(find.text('Écouter'), findsOneWidget);
  });

  testWidgets('the menu keeps every upstream entry', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    for (final label in [
      fr.sessionLibraryTitle,
      fr.forkRanking,
      fr.forkMap,
      fr.forkQuickReview,
      fr.forkSoundLibrary,
      fr.forkGardenTitle,
      fr.exploreMode,
      fr.pointCountMode,
      fr.surveyMode,
      fr.aruMode,
      fr.fileAnalysisMode,
      fr.settings,
      fr.helpTitle,
      fr.about,
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  for (final (name, dark, textScale, size) in [
    ('dark theme', true, 1.0, const Size(390, 844)),
    ('text at 130 %', false, 1.3, const Size(360, 740)),
    ('dark, text at 130 %', true, 1.3, const Size(360, 740)),
    ('small phone at 130 %', false, 1.3, const Size(320, 568)),
    ('landscape at 130 %', false, 1.3, const Size(844, 390)),
    ('tablet', true, 1.0, const Size(1024, 1366)),
  ]) {
    testWidgets('lays out without overflow: $name', (tester) async {
      await pump(
        tester,
        dark: dark,
        textScale: textScale,
        size: size,
        withGoal: true,
        sunrise: DateTime(2026, 9, 26, 7, 36),
      );
      expect(tester.takeException(), isNull);
      await scrollTo(tester, find.byType(DailyGoalBlock));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp('^Bird 5 ')), findsOneWidget);
      expect(find.text('Écouter'), findsOneWidget);
      // « Écouter » stays on screen, within reach of the thumb.
      expect(
        tester.getBottomLeft(find.text('Écouter')).dy,
        lessThan(size.height),
      );
      // Scrolling to the end lays out every block.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('block order: greeting, hero, grid, status, today', (
    tester,
  ) async {
    await pump(tester, withGoal: true, size: const Size(390, 2000));
    final tops = [
      for (final key in ['greeting', 'last', 'grid', 'status', 'today'])
        tester.getTopLeft(find.byKey(ValueKey('home-$key'))).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]));
    }
    // 10 dp between blocks, 16 dp page margin.
    final greeting = tester.getRect(find.byType(BirdyTabHeader));
    final hero = tester.getRect(find.byType(HomeHero));
    expect(hero.top - greeting.bottom, BirdySpace.block);
    expect(hero.left, BirdySpace.page);
  });

  testWidgets('« Écouter » is a 72 dp pill pinned outside the scroll', (
    tester,
  ) async {
    await pump(tester, withGoal: true);
    final button = find.ancestor(
      of: find.text('Écouter'),
      matching: find.byType(FilledButton),
    );
    expect(tester.getSize(button).height, BirdySizes.listen);
    expect(
      find.ancestor(of: button, matching: find.byType(Scrollable)),
      findsNothing,
    );
    final before = tester.getTopLeft(button);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(button), before);
    // The only strong action of the screen.
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets(
    'the « Écouter » glow has room: not clipped by the bottom bar (J6f)',
    (tester) async {
      await pump(tester, withGoal: true);
      final button = find.byType(ListenButton);
      // The Padding directly wrapping the button (nearest ancestor).
      final padding =
          tester
              .widgetList<Padding>(
                find.ancestor(of: button, matching: find.byType(Padding)),
              )
              .first;
      // Centered: the same room above and below, and at least the glow's
      // reach (offset + blur), or the bottom navigation bar covers it.
      final glow = BirdyColors.light.listenGlow
          .map((s) => s.offset.dy + s.blurRadius)
          .reduce((a, b) => a > b ? a : b);
      expect(glow, lessThanOrEqualTo(BirdyColors.listenGlowExtent));
      final insets = padding.padding as EdgeInsets;
      expect(insets.top, insets.bottom);
      expect(insets.bottom, greaterThanOrEqualTo(BirdyColors.listenGlowExtent));
      // No hard clip between the button and the screen: the glow can
      // paint past the button's own box.
      expect(
        find.ancestor(of: button, matching: find.byType(ClipRect)),
        findsNothing,
      );
    },
  );

  testWidgets('blocks rise once, five at most, 40 ms apart', (tester) async {
    await pump(tester, withGoal: true, settle: false);
    final entrances = tester.widgetList<BirdyEntrance>(
      find.byType(BirdyEntrance),
    );
    expect(entrances, isNotEmpty);
    expect(entrances.length, lessThanOrEqualTo(5));
    expect(entrances.map((e) => e.delay.inMilliseconds), [
      for (var i = 0; i < entrances.length; i++) i * 40,
    ]);
    await tester.pumpAndSettle();
    // Nothing loops: the screen settles.
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: no entrance at all', (tester) async {
    await pump(tester, withGoal: true, reducedMotion: true, settle: false);
    await tester.pump();
    expect(find.byType(BirdyEntrance), findsNothing);
    expect(find.text('Objectif du jour'), findsOneWidget);
  });
}
