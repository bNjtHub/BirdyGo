import 'package:birdnet_live/features/announcements/geo_commonness_provider.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/history/session_review_screen.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/summary/listening_summary.dart';
import 'package:birdnet_live/fork/summary/listening_summary_loader.dart';
import 'package:birdnet_live/fork/summary/listening_summary_screen.dart';
import 'package:birdnet_live/fork/summary/listening_summary_view.dart';
import 'package:birdnet_live/fork/summary/open_listening_summary.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'summary_fixture.dart';

/// Keeps saved sessions in memory.
class _MemoryRepository extends SessionRepository {
  final saved = <LiveSession>[];
  final deleted = <String>[];
  final stored = <String, LiveSession>{};
  bool failSave = false;

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<LiveSession?> load(String id) async => stored[id];

  @override
  Future<void> save(LiveSession session) async {
    if (failSave) throw StateError('save failed');
    saved.add(session);
  }
}

void main() {
  // The index part of the loading is tested in listening_summary_test.dart
  // (sqflite runs on real async, which widget tests do not drive).
  Future<void> pump(
    WidgetTester tester,
    Future<ListeningSummary> Function(LiveSession session) loader, {
    SessionRepository? repository,
    LiveSession? session,
    bool saved = true,
    bool fromLive = true,
  }) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          listeningSummaryLoaderProvider.overrideWithValue(loader),
          if (repository != null)
            sessionRepositoryProvider.overrideWithValue(repository),
          geoCommonnessProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith((ref) async => null),
          rawGeoScoresProvider.overrideWith((ref) async => null),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    // As after « Arrêter »: library, then the summary.
                    onPressed:
                        () =>
                            Navigator.of(context)
                              ..push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => const Scaffold(
                                        body: Text('Bibliothèque'),
                                      ),
                                ),
                              )
                              ..push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => ListeningSummaryScreen(
                                        session: session ?? morningSession(),
                                        saved: saved,
                                        fromLive: fromLive,
                                      ),
                                ),
                              ),
                    child: const Text('Accueil'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
  }

  Future<void> submitObservation(WidgetTester tester) async {
    final context = tester.element(find.byType(ListeningSummaryView));
    final label = AppLocalizations.of(context)!.forkSummaryAddObservation;
    await tester.scrollUntilVisible(
      find.text(label),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    final overlay = tester.widget<AddSpeciesOverlay>(
      find.byType(AddSpeciesOverlay),
    );
    expect(overlay.initialMode, AddSpeciesInsertMode.global);
    expect(overlay.lockMode, isTrue);
    expect(overlay.initialEvidence, DetectionEvidence.seen);
    Navigator.of(tester.element(find.byType(AddSpeciesOverlay))).pop(
      AddSpeciesResult(
        scientificName: 'Upupa epops',
        commonName: 'Huppe fasciée',
        mode: AddSpeciesInsertMode.global,
        evidence: DetectionEvidence.seen,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty listening can save a visual observation directly', (
    tester,
  ) async {
    final session =
        morningSession()
          ..detections.clear()
          ..locationName = 'Test place';
    final repository = _MemoryRepository();
    await pump(
      tester,
      (session) async => ListeningSummary.of(session, verifiedBefore: {}),
      session: session,
      repository: repository,
    );
    await submitObservation(tester);
    final saved = repository.saved.single;
    final bird = saved.detections.single;
    expect(bird.source, DetectionSource.manualGlobal);
    expect(bird.evidence, DetectionEvidence.seen);
    expect(bird.isConfirmed, isTrue);
    expect(bird.reviewedAt, isNotNull);
    expect(bird.latitude, session.latitude);
    expect(bird.longitude, session.longitude);
    expect(bird.audioClipPath, isNull);
    expect(session.detections, isEmpty);
    final view = tester.widget<ListeningSummaryView>(
      find.byType(ListeningSummaryView),
    );
    expect(view.summary.otherObservedSpecies, hasLength(1));
    expect(view.summary.heardSpecies, isEmpty);
  });

  testWidgets('failed observation save leaves the session unchanged', (
    tester,
  ) async {
    final session = morningSession()..locationName = 'Test place';
    final repository = _MemoryRepository()..failSave = true;
    await pump(
      tester,
      (session) async => ListeningSummary.of(session, verifiedBefore: {}),
      session: session,
      repository: repository,
    );
    await submitObservation(tester);
    expect(repository.saved, isEmpty);
    expect(session.detections, hasLength(52));
    final view = tester.widget<ListeningSummaryView>(
      find.byType(ListeningSummaryView),
    );
    expect(view.summary.contacts, 52);
    expect(view.savingObservation, isFalse);
    final context = tester.element(find.byType(ListeningSummaryView));
    expect(
      find.text(AppLocalizations.of(context)!.forkSummaryObservationSaveFailed),
      findsOneWidget,
    );
  });

  for (final practice in [true, false]) {
    testWidgets('no observation action for ${practice ? 'practice' : 'file'}', (
      tester,
    ) async {
      final session = LiveSession.fromJson({
        ...morningSession().toJson(),
        'practice': practice,
        'type': practice ? 'live' : 'fileUpload',
        'locationName': 'Test place',
      });
      await pump(
        tester,
        (session) async => ListeningSummary.of(session, verifiedBefore: {}),
        session: session,
      );
      expect(
        tester
            .widget<ListeningSummaryView>(find.byType(ListeningSummaryView))
            .onAddObservation,
        isNull,
      );
    });
  }

  testWidgets('shows the loaded summary; the back button goes home', (
    tester,
  ) async {
    await pump(
      tester,
      (session) async => ListeningSummary.of(
        session,
        verifiedBefore: verifiedBeforeMorning,
        presence: morningPresence,
      ),
    );

    expect(find.text('Belle matinée !'), findsOneWidget);
    expect(find.text('Ta 24e espèce, à 07:26.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Envoyer à Faune-France (LPO)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Seuls les oiseaux que tu confirmes partent à la LPO.'),
      findsOneWidget,
    );

    // J6f: the header is now `BirdyOverlayHeader`, whose back button
    // carries the system back tooltip (« Retour »), not « Terminer ».
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Bibliothèque'), findsNothing);
  });

  testWidgets('opened from elsewhere, close pops one level only', (
    tester,
  ) async {
    await pump(
      tester,
      (session) async => ListeningSummary.of(session, verifiedBefore: {}),
      fromLive: false,
    );
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.byType(ListeningSummaryView), findsNothing);
  });

  group('unsaved listening (J6g-e)', () {
    Future<_MemoryRepository> pumpUnsaved(WidgetTester tester) async {
      final repository = _MemoryRepository();
      await pump(
        tester,
        // The index is never reached for an unsaved session.
        (session) async => throw StateError('index must not be used'),
        repository: repository,
        session: morningSession()..locationName = 'Test place',
        saved: false,
      );
      return repository;
    }

    testWidgets('shows what was heard with a « non enregistrée » note', (
      tester,
    ) async {
      final repository = await pumpUnsaved(tester);
      expect(find.text('Écoute non enregistrée'), findsOneWidget);
      expect(find.text('Belle matinée !'), findsOneWidget);
      expect(repository.saved, isEmpty);
      final view = tester.widget<ListeningSummaryView>(
        find.byType(ListeningSummaryView),
      );
      // Nothing that writes the session or reads the index before saving.
      expect(view.onCheck, isNull);
      expect(view.onAddObservation, isNull);
      expect(view.onMarkRecording, isNull);
      expect(view.onDetails, isNotNull);
      expect(find.text('Envoyer à Faune-France (LPO)'), findsNothing);
    });

    testWidgets('the save button keeps it and drops the note', (tester) async {
      final repository = await pumpUnsaved(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      await tester.pump();
      expect(repository.saved, hasLength(1));
    });

    testWidgets('leaving asks; discard deletes and goes back', (tester) async {
      final repository = await pumpUnsaved(tester);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(repository.deleted, [morningSession().id]);
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgets('leaving asks; save keeps it and goes back', (tester) async {
      final repository = await pumpUnsaved(tester);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Enregistrer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.saved, hasLength(1));
      expect(find.text('Accueil'), findsOneWidget);
    });
  });

  testWidgets('the stop flow always builds the Bilan, saved or not', (
    tester,
  ) async {
    final session = morningSession();
    for (final saved in [true, false]) {
      final route = afterStopSummaryRoute(session, saved: saved);
      expect(route, isA<MaterialPageRoute<void>>());
      late Widget page;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            page = (route as MaterialPageRoute<void>).builder(context);
            return const SizedBox.shrink();
          },
        ),
      );
      final screen = page as ListeningSummaryScreen;
      expect(screen.saved, saved);
      expect(screen.fromLive, isTrue);
      expect(screen.session, same(session));
    }
  });

  testWidgets('openListeningSummary opens a saved session, one level deep', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = morningSession()..locationName = 'Test place';
    final repository = _MemoryRepository()..stored[session.id] = session;
    late bool opened;
    late bool missing;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          listeningSummaryLoaderProvider.overrideWithValue(
            (s) async => ListeningSummary.of(s, verifiedBefore: {}),
          ),
          sessionRepositoryProvider.overrideWithValue(repository),
          geoCommonnessProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith((ref) async => null),
          rawGeoScoresProvider.overrideWith((ref) async => null),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder:
                (context, ref, _) => Scaffold(
                  body: Column(
                    children: [
                      TextButton(
                        onPressed: () async {
                          missing = await openListeningSummary(
                            context,
                            ref,
                            sessionId: 'nope',
                          );
                        },
                        child: const Text('Absent'),
                      ),
                      TextButton(
                        onPressed: () async {
                          opened = await openListeningSummary(
                            context,
                            ref,
                            sessionId: session.id,
                          );
                        },
                        child: const Text('Bilan du jour'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Absent'));
    await tester.pumpAndSettle();
    expect(missing, isFalse);
    expect(find.byType(ListeningSummaryView), findsNothing);

    await tester.tap(find.text('Bilan du jour'));
    await tester.pumpAndSettle();
    expect(find.byType(ListeningSummaryView), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.text('Bilan du jour'), findsOneWidget);
  });

  testWidgets('back also goes home', (tester) async {
    await pump(
      tester,
      (session) async => ListeningSummary.of(session, verifiedBefore: {}),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('without the index, the summary shows no novelty', (
    tester,
  ) async {
    await pump(tester, (session) async => throw StateError('no index'));

    expect(find.text('Belle matinée !'), findsOneWidget);
    expect(find.text('Première fois'), findsNothing);
    expect(find.text('Une nouvelle, peut-être deux'), findsNothing);
  });

  testWidgets('« C\'était un enregistrement ? » saves the session as one', (
    tester,
  ) async {
    final repository = _MemoryRepository();
    await pump(
      tester,
      (session) async => ListeningSummary.of(
        session,
        verifiedBefore: verifiedBeforeMorning,
        presence: morningPresence,
      ),
      repository: repository,
    );
    final page = find.byType(Scrollable).first;
    final link = find.text("C'était un enregistrement ?");
    await tester.scrollUntilVisible(link, 300, scrollable: page);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(repository.saved.last.practice, isTrue);
    expect(find.text('Première fois'), findsNothing);
    await tester.scrollUntilVisible(
      find.text("Non, c'étaient de vrais oiseaux"),
      300,
      scrollable: page,
    );
    expect(find.text('Envoyer à Faune-France (LPO)'), findsNothing);
  });
}
