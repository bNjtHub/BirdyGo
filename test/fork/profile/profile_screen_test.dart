import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_screen.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/game/streak_dots.dart';
import 'package:birdnet_live/fork/profile/profile_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The mockup's player (SPEC.md 8.1): 24 species, a 9-day série.
GameProgress _player({int species = 24}) => GameProgress(
  GameFacts(
    verifiedBirds: {
      'Strix aluco',
      'Parus major',
      for (var i = 2; i < species; i++) 'Species $i',
    },
    dawnChoruses: 1,
    earlyStarts: 2,
    reviewed: 36,
    migrants: const {'Sylvia atricapilla'},
    streak: computeStreak({
      for (var d = 18; d <= 26; d++)
        if (d != 22) DateTime(2026, 9, d),
    }, DateTime(2026, 9, 26, 9)),
  ),
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    GameProgress? progress,
    bool dark = false,
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProgressProvider.overrideWith(
            (ref) async => progress ?? _player(),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, app) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: app!,
              ),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('level card, série and badges (J6f)', (tester) async {
    await pump(tester);
    expect(find.text('Sentinelle des haies'), findsWidgets);
    expect(find.text('Niveau 4 sur 8'), findsOneWidget);
    expect(find.text('24 espèces découvertes'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Progression vers le prochain niveau : 27 %')),
      findsOneWidget,
    );
    // Nothing picked: the info box defaults to the next level.
    expect(find.text('Prochain niveau'), findsOneWidget);
    expect(find.text('Oreille de chouette'), findsOneWidget);
    expect(find.text('Encore 11 espèces'), findsOneWidget);
    expect(find.text('Touche un emblème pour le découvrir.'), findsOneWidget);

    expect(find.text('Série : 9 jours'), findsOneWidget);
    expect(find.text('Record : 9 jours'), findsOneWidget);
    expect(find.byType(StreakDots), findsOneWidget);

    await tester.scrollUntilVisible(find.text('À gagner'), 300);
    expect(find.text('À gagner'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Les mésanges'), 200);
    for (final name in [
      "Chœur de l'aube",
      'Lève-tôt',
      'Noctambule',
      'Réviseur',
      'Migrateur',
      "7 jours d'affilée",
      'Les mésanges',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // Locked: the way to go.
    expect(find.text('1 sur 3'), findsOneWidget); // Migrateur.
  });

  testWidgets('earned badges come first in the grid', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Les mésanges'), 200);
    // The player's earned badges (Chœur de l'aube, Lève-tôt, Noctambule,
    // Réviseur, 7 jours d'affilée) show tier dots; the locked ones
    // (Migrateur, Les mésanges, Oreille fine) show a "value sur target"
    // caption instead. Earned tiles are placed first in the underlying
    // list, so a TierDots widget never follows a locked progress caption
    // in the grid's build (tree) order, even when a row mixes both kinds.
    final gridFinder = find.byKey(const ValueKey('profile-badges-grid'));
    final markers = find.descendant(
      of: gridFinder,
      matching: find.byWidgetPredicate(
        (w) =>
            w is TierDots ||
            (w is Text &&
                w.data != null &&
                RegExp(r'^\d+ sur \d+$').hasMatch(w.data!)),
      ),
    );
    final elements = markers.evaluate().toList();
    expect(elements, isNotEmpty);
    var sawLocked = false;
    for (final element in elements) {
      final isEarned = element.widget is TierDots;
      if (!isEarned) sawLocked = true;
      expect(
        !(isEarned && sawLocked),
        isTrue,
        reason: 'an earned badge (TierDots) appeared after a locked one',
      );
    }
    expect(sawLocked, isTrue, reason: 'no locked badge found to compare against');
  });

  testWidgets('the next-level segmented bar has one segment per species', (
    tester,
  ) async {
    await pump(tester);
    // Sentinelle des haies (20) -> Oreille de chouette (35): 15 segments.
    final bars = tester.widgetList<SegmentedBar>(find.byType(SegmentedBar));
    expect(bars, hasLength(1));
    expect(bars.first.count, 15);
  });

  testWidgets('tapping a level emblem shows it, tapping again returns to next', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Prochain niveau'), findsOneWidget);
    expect(find.text('Oreille de chouette'), findsOneWidget);

    // The current level (4, « Sentinelle des haies ») is reached: its
    // emblem announces "ton niveau".
    await tester.tap(
      find.bySemanticsLabel(RegExp('Niveau 4, Sentinelle des haies.*ton niveau')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ton niveau'), findsOneWidget);
    expect(find.text('Dès 20 espèces'), findsOneWidget);
    expect(
      find.text('Tu reconnais maintenant les voix des haies et des jardins.'),
      findsOneWidget,
    );
    expect(find.text('Prochain niveau'), findsNothing);

    // Tapping it again clears the pick and returns to the next level.
    await tester.tap(
      find.bySemanticsLabel(RegExp('Niveau 4, Sentinelle des haies.*ton niveau')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Prochain niveau'), findsOneWidget);
    expect(find.text('Ton niveau'), findsNothing);
  });

  testWidgets('the plumes counter totals every badge tier', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.scrollUntilVisible(find.text('À gagner'), 300);
    final progress = _player();
    final total = progress.badges.fold<int>(0, (sum, b) => sum + b.tier);
    expect(
      find.bySemanticsLabel(RegExp('$total plumes? gagnée')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the quiz entry opens the quiz', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Qui chante ?'), 300);
    await tester.ensureVisible(find.text('Qui chante ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qui chante ?'));
    // The quiz screen loads its clips from a real index/model pipeline not
    // mocked here; just pump a few frames rather than pumpAndSettle (which
    // would time out waiting on that pipeline) to confirm the navigation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The quiz screen opened on top with its own big « Qui chante ? »
    // heading (the Profil's own quiz-entry row, still mounted underneath,
    // keeps showing its smaller heading too, until the page transition ends
    // and the route below goes offstage: J7's 220 ms transition ends first).
    expect(find.text('Qui chante ?'), findsWidgets);
    expect(find.byType(FineEarQuizScreen), findsOneWidget);
  });

  testWidgets('a badge explains its rule', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Réviseur'), 200);
    await tester.ensureVisible(find.text('Réviseur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réviseur'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Des détections triées dans la revue rapide. « Je ne sais pas » compte aussi.',
      ),
      findsOneWidget,
    );
    expect(find.text('36 sur 50'), findsOneWidget);
    expect(find.text('Plumes à : 10 · 50 · 200'), findsOneWidget);
  });

  testWidgets('before the first species', (tester) async {
    await pump(tester, progress: const GameProgress(GameFacts.empty));
    expect(find.text('Pas encore de niveau'), findsOneWidget);
    expect(
      find.text("Ton carnet t'attend. Lance une écoute au lever du jour."),
      findsOneWidget,
    );
    expect(find.text('Prochain niveau'), findsOneWidget);
    expect(find.text('Oisillon'), findsWidgets);
  });

  testWidgets('the top level shows a message instead of a next level', (
    tester,
  ) async {
    await pump(
      tester,
      progress: GameProgress(
        GameFacts(
          verifiedBirds: {for (var i = 0; i < GameConfig.statuses.last.from; i++) 'Species $i'},
          dawnChoruses: 0,
          earlyStarts: 0,
          reviewed: 0,
          migrants: const {},
          streak: Streak.empty,
        ),
      ),
    );
    expect(find.text('Tu as atteint le dernier niveau.'), findsOneWidget);
  });

  testWidgets('« niveau », not « statut », in the interface', (tester) async {
    await pump(tester);
    expect(find.textContaining('statut'), findsNothing);
    expect(find.textContaining('Statut'), findsNothing);
  });

  testWidgets('dark at 130 % on a small phone: no overflow', (tester) async {
    await pump(tester, dark: true, textScale: 1.3, size: const Size(320, 640));
    await tester.scrollUntilVisible(find.text('Les mésanges'), 200);
    expect(tester.takeException(), isNull);
  });
}
