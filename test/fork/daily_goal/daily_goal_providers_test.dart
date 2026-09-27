import 'dart:async';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/core/services/location_service.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_providers.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _birds = [
  DailyGoalSpecies(
    scientificName: 'Parus major',
    commonName: 'Great tit',
    geoScore: .9,
    unexpected: false,
  ),
  DailyGoalSpecies(
    scientificName: 'Erithacus rubecula',
    commonName: 'Robin',
    geoScore: .8,
    unexpected: false,
  ),
];

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late DateTime now;
  late AppLocation? location;
  late int locationReads;
  late int modelReads;
  late List<DailyGoalSpecies> birds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 9, 27, 10);
    location = const AppLocation(latitude: 47.21, longitude: -1.55);
    locationReads = 0;
    modelReads = 0;
    birds = _birds;
  });

  ProviderContainer container({
    DailyGoalCandidateLoader? loader,
    bool disposeAtTearDown = true,
  }) {
    final result = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dailyGoalNowProvider.overrideWithValue(() => now),
        currentLocationProvider.overrideWith((ref) async {
          locationReads++;
          return location;
        }),
        dailyGoalCandidateLoaderProvider.overrideWithValue(
          loader ??
              (position, day) async {
                modelReads++;
                expect(position, same(location));
                expect(day, dailyGoalDay(now));
                return birds;
              },
        ),
      ],
    );
    if (disposeAtTearDown) addTearDown(result.dispose);
    return result;
  }

  test('passive home watch never acquires a position or loads a model', () {
    final scope = container();
    expect(scope.read(dailyGoalProvider).status, DailyGoalStatus.idle);
    expect(locationReads, 0);
    expect(modelReads, 0);
  });

  test(
    'same-day goal survives movement, restart and unavailable models',
    () async {
      final first = container();
      await first.read(dailyGoalProvider.notifier).ensureToday();
      final seeded = first.read(dailyGoalProvider).goal!;
      expect(locationReads, 1);
      expect(modelReads, 1);
      location = const AppLocation(latitude: 48.8, longitude: 2.3);
      await first.read(dailyGoalProvider.notifier).ensureToday();
      expect(first.read(dailyGoalProvider).goal, same(seeded));
      final restarted = container(
        loader: (_, _) => throw StateError('Offline'),
      );
      await restarted.read(dailyGoalProvider.notifier).ensureToday();
      expect(restarted.read(dailyGoalProvider).goal!.toJson(), seeded.toJson());
      expect(locationReads, 1);
      expect(modelReads, 1);
    },
  );

  test(
    'unavailable location is actionable and does not attempt a model',
    () async {
      location = null;
      final scope = container();
      await scope.read(dailyGoalProvider.notifier).ensureToday();
      expect(
        scope.read(dailyGoalProvider).status,
        DailyGoalStatus.needsLocation,
      );
      expect(scope.read(dailyGoalProvider).goal, isNull);
      expect(modelReads, 0);
      expect(prefs.containsKey(PrefKeys.dailyBirdGoal), isFalse);
      location = const AppLocation(latitude: 47.21, longitude: -1.55);
      await scope.read(dailyGoalProvider.notifier).ensureToday();
      expect(scope.read(dailyGoalProvider).status, DailyGoalStatus.ready);
    },
  );

  test(
    'empty predictions and failed models remain distinct retry states',
    () async {
      birds = [];
      final empty = container();
      await empty.read(dailyGoalProvider.notifier).ensureToday();
      expect(
        empty.read(dailyGoalProvider).status,
        DailyGoalStatus.noCandidates,
      );
      final failed = container(loader: (_, _) => throw StateError('No model'));
      await failed.read(dailyGoalProvider.notifier).ensureToday();
      expect(failed.read(dailyGoalProvider).status, DailyGoalStatus.error);
    },
  );

  test(
    'resume rolls local day and next explicit generation fetches a fresh place',
    () async {
      final scope = container();
      await scope.read(dailyGoalProvider.notifier).ensureToday();
      now = DateTime(2026, 9, 28, 8);
      location = const AppLocation(latitude: 48.8, longitude: 2.3);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(scope.read(dailyGoalProvider).status, DailyGoalStatus.idle);
      expect(locationReads, 1);
      await scope.read(dailyGoalProvider.notifier).ensureToday();
      expect(scope.read(dailyGoalProvider).goal!.day, DateTime(2026, 9, 28));
      expect(scope.read(dailyGoalProvider).goal!.latitude, 48.8);
      expect(locationReads, 2);
    },
  );

  test(
    'creation finishing after midnight does not install a stale goal',
    () async {
      final completion = Completer<List<DailyGoalSpecies>>();
      final scope = container(loader: (_, _) => completion.future);
      final pending = scope.read(dailyGoalProvider.notifier).ensureToday();
      await Future<void>.delayed(Duration.zero);
      now = DateTime(2026, 9, 28);
      completion.complete(_birds);
      await pending;
      expect(scope.read(dailyGoalProvider).status, DailyGoalStatus.idle);
      expect(prefs.containsKey(PrefKeys.dailyBirdGoal), isFalse);
    },
  );

  testWidgets('foreground timer expires the local day at midnight', (
    tester,
  ) async {
    now = DateTime(2026, 9, 27, 23, 59, 59);
    await DailyGoalStore(prefs).save(
      DailyGoal.create(
        day: now,
        latitude: 47.21,
        longitude: -1.55,
        candidates: _birds,
      ),
    );
    final scope = container(disposeAtTearDown: false);
    expect(scope.read(dailyGoalProvider).status, DailyGoalStatus.ready);
    now = DateTime(2026, 9, 28);
    await tester.pump(const Duration(seconds: 1));
    expect(scope.read(dailyGoalProvider).status, DailyGoalStatus.idle);
    scope.dispose();
  });
}
