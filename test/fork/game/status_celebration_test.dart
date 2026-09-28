import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/status_celebration.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameProgress _with(int species) => GameProgress(
  GameFacts(
    verifiedBirds: {for (var i = 0; i < species; i++) 'Species $i'},
    dawnChoruses: 0,
    earlyStarts: 0,
    reviewed: 0,
    migrants: const {},
    streak: Streak.empty,
  ),
);

void main() {
  late SharedPreferences prefs;
  late WidgetRef widgetRef;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Map<String, Object> stored = const {},
    bool reduced = false,
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: child!,
              ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      ),
    );
    return container;
  }

  Future<void> celebrate(WidgetTester tester, int species) async {
    await maybeCelebrateStatus(
      tester.element(find.text('home')),
      widgetRef,
      _with(species),
    );
  }

  testWidgets('the first time, the current status is recorded silently', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(() => celebrate(tester, 24));
    await tester.pumpAndSettle();
    expect(find.byType(NewStatusScreen), findsNothing);
    expect(prefs.getInt(kStatusCelebratedPref), 4);
  });

  testWidgets('a new status plays once', (tester) async {
    await pump(tester, stored: {kStatusCelebratedPref: 3});
    celebrate(tester, 20);
    await tester.pumpAndSettle();
    expect(find.text('Tu deviens Sentinelle des haies'), findsOneWidget);
    expect(
      find.text(
        '20 espèces découvertes. Tu reconnais maintenant les voix des haies et des jardins.',
      ),
      findsOneWidget,
    );
    expect(find.text('Oreille de chouette, à 35 espèces'), findsOneWidget);
    expect(prefs.getInt(kStatusCelebratedPref), 4);

    await tester.ensureVisible(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.byType(NewStatusScreen), findsNothing);
    celebrate(tester, 21);
    await tester.pumpAndSettle();
    expect(find.byType(NewStatusScreen), findsNothing);
  });

  testWidgets('one confetti burst from the emblem, once it is in', (
    tester,
  ) async {
    await pump(tester, stored: {kStatusCelebratedPref: 3});
    celebrate(tester, 20);
    await tester.pump();
    await tester.pump(BirdyMotion.enter);
    expect(
      tester
          .widget<ConfettiWidget>(find.byType(ConfettiWidget))
          .confettiController
          .state,
      ConfettiControllerState.stopped,
    );
    await tester.pump(BirdyMotion.newStatus);
    final particles = tester.widget<ConfettiWidget>(
      find.byType(ConfettiWidget),
    );
    expect(particles.confettiController.state, ConfettiControllerState.playing);
    expect(particles.shouldLoop, isFalse);
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiWidget), findsNothing);
    expect(find.text('Tu deviens Sentinelle des haies'), findsOneWidget);
  });

  testWidgets('reduced motion: no confetti', (tester) async {
    await pump(tester, stored: {kStatusCelebratedPref: 3}, reduced: true);
    celebrate(tester, 20);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ConfettiWidget), findsNothing);
    expect(find.text('Tu deviens Sentinelle des haies'), findsOneWidget);
  });

  testWidgets('never while listening', (tester) async {
    final container = await pump(tester, stored: {kStatusCelebratedPref: 3});
    container.read(liveStateProvider.notifier).state = LiveState.active;
    celebrate(tester, 20);
    await tester.pumpAndSettle();
    expect(find.byType(NewStatusScreen), findsNothing);
    expect(prefs.getInt(kStatusCelebratedPref), 3);
  });
}
