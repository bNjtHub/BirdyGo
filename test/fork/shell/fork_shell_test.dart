import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/home/fork_home.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/home/home_model.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/fork/notebook/notebook_loader.dart';
import 'package:birdnet_live/fork/notebook/notebook_model.dart';
import 'package:birdnet_live/fork/notebook/notebook_screen.dart';
import 'package:birdnet_live/fork/shell/fork_shell.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHome implements HomeLoader {
  @override
  Future<HomeSnapshot> load() async =>
      const HomeSnapshot(today: DaySummary.empty, last: null, toVerify: 0);

  @override
  Future<String?> placeName() async => null;
}

class _FakeNotebook implements NotebookLoader {
  @override
  Future<List<HeardSpecies>> heard() async => const [];

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
  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeLoaderProvider.overrideWithValue(_FakeHome()),
          notebookLoaderProvider.overrideWithValue(_FakeNotebook()),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith(
            (ref) => _PendingIndex(prefs),
          ),
        ],
        child: MaterialApp(
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ForkShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tab(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

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
    expect(find.text('Ton profil arrive'), findsOneWidget);
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
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
