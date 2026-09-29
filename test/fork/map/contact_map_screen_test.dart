import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/clip_play_button.dart';
import 'package:birdnet_live/fork/map/contact_map_data.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/fork/map/contact_map_sheets.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A session heard two hours ago, inside the default 30-day period.
LiveSession _recentSession() {
  final start = DateTime.now().toUtc().subtract(const Duration(hours: 2));
  return LiveSession.fromJson({
    'id': 'recent',
    'startTime': start.toIso8601String(),
    'endTime': start.add(const Duration(minutes: 30)).toIso8601String(),
    'detections': [
      for (var i = 0; i < 3; i++)
        {
          'scientificName': 'Erithacus rubecula',
          'commonName': 'Rougegorge familier',
          'confidence': 0.9,
          'timestamp': start.add(Duration(minutes: i * 5)).toIso8601String(),
          'detLat': 47.2101 + i * 1e-5,
          'detLon': -1.5502,
        },
    ],
  });
}

void main() {
  sqfliteFfiInit();

  Future<void> pumpMap(
    WidgetTester tester, {
    required bool withData,
    bool dark = false,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      kObservationIndexFilledVersion: ObservationIndex.schemaVersion,
    });
    final prefs = await SharedPreferences.getInstance();
    final index =
        (await tester.runAsync(() async {
          final index = await ObservationIndex.open(
            databaseFactoryFfi,
            inMemoryDatabasePath,
          );
          if (withData) await index.upsertSession(_recentSession());
          return index;
        }))!;
    addTearDown(() => tester.runAsync(index.close));
    final service = ObservationIndexService(
      repository: SessionRepository(),
      prefs: prefs,
      openIndex: () async => index,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          observationIndexServiceProvider.overrideWith((ref) => service),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: const ContactMapScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('empty index: filters and an invitation to listen', (
    tester,
  ) async {
    await pumpMap(tester, withData: false);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Ma carte'), findsOneWidget);
    expect(find.textContaining('Tes contacts sur'), findsOneWidget);
    expect(find.text('Toutes les espèces'), findsOneWidget);
    expect(find.text('30 jours'), findsOneWidget);
    expect(find.text('Confirmées'), findsOneWidget);
    expect(find.textContaining('Aucun oiseau sur la carte'), findsOneWidget);
    // No tiles before the user allows them.
    expect(find.textContaining('fond de carte est désactivé'), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    // Default constructor: showBack is true, so the top card has a back
    // button (species page usage; the bottom navigation passes false).
    expect(find.byIcon(AppIcons.arrowBackRounded), findsOneWidget);
  });

  testWidgets('the top card shows the number of places (J6f)', (tester) async {
    await pumpMap(tester, withData: true);
    // A single session, so its contacts sit at one place.
    expect(find.textContaining('1 lieu'), findsOneWidget);
  });

  testWidgets('contacts show; the confirmed filter narrows them', (
    tester,
  ) async {
    await pumpMap(tester, withData: true);
    expect(find.textContaining('Aucun oiseau sur la carte'), findsNothing);
    expect(find.textContaining('Aucun contact avec ces filtres'), findsNothing);

    await tester.tap(find.text('Confirmées'));
    await settle(tester);
    expect(
      find.textContaining('Aucun contact avec ces filtres'),
      findsOneWidget,
    );
  });

  testWidgets('the confirmed chip shows a check when on (J6c)', (tester) async {
    await pumpMap(tester, withData: false);
    expect(find.byIcon(AppIcons.check), findsNothing);
    await tester.tap(find.text('Confirmées'));
    await settle(tester);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
  });

  testWidgets('dark theme at 130 %: the overlays lay out', (tester) async {
    await pumpMap(tester, withData: true, dark: true, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Toutes les espèces'), findsOneWidget);
  });

  testWidgets('landscape: the header and map still lay out (J6f-b)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpMap(tester, withData: true);
    expect(tester.takeException(), isNull);
    expect(find.text('Ma carte'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('area sheet: title, contacts, replay and privacy line', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final clip = IndexedDetection(
      key: 'k',
      sessionId: 's',
      position: 0,
      scientificName: 'Erithacus rubecula',
      commonName: 'Rougegorge familier',
      start: DateTime(2026, 9, 26, 7),
      end: null,
      confidence: 0.9,
      reviewStatus: ReviewStatus.unreviewed,
      latitude: null,
      longitude: null,
      clipPath: '/clips/k.wav',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showAreaSheet(
                          context,
                          species: [
                            SpeciesInArea(
                              scientificName: 'Erithacus rubecula',
                              commonName: 'Rougegorge familier',
                              contacts: 44,
                              bestClip: clip,
                            ),
                            const SpeciesInArea(
                              scientificName: 'Turdus merula',
                              commonName: 'Merle noir',
                              contacts: 35,
                              bestClip: null,
                            ),
                          ],
                          filterSummary: '30 jours',
                        ),
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('2 espèces · 79 contacts'), findsOneWidget);
    // Count as a big number with its unit under it (J6g-f).
    expect(find.text('44'), findsOneWidget);
    expect(find.text('contacts'), findsNWidgets(2));
    expect(find.text('Merle noir'), findsOneWidget);
    // Only the robin has a clip to replay.
    expect(find.byType(ClipPlayButton), findsOneWidget);
    expect(
      find.text('Tes positions précises restent sur ton téléphone.'),
      findsOneWidget,
    );
  });
}

/// Lets the in-memory database answer, then draws the result.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
