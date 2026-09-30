import 'dart:async';

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
import 'package:birdnet_live/fork/home/logo_tweet.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared harness of the Accueil theme tests (goldens and smoke): fixed clock,
/// fake loaders, one pump helper.
final DateTime _fixedNow = DateTime(2026, 9, 29, 9, 30);

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
  final now = _fixedNow;
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

/// Pumps the Accueil in [bird] and [dark]/light, then settles it.
Future<void> pumpHome(WidgetTester tester, BirdyBird bird, bool dark) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(390, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        homeClockProvider.overrideWithValue(() => _fixedNow),
        logoTweetPlayerProvider.overrideWithValue(_SilentTweet()),
        homeLoaderProvider.overrideWithValue(_Loader()),
        gameProgressProvider.overrideWith((ref) async => _game()),
        taxonomyServiceProvider.overrideWith((ref) async => TaxonomyService()),
        observationIndexServiceProvider.overrideWith(
          (ref) => _PendingIndex(prefs),
        ),
        dailyGoalProgressProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme:
            dark ? BirdyTheme.dark(bird: bird) : BirdyTheme.light(bird: bird),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder:
            (context, app) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: app!,
            ),
        home: const ForkHome(),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// No audio plugin in tests: the tweet is prepared and played by a no-op.
class _SilentTweet implements LogoTweetPlayer {
  @override
  Future<void> prepare() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async {}
}
