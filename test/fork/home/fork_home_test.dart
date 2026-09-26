import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_screen.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/home/fork_home.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/home/home_model.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loader with a fixed snapshot and place.
class _FakeLoader implements HomeLoader {
  _FakeLoader(this.snapshot, {this.place});

  final HomeSnapshot snapshot;
  final String? place;

  @override
  Future<HomeSnapshot> load() async => snapshot;

  @override
  Future<String?> placeName() async => place;
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

HomeSnapshot _morning({int toVerify = 12, bool withToday = true}) =>
    HomeSnapshot(
      today:
          withToday
              ? const DaySummary(species: 13, contacts: 52, newSpecies: 1)
              : DaySummary.empty,
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
          clipPath: null,
        ),
        level: ReliabilityLevel.sure,
        unexpected: false,
        total: 142,
      ),
      toVerify: toVerify,
    );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_Pushes> pump(
    WidgetTester tester, {
    HomeSnapshot? snapshot,
    String? place = 'Beaulieu-sur-Brenne',
    bool dark = false,
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final pushes = _Pushes();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeLoaderProvider.overrideWithValue(
            _FakeLoader(snapshot ?? _morning(), place: place),
          ),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
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
          home: const ForkHome(),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('the mockup morning (SPEC 9.1), without the game blocks', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('BirdyGo'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.textContaining('· Beaulieu-sur-Brenne'), findsOneWidget);
    for (final text in [
      '13',
      "espèces aujourd'hui",
      '52',
      'contacts',
      '1',
      'nouvelle',
      'Dernier oiseau entendu',
      'Rougegorge familier',
      'Sûr',
      '12 détections à vérifier',
      'Réécoute-les quand tu as un moment.',
      'Écouter',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.textContaining('142 au total'), findsOneWidget);
    // J6e.
    expect(find.textContaining('Sentinelle'), findsNothing);
    expect(find.textContaining('Défi'), findsNothing);
    expect(find.textContaining('jours'), findsNothing);
  });

  testWidgets('« Écouter » opens the live screen', (tester) async {
    final pushes = await pump(tester);
    await tester.tap(find.text('Écouter'));
    expect(await pushedScreen(tester, pushes), isA<LiveScreen>());
  });

  testWidgets('the to-check card opens the quick review', (tester) async {
    final pushes = await pump(tester);
    await tester.tap(find.text('12 détections à vérifier'));
    final screen = await pushedScreen(tester, pushes);
    expect(screen, isA<QuickReviewScreen>());
    expect((screen as QuickReviewScreen).onlyKeys, isNull);
  });

  testWidgets('nothing to check: no card', (tester) async {
    await pump(tester, snapshot: _morning(toVerify: 0));
    expect(find.textContaining('à vérifier'), findsNothing);
  });

  testWidgets('no bird today: an invitation, the last bird stays', (
    tester,
  ) async {
    await pump(tester, snapshot: _morning(withToday: false), place: null);
    expect(find.textContaining('Aucun oiseau pour l'), findsOneWidget);
    expect(find.text("espèces aujourd'hui"), findsNothing);
    expect(find.text('Rougegorge familier'), findsOneWidget);
    expect(find.textContaining('Beaulieu'), findsNothing);
  });

  testWidgets('first launch: nothing yet, « Écouter » still there', (
    tester,
  ) async {
    await pump(tester, snapshot: const HomeSnapshot());
    expect(find.textContaining('Aucun oiseau'), findsOneWidget);
    expect(find.text('Dernier oiseau entendu'), findsNothing);
    expect(find.text('Écouter'), findsOneWidget);
  });

  testWidgets('the menu keeps every upstream entry', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('fr'));
    for (final label in [
      l10n.sessionLibraryTitle,
      l10n.forkRanking,
      l10n.forkMap,
      l10n.forkQuickReview,
      l10n.forkSoundLibrary,
      l10n.forkGardenTitle,
      l10n.exploreMode,
      l10n.pointCountMode,
      l10n.surveyMode,
      l10n.aruMode,
      l10n.fileAnalysisMode,
      l10n.settings,
      l10n.helpTitle,
      l10n.about,
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
    ('landscape at 130 %', false, 1.3, const Size(844, 390)),
    ('tablet', true, 1.0, const Size(1024, 1366)),
  ]) {
    testWidgets('lays out without overflow: $name', (tester) async {
      await pump(tester, dark: dark, textScale: textScale, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Écouter'), findsOneWidget);
      // « Écouter » stays on screen, within reach of the thumb.
      expect(
        tester.getBottomLeft(find.text('Écouter')).dy,
        lessThan(size.height),
      );
    });
  }
}
