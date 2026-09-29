import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_card.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_providers.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal_screen.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_headers.dart';
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
    Widget? home,
    bool progressError = false,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool dark = false,
    Completer<Set<String>>? slowProgress,
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
          dailyGoalProgressProvider.overrideWith((ref) async {
            if (slowProgress != null) return slowProgress.future;
            // Follow replacements just as the real progress provider does.
            final goal = ref.watch(dailyGoalProvider).goal;
            if (progressError) throw StateError('Index unavailable');
            return {
              if (goal?.species.any((s) => s.scientificName == 'Species 0') ??
                  false)
                'Species 0',
            };
          }),
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
          home: home ?? const DailyGoalScreen(),
        ),
      ),
    );
    // While progress is still pending its skeleton may shimmer forever
    // (J6g-g), so pumpAndSettle would never return: pump past the entrance.
    if (slowProgress != null) {
      await tester.pump(const Duration(seconds: 1));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('home card is passive until opened', (tester) async {
    var opened = false;
    await pump(
      tester,
      home: Scaffold(body: DailyGoalCard(onTap: () => opened = true)),
    );
    expect(locationRequests, 0);
    expect(find.text('Objectif du jour'), findsOneWidget);
    await tester.tap(find.text('Objectif du jour'));
    expect(opened, isTrue);
    expect(locationRequests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('restores goal offline, shows progress and saves replacement', (
    tester,
  ) async {
    await saveGoal();
    await pump(tester);
    expect(locationRequests, 0);
    expect(find.text('1/8 espèces entendues'), findsOneWidget);
    expect(find.text('Entendu'), findsOneWidget);
    await tester.tap(find.byTooltip('Remplacer Bird 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bird 8'));
    await tester.pumpAndSettle();
    expect(
      DailyGoalStore(prefs).readToday(day)!.species.first.scientificName,
      'Species 8',
    );
    expect(find.text('0/8 espèces entendues'), findsOneWidget);
    expect(find.text('Bird 8'), findsOneWidget);
    expect(locationRequests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing location offers settings and retry', (tester) async {
    await pump(tester);
    expect(locationRequests, 1);
    expect(find.text('Réessayer'), findsOneWidget);
    final l10n =
        AppLocalizations.of(tester.element(find.byType(DailyGoalScreen)))!;
    expect(find.text(l10n.settings), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'index error offers retry without reporting false zero progress',
    (tester) async {
      await saveGoal();
      await pump(tester, progressError: true);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('0/8 espèces entendues'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('landscape and large text remain scrollable without overflow', (
    tester,
  ) async {
    await saveGoal();
    await pump(tester, size: const Size(844, 390), textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('uses the overlay header, not a Material app bar', (
    tester,
  ) async {
    await saveGoal();
    await pump(tester);
    expect(find.byType(BirdyOverlayHeader), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('progress load shows skeletons, not a spinner', (tester) async {
    await saveGoal();
    final slow = Completer<Set<String>>();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, slowProgress: slow);
    // pumpAndSettle in pump() ends with progress still pending.
    expect(
      find.byKey(const ValueKey('dailyGoalProgressSkeleton')),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    slow.complete({'Species 0'});
    await tester.pumpAndSettle();
    expect(find.text('1/8 espèces entendues'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('small phone, 130 %, dark: no overflow', (tester) async {
    await saveGoal();
    await pump(tester, size: const Size(320, 640), textScale: 1.3, dark: true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
