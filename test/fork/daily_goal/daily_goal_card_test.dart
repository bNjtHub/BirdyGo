import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_card.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_providers.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
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
  const heard = {
    'Species 0',
    'Species 1',
    'Species 2',
    'Species 3',
    'Species 4',
  };
  late SharedPreferences prefs;
  late int locationRequests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    locationRequests = 0;
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
    bool dark = false,
    double textScale = 1,
    Size size = const Size(390, 844),
    Locale locale = const Locale('fr'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
          locale: locale,
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
              padding: const EdgeInsets.all(BirdySpace.gutter),
              children: [DailyGoalCard(onTap: () {})],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('heard birds on their tint with a check, the others dashed', (
    tester,
  ) async {
    await saveGoal();
    await pump(tester);
    expect(locationRequests, 0);
    expect(find.text('5/8 espèces entendues'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-goal-heard')), findsNWidgets(5));
    expect(find.byKey(const ValueKey('daily-goal-to-find')), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('two rows of four big circles', (tester) async {
    await saveGoal();
    await pump(tester);
    for (final row in ['daily-goal-row-0', 'daily-goal-row-1']) {
      final circles = find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.bySemanticsLabel(RegExp('^Bird ')),
      );
      expect(circles, findsNWidgets(4), reason: row);
    }
    final first = tester.getRect(
      find.byKey(const ValueKey('daily-goal-heard')).first,
    );
    expect(first.width, DailyGoalCardSizes.bird);
    // Same row: same top; next row below.
    final rows = [
      for (final i in [0, 3, 4])
        tester.getTopLeft(find.bySemanticsLabel(RegExp('^Bird $i '))).dy,
    ];
    expect(rows[0], rows[1]);
    expect(rows[2], greaterThan(rows[0]));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each circle announces the bird and whether it was heard', (
    tester,
  ) async {
    await saveGoal();
    await pump(tester);
    expect(find.bySemanticsLabel('Bird 0 : entendu'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Bird 7 : pas encore entendu'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());

    await pump(tester, locale: const Locale('en'));
    expect(find.text('5 of 8 species heard'), findsOneWidget);
    expect(find.bySemanticsLabel('Bird 0: heard'), findsOneWidget);
    expect(find.bySemanticsLabel('Bird 7: not heard yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no goal yet: the invitation, no circles, no GPS request', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Choisir les oiseaux du jour'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-goal-grid')), findsNothing);
    expect(locationRequests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (name, dark, width) in [
    ('light, small phone', false, 320.0),
    ('dark, small phone', true, 320.0),
    ('dark', true, 390.0),
  ]) {
    testWidgets('no overflow at 130 %: $name', (tester) async {
      await saveGoal();
      await pump(tester, dark: dark, textScale: 1.3, size: Size(width, 700));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('daily-goal-heard')), findsNWidgets(5));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
