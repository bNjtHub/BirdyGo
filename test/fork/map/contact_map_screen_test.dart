import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
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

  Future<void> pumpMap(WidgetTester tester, {required bool withData}) async {
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
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ContactMapScreen(),
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
    expect(find.text('Toutes les espèces'), findsOneWidget);
    expect(find.text('30 jours'), findsOneWidget);
    expect(find.text('Confirmées'), findsOneWidget);
    expect(find.textContaining('Aucun oiseau sur la carte'), findsOneWidget);
    // No tiles before the user allows them.
    expect(find.textContaining('fond de carte est désactivé'), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
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
