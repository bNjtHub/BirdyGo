import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_block.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_providers.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_block.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final day = DateTime(2026, 9, 27, 9);
  final birds = List.generate(
    10,
    (i) => DailyGoalSpecies(
      scientificName: 'Species $i',
      commonName: 'Bird $i',
      geoScore: .8 - i * .01,
      unexpected: false,
    ),
  );
  late SharedPreferences prefs;
  late int locationRequests;
  late int taps;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    locationRequests = 0;
    taps = 0;
  });

  Future<void> saveGoal() => DailyGoalStore(prefs).save(
    DailyGoal.create(
      day: day,
      latitude: 48.8,
      longitude: 2.3,
      candidates: birds,
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    Set<String> heard = const {},
    bool dark = false,
    double textScale = 1,
    double width = 170,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dailyGoalNowProvider.overrideWithValue(() => day),
          currentLocationProvider.overrideWith((ref) async {
            locationRequests++;
            return null;
          }),
          dailyGoalProgressProvider.overrideWith((ref) async => heard),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
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
          home: Scaffold(
            body: ListView(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: DailyGoalBlock(onTap: () => taps++),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no goal: an invitation, no location request', (tester) async {
    await pump(tester);
    expect(locationRequests, 0);
    expect(find.text('Objectif du jour'), findsOneWidget);
    expect(
      find.text("Huit oiseaux à trouver près d'ici aujourd'hui."),
      findsOne,
    );
    expect(find.text('Choisir les oiseaux du jour'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-goal-ring')), findsNothing);
    await tester.tap(find.byType(DailyGoalBlock));
    expect(taps, 1);
  });

  testWidgets('ring, species left and three dashed slots at most', (
    tester,
  ) async {
    await saveGoal();
    await pump(tester, heard: {for (var i = 0; i < 5; i++) 'Species $i'});
    expect(locationRequests, 0);
    expect(find.text('5/8'), findsOneWidget);
    expect(find.bySemanticsLabel('5/8 espèces entendues'), findsOneWidget);
    expect(find.text('Encore 3 espèces'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-goal-slot')), findsNWidgets(3));
    expect(
      find.bySemanticsLabel('Bird 5 : pas encore entendu'),
      findsOneWidget,
    );
    final block = tester.widget<BirdyBlock>(find.byType(BirdyBlock));
    expect(block.tone, BirdyBlockTone.tonal);
  });

  testWidgets('few birds heard: still three slots', (tester) async {
    await saveGoal();
    await pump(tester, heard: const {'Species 0'});
    expect(find.text('Encore 7 espèces'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-goal-slot')), findsNWidgets(3));
  });

  testWidgets('every bird heard: goal reached, no slot', (tester) async {
    await saveGoal();
    await pump(tester, heard: {for (var i = 0; i < 8; i++) 'Species $i'});
    expect(find.text('Objectif atteint'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-goal-slot')), findsNothing);
  });

  for (final (name, dark, scale, width) in [
    ('dark', true, 1.0, 170.0),
    ('narrow at 130 %', false, 1.3, 130.0),
    ('dark, narrow at 130 %', true, 1.3, 130.0),
  ]) {
    testWidgets('no overflow: $name', (tester) async {
      await saveGoal();
      await pump(
        tester,
        heard: const {'Species 0'},
        dark: dark,
        textScale: scale,
        width: width,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('daily-goal-ring'))).width,
        BirdySizes.ring,
      );
    });
  }
}
