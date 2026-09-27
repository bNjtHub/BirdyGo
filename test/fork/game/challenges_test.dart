import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/challenge_card.dart';
import 'package:birdnet_live/fork/game/challenges.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('weeks run Monday to Sunday', () {
    final sunday = DateTime(2026, 9, 27, 22);
    expect(weekStart(sunday), DateTime(2026, 9, 21));
    expect(weekEnd(sunday), DateTime(2026, 9, 28));
    expect(weekStart(DateTime(2026, 9, 28, 6)), DateTime(2026, 9, 28));
  });

  test('one challenge per week, in turn', () {
    final kinds = {
      for (var w = 0; w < GameConfig.weeklyChallenges.length; w++)
        challengeOfWeek(DateTime(2026, 9, 21 + 7 * w)).$1,
    };
    expect(kinds, hasLength(GameConfig.weeklyChallenges.length));
    expect(
      challengeOfWeek(DateTime(2026, 9, 21)),
      challengeOfWeek(DateTime(2026, 9, 27, 23)),
    );
  });

  test('a start counts for its week only', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ChallengeStore(await SharedPreferences.getInstance());
    final wednesday = DateTime(2026, 9, 23, 9);
    expect(store.startedAt(wednesday), isNull);
    await store.start(wednesday);
    expect(store.startedAt(DateTime(2026, 9, 27)), wednesday);
    expect(store.startedAt(DateTime(2026, 9, 28)), isNull);
  });

  group('ChallengeCard', () {
    Future<void> pump(
      WidgetTester tester,
      WeeklyChallenge challenge, {
      VoidCallback? onStart,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChallengeCard(challenge: challenge, onStart: onStart ?? () {}),
        ),
      ),
    );

    WeeklyChallenge challenge({DateTime? startedAt, int value = 0}) =>
        WeeklyChallenge(
          kind: ChallengeKind.dawnMornings,
          target: 3,
          startedAt: startedAt,
          value: value,
          ends: DateTime(2026, 9, 28),
        );

    testWidgets('offered: nothing counts before « Commencer »', (tester) async {
      var started = 0;
      await pump(tester, challenge(), onStart: () => started++);
      expect(find.text('Défi de la semaine'), findsOneWidget);
      expect(find.text('3 matins avant 8 h'), findsOneWidget);
      expect(
        find.text(
          'Rien ne compte avant « Commencer ». Pas de pénalité si le défi n\'est pas fini.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Commencer'));
      expect(started, 1);
    });

    testWidgets('started, then done', (tester) async {
      await pump(tester, challenge(startedAt: DateTime(2026, 9, 22), value: 2));
      expect(find.text("2 sur 3 · jusqu'à dimanche"), findsOneWidget);
      expect(find.text('Commencer'), findsNothing);

      await pump(tester, challenge(startedAt: DateTime(2026, 9, 22), value: 3));
      expect(find.text('Défi réussi !'), findsOneWidget);
    });
  });
}
