import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/profile/profile_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProgressProvider.overrideWith(
            (ref) async => progress ?? _player(),
          ),
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

  testWidgets('status, ladder, série and badges (SPEC.md 9.11)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Sentinelle des haies'), findsWidgets);
    expect(find.text('24 espèces découvertes'), findsOneWidget);
    expect(
      find.text('Encore 11 espèces pour devenir Oreille de chouette'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('Progression vers le prochain statut : 27 %'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('8 statuts, du premier oiseau au centième.'),
      findsOneWidget,
    );
    expect(find.text('Série : 9 jours'), findsOneWidget);
    expect(find.text('Record : 9 jours'), findsOneWidget);

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

  testWidgets('a badge explains its rule', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Réviseur'), 200);
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
    expect(find.text('Pas encore de statut'), findsOneWidget);
    expect(
      find.text("Ton carnet t'attend. Lance une écoute au lever du jour."),
      findsOneWidget,
    );
    expect(find.text('Encore 1 espèce pour devenir Oisillon'), findsOneWidget);
  });

  testWidgets('dark at 130 % on a small phone: no overflow', (tester) async {
    await pump(tester, dark: true, textScale: 1.3, size: const Size(320, 640));
    await tester.scrollUntilVisible(find.text('Les mésanges'), 200);
    expect(tester.takeException(), isNull);
  });
}
