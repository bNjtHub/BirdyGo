import 'dart:async';

import 'package:birdnet_live/app.dart';
import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/file_analysis/file_analysis_controller.dart';
import 'package:birdnet_live/features/file_analysis/file_analysis_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/home/home_screen.dart';
import 'package:birdnet_live/features/inference/geo_model.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/home/home_model.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash.dart';
import 'package:birdnet_live/fork/splash/birdygo_startup.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/quick_action_service.dart';
import 'package:birdnet_live/shared/services/shared_media_service.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingRepository extends SessionRepository {
  final scan = Completer<List<LiveSession>>();

  @override
  Future<List<LiveSession>> listAll() => scan.future;
}

class _IdleLive extends Fake implements LiveController {
  @override
  LiveState get state => LiveState.idle;

  @override
  Future<void> loadModel() async {} // No native model runs in this widget test.
}

class _IdleFileAnalysis extends Fake implements FileAnalysisController {
  @override
  FileAnalysisState get state => FileAnalysisState.idle;
}

class _EmptyHome extends Fake implements HomeLoader {
  @override
  Future<HomeSnapshot> load() async => const HomeSnapshot();

  @override
  Future<String?> placeName() async => null;
}

class _NoDiskIndex extends ChangeNotifier implements ObservationIndexService {
  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final share in [true, false]) {
    for (final introFinished in [false, true]) {
      testWidgets(
        '${share ? 'audio share' : 'Quick Listen'} holds routing, intro finished: $introFinished',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            PrefKeys.onboardingComplete: true,
            PrefKeys.termsAccepted: true,
          });
          final prefs = await SharedPreferences.getInstance();
          final repository = _PendingRepository();
          final pending = Completer<Widget>();
          final index = _NoDiskIndex();
          await tester.pumpWidget(
            BirdyGoStartup(bootstrap: () => pending.future),
          );
          await tester.pump(
            introFinished
                ? BirdyGoSplash.introDuration
                : const Duration(milliseconds: 20),
          );
          await tester.pump(
            introFinished ? const Duration(milliseconds: 16) : Duration.zero,
          );
          pending.complete(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                sessionRepositoryProvider.overrideWithValue(repository),
                liveControllerProvider.overrideWithValue(_IdleLive()),
                fileAnalysisControllerProvider.overrideWithValue(
                  _IdleFileAnalysis(),
                ),
                homeLoaderProvider.overrideWithValue(_EmptyHome()),
                observationIndexServiceProvider.overrideWith((ref) => index),
                taxonomyServiceProvider.overrideWith(
                  (ref) async => TaxonomyService(),
                ),
                audioLabelsSetProvider.overrideWith((ref) async => <String>{}),
                geoModelProvider.overrideWith((ref) async => GeoModel()),
                currentLocationProvider.overrideWith((ref) async => null),
                speciesSheetsProvider.overrideWith(
                  (ref) async => SpeciesSheets.empty,
                ),
              ],
              child: App(
                launchSharedFile:
                    share
                        ? const SharedAudioFile(
                          uri: 'content://test/bird.wav',
                          name: 'bird.wav',
                        )
                        : null,
                launchQuickAction:
                    share ? null : QuickActionService.startListeningAction,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(BirdyGoSplash), findsOneWidget);
          expect(find.byType(HomeScreen), findsNothing);
          expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

          // A failed storage read must reveal the fail-closed dialog, not leave
          // startup stuck behind it. This exercises both real App listeners.
          repository.scan.completeError(StateError('Storage unavailable'));
          await tester.pump();
          await tester.pump();
          await tester.pump();
          // No clock advance: explicit launches reveal their controls even when
          // the normal startup introduction still has time left.
          expect(find.byType(BirdyGoSplash), findsNothing);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        },
      );
    }
  }
}
