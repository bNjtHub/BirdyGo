import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_screen.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/home/fork_home.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/home/home_model.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/fork/notebook/notebook_loader.dart';
import 'package:birdnet_live/fork/notebook/notebook_model.dart';
import 'package:birdnet_live/fork/notebook/notebook_screen.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/profile/profile_screen.dart';
import 'package:birdnet_live/fork/shell/fork_nav_bar.dart';
import 'package:birdnet_live/fork/shell/fork_shell.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/l10n/app_localizations_fr.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHome implements HomeLoader {
  @override
  Future<HomeSnapshot> load() async =>
      const HomeSnapshot(today: DaySummary.empty, last: null, toVerify: 0);

  @override
  Future<String?> placeName() async => null;

  @override
  Future<DateTime?> sunrise() async => null;

  @override
  Future<DateTime?> sunset() async => null;
}

class _FakeNotebook implements NotebookLoader {
  _FakeNotebook([this._heard = const []]);

  final List<HeardSpecies> _heard;

  @override
  Future<List<HeardSpecies>> heard() async => _heard;

  @override
  Future<List<ExpectedSpecies>?> expected() async => null;

  @override
  Future<Set<String>> reviewKeysFor(String scientificName) async => {};
}

/// Index that never opens and never notifies.
class _PendingIndex extends ObservationIndexService {
  _PendingIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<HeardSpecies> heard = const [],
    double width = 390,
    bool reducedMotion = false,
    LiveState? liveState,
    NavigatorObserver? observer,
    bool settle = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = Size(width, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (liveState != null)
            liveStateProvider.overrideWith((ref) => liveState),
          homeLoaderProvider.overrideWithValue(_FakeHome()),
          notebookLoaderProvider.overrideWithValue(_FakeNotebook(heard)),
          gameProgressProvider.overrideWith(
            (ref) async => GameProgress(
              GameFacts(
                verifiedBirds: {for (var i = 0; i < 24; i++) 'Species $i'},
                dawnChoruses: 0,
                earlyStarts: 0,
                reviewed: 0,
                migrants: const {},
                streak: const Streak(current: 9, record: 12, calendar: []),
              ),
            ),
          ),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith(
            (ref) => _PendingIndex(prefs),
          ),
        ],
        child: MaterialApp(
          navigatorObservers: [if (observer != null) observer],
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reducedMotion),
                child: child!,
              ),
          home: const ForkShell(),
        ),
      ),
    );
    // The listening wing loops while active: nothing settles then.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Finder tab(String label) =>
      find.descendant(of: find.byType(ForkNavBar), matching: find.text(label));

  testWidgets('four tabs, Accueil first, the others built on first visit', (
    tester,
  ) async {
    await pump(tester);
    for (final label in ['Accueil', 'Carnet', 'Carte', 'Profil']) {
      expect(tab(label), findsOneWidget, reason: label);
    }
    expect(find.byType(ForkHome), findsOneWidget);
    expect(find.byType(NotebookScreen), findsNothing);
    // The map loads its tiles only when opened.
    expect(find.byType(ContactMapScreen, skipOffstage: false), findsNothing);

    await tester.tap(tab('Carnet'));
    await tester.pumpAndSettle();
    expect(find.text('Mon carnet'), findsOneWidget);

    await tester.tap(tab('Profil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    // The notebook stays alive behind.
    expect(find.byType(NotebookScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(ContactMapScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('back from another tab returns to Accueil', (tester) async {
    await pump(tester);
    await tester.tap(tab('Carnet'));
    await tester.pumpAndSettle();
    expect(find.text('Mon carnet'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('Mon carnet'), findsNothing);
    expect(find.byType(ForkHome), findsOneWidget);
    expect(
      tester.widget<ForkNavBar>(find.byType(ForkNavBar)).selected.index,
      0,
    );
  });

  testWidgets('home: série and status blocks open the Profil tab', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('jours de suite'), findsOneWidget);
    expect(find.text('Sentinelle des haies'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-streak')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ForkNavBar>(find.byType(ForkNavBar)).selected.index,
      3,
    );

    await tester.tap(tab('Accueil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sentinelle des haies'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ForkNavBar>(find.byType(ForkNavBar)).selected.index,
      3,
    );
    expect(find.text('Série : 9 jours'), findsOneWidget);
  });

  int selected(WidgetTester tester) =>
      tester.widget<ForkNavBar>(find.byType(ForkNavBar)).selected.index;

  Future<void> swipe(WidgetTester tester, double dx, {Finder? from}) async {
    await tester.fling(from ?? find.byType(PageView), Offset(dx, 0), 1000);
    await tester.pumpAndSettle();
  }

  // The map keeps animating (tiles, location): no pumpAndSettle there.
  Future<void> settleOnMap(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('swiping left from Accueil opens Carnet, the bar follows', (
    tester,
  ) async {
    await pump(tester);
    await swipe(tester, -300);
    expect(selected(tester), 1);
    expect(find.text('Mon carnet'), findsOneWidget);

    await swipe(tester, 300);
    expect(selected(tester), 0);
    expect(find.byType(ForkHome), findsOneWidget);
  });

  testWidgets('swiping is off on the Carte tab, allowed into it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(tab('Profil'));
    await tester.pump(const Duration(seconds: 1));
    // Swiping right from Profil enters the map.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await settleOnMap(tester);
    expect(selected(tester), 2);
    expect(find.byType(ContactMapScreen), findsOneWidget);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    // On the map, a horizontal drag does not leave the tab.
    await tester.dragFrom(const Offset(200, 400), const Offset(300, 0));
    await settleOnMap(tester);
    await tester.dragFrom(const Offset(200, 400), const Offset(-300, 0));
    await settleOnMap(tester);
    expect(selected(tester), 2);
    expect(find.byType(ContactMapScreen), findsOneWidget);

    // The bar still leaves it.
    await tester.tap(tab('Carnet'));
    await settleOnMap(tester);
    expect(selected(tester), 1);
    expect(find.text('Mon carnet'), findsOneWidget);
  });

  testWidgets('tapping the bar with reduced motion changes tab at once', (
    tester,
  ) async {
    await pump(tester, reducedMotion: true);
    await tester.tap(tab('Profil'));
    await tester.pump();
    expect(selected(tester), 3);
    expect(find.byType(ProfileScreen), findsOneWidget);
    // The notebook and the map, crossed on the way, are not built.
    expect(find.byType(ContactMapScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('a tap that skips tabs jumps, never flashing those between', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(tab('Profil'));
    // First frame after the tap: already on the Profil, nothing slid.
    await tester.pump();
    expect(selected(tester), 3);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ContactMapScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('each tab keeps its state across swipes', (tester) async {
    await pump(tester, heard: _heard);
    await swipe(tester, -300);
    expect(find.text('Mon carnet'), findsOneWidget);
    final state = tester.state(find.byType(NotebookScreen));

    // From the title: the middle of the notebook may be its chips row.
    await swipe(tester, 300, from: find.text('Mon carnet'));
    expect(selected(tester), 0);
    // Kept alive off screen, not rebuilt.
    expect(find.byType(NotebookScreen, skipOffstage: false), findsOneWidget);
    await swipe(tester, -300);
    expect(tester.state(find.byType(NotebookScreen)), same(state));
  });

  testWidgets('home is hidden for Visibility.of once off screen', (
    tester,
  ) async {
    await pump(tester);
    final home = find.byType(ForkHome, skipOffstage: false);
    expect(Visibility.of(tester.element(home)), isTrue);
    await swipe(tester, -300);
    expect(Visibility.of(tester.element(home)), isFalse);
    await tester.tap(tab('Accueil'));
    await tester.pumpAndSettle();
    expect(Visibility.of(tester.element(home)), isTrue);
  });

  testWidgets('the notebook filter chips scroll without changing tab', (
    tester,
  ) async {
    await pump(tester, heard: _heard);
    await tester.tap(tab('Carnet'));
    await tester.pumpAndSettle();
    final chips = find.descendant(
      of: find.byKey(const ValueKey('notebook-filter-chips')),
      matching: find.byType(Scrollable),
    );
    expect(chips, findsOneWidget);
    final position = tester.state<ScrollableState>(chips).position;
    expect(position.maxScrollExtent, greaterThan(0));

    await tester.drag(chips, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(selected(tester), 1);
  });

  testWidgets('back from Profil returns to Accueil', (tester) async {
    await pump(tester);
    await tester.tap(tab('Profil'));
    await tester.pumpAndSettle();
    expect(selected(tester), 3);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(selected(tester), 0);
    expect(find.byType(ForkHome), findsOneWidget);
  });

  // FORK: J6j, the « Écouter » disc in the middle of the bar.
  group('« Écouter » disc', () {
    final disc = find.descendant(
      of: find.byType(ForkNavBar),
      matching: find.text('Écouter'),
    );

    /// The screen built by the last route pushed on [observer].
    Widget lastPushed(BuildContext context, _Pushes observer) =>
        (observer.pushed.last as MaterialPageRoute<void>).builder(context);

    const tabLabels = {
      ForkTab.home: 'Accueil',
      ForkTab.notebook: 'Carnet',
      ForkTab.map: 'Carte',
      ForkTab.profile: 'Profil',
    };

    for (final start in ForkTab.values) {
      testWidgets('from ${start.name}: listens, the tab stays', (tester) async {
        final observer = _Pushes();
        await pump(tester, observer: observer);
        if (start != ForkTab.home) {
          await tester.tap(tab(tabLabels[start]!));
          // The map keeps its tiles loading: no settling.
          await tester.pump(const Duration(seconds: 1));
        }
        final count = observer.pushed.length;
        await tester.tap(disc);
        expect(observer.pushed.length, count + 1);
        final screen = lastPushed(
          tester.element(find.byType(ForkShell)),
          observer,
        );
        expect(screen, isA<LiveScreen>());
        expect((screen as LiveScreen).forceAutoStart, isTrue);
        expect(selected(tester), start.index);
      });
    }

    for (final state in [LiveState.active, LiveState.paused]) {
      testWidgets('while ${state.name}: reopens the screen, no autostart', (
        tester,
      ) async {
        final observer = _Pushes();
        await pump(tester, liveState: state, observer: observer, settle: false);
        final count = observer.pushed.length;
        await tester.tap(disc);
        expect(observer.pushed.length, count + 1);
        final screen = lastPushed(
          tester.element(find.byType(ForkShell)),
          observer,
        );
        expect(screen, isA<LiveScreen>());
        expect((screen as LiveScreen).forceAutoStart, isFalse);
      });
    }

    Finder discBox() => find.descendant(
      of: find.byType(ForkNavBar),
      matching: find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.width == BirdySizes.listenDisc &&
            w.height == BirdySizes.listenDisc,
      ),
    );

    testWidgets('overhangs the bar and takes the touch up there', (
      tester,
    ) async {
      final observer = _Pushes();
      await pump(tester, observer: observer);
      final bar = tester.getRect(find.byType(ForkNavBar));
      final rect = tester.getRect(discBox());
      // The disc's outer top is the bar box's top, 22 dp above the surface.
      expect(rect.top, bar.top);
      expect(
        bar.bottom - BirdySizes.navBar - bar.top,
        BirdySizes.listenDiscLift,
      );
      // A tap in the overhanging part opens the listening.
      final count = observer.pushed.length;
      await tester.tapAt(Offset(rect.center.dx, bar.top + 12));
      expect(observer.pushed.length, count + 1);
    });

    testWidgets('tap targets are at least 48 dp', (tester) async {
      await pump(tester);
      final bar = find.byType(ForkNavBar);
      for (final label in ['Accueil', 'Carnet', 'Carte', 'Profil']) {
        final inkWell = find.ancestor(
          of: find.descendant(of: bar, matching: find.text(label)),
          matching: find.byType(InkWell),
        );
        final size = tester.getSize(inkWell.first);
        expect(
          size.width,
          greaterThanOrEqualTo(BirdySizes.target),
          reason: label,
        );
        expect(
          size.height,
          greaterThanOrEqualTo(BirdySizes.target),
          reason: label,
        );
      }
      expect(
        tester.getSize(discBox()).shortestSide,
        greaterThanOrEqualTo(BirdySizes.target),
      );
    });

    testWidgets('semantics order: Accueil, Carnet, Écouter, Carte, Profil', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      final labels = <String>[];
      void visit(SemanticsNode node) {
        final label = node.label;
        if (const {
          'Accueil',
          'Carnet',
          'Écouter',
          'Carte',
          'Profil',
        }.contains(label)) {
          labels.add(label);
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(
        tester.getSemantics(
          find.bySemanticsLabel(AppLocalizationsFr().forkNavLabel),
        ),
      );
      expect(labels, ['Accueil', 'Carnet', 'Écouter', 'Carte', 'Profil']);
      handle.dispose();
    });
  });

  testWidgets('the Profil tab has the menu button (Palmarès is in the sheet)', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(tab('Profil'));
    await tester.pumpAndSettle();
    final menu = find.descendant(
      of: find.byType(ProfileScreen),
      matching: find.byTooltip('Menu'),
    );
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsFr().forkMoreTitle), findsOneWidget);
  });
}

const _heard = [
  HeardSpecies(
    scientificName: 'Erithacus rubecula',
    commonName: 'Rougegorge familier',
    contacts: 3,
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

/// Records every route pushed on the navigator.
class _Pushes extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}
