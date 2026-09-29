import 'dart:async';
import 'dart:typed_data';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_providers.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fonts.dart';

/// Goldens of the Accueil in the four bird themes, light and dark (J6i).
///
/// The Accueil shows the date and a greeting that depend on the clock, so
/// the comparison tolerates a small share of different pixels (text only);
/// a theme change recolors far more than that. Regenerate with
/// `flutter test test/fork/goldens --update-goldens`.
const double _tolerance = 0.02;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

class _Loader implements HomeLoader {
  @override
  Future<HomeSnapshot> load() async => _snapshot();

  @override
  Future<String?> placeName() async => null;

  @override
  Future<DateTime?> sunrise() async => null;

  @override
  Future<DateTime?> sunset() async => null;
}

class _PendingIndex extends ObservationIndexService {
  _PendingIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

HomeSnapshot _snapshot() {
  final now = DateTime.now();
  return HomeSnapshot(
    today: const DaySummary(
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
    ),
    last: LastBird(
      detection: IndexedDetection(
        key: 'k',
        sessionId: 's',
        position: 0,
        scientificName: 'Erithacus rubecula',
        commonName: 'Rougegorge familier',
        // A fixed time of day, so the caption does not change per minute.
        start: DateTime(now.year, now.month, now.day, 7, 52),
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
    toVerify: 12,
  );
}

GameProgress _game() {
  final monday = DateTime(2026, 9, 14);
  return GameProgress(
    GameFacts(
      verifiedBirds: {for (var i = 0; i < 24; i++) 'Species $i'},
      dawnChoruses: 0,
      earlyStarts: 0,
      reviewed: 0,
      migrants: const {},
      streak: Streak(
        current: 9,
        record: 12,
        calendar: [
          for (var i = 0; i < 14; i++)
            StreakDay(
              date: DateTime(monday.year, monday.month, monday.day + i),
              state: i == 13 ? StreakDayState.open : StreakDayState.listened,
              isToday: i == 13,
            ),
        ],
      ),
    ),
  );
}

void main() {
  final previous = goldenFileComparator;
  setUpAll(() async {
    await loadAppFonts(icons: true);
    final dir = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${dir}home_themes_golden_test.dart'),
    );
  });
  tearDownAll(() => goldenFileComparator = previous);

  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('Accueil ${bird.name} $mode', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        tester.view.physicalSize = const Size(390, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              homeLoaderProvider.overrideWithValue(_Loader()),
              gameProgressProvider.overrideWith((ref) async => _game()),
              taxonomyServiceProvider.overrideWith(
                (ref) async => TaxonomyService(),
              ),
              observationIndexServiceProvider.overrideWith(
                (ref) => _PendingIndex(prefs),
              ),
              dailyGoalProgressProvider.overrideWith((ref) async => const {}),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme:
                  dark
                      ? BirdyTheme.dark(bird: bird)
                      : BirdyTheme.light(bird: bird),
              locale: const Locale('fr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder:
                  (context, app) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: app!,
                  ),
              home: const ForkHome(),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('home_${bird.name}_$mode.png'),
        );
      });
    }
  }
}
