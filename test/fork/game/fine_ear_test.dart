import 'dart:math';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/fine_ear.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_screen.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/species_page/species_clip_player.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

IndexedDetection _clip(
  String name, {
  String? path,
  double confidence = .95,
  ReviewStatus review = ReviewStatus.unreviewed,
  int position = 0,
}) => IndexedDetection(
  key: '$name-$position',
  sessionId: 's',
  position: position,
  scientificName: name,
  commonName: 'Common $name',
  start: DateTime(2026, 9, 20, 7),
  end: null,
  confidence: confidence,
  reviewStatus: review,
  latitude: null,
  longitude: null,
  clipPath: path ?? '/clips/$name-$position.wav',
);

Map<String, IndexedDetection> _species(int count) => {
  for (var i = 0; i < count; i++) 'Species $i': _clip('Species $i'),
};

class _FakePlayer implements SpeciesClipPlayer {
  final ValueNotifier<String?> _playing = ValueNotifier(null);
  final played = <String>[];

  @override
  ValueListenable<String?> get playing => _playing;

  @override
  Future<void> play(String clipPath) async {
    played.add(clipPath);
    _playing.value = clipPath;
  }

  @override
  Future<void> stop() async => _playing.value = null;
}

void main() {
  group('quizClip', () {
    test('a confirmed clip first, then the best Sûr score', () {
      final best = _clip('A', confidence: .99, position: 1);
      final confirmed = _clip(
        'A',
        confidence: .5,
        review: ReviewStatus.confirmed,
        position: 2,
      );
      expect(quizClip([best, confirmed], fileExists: (_) => true), confirmed);
      expect(quizClip([best], fileExists: (_) => true), best);
    });

    test('never a rejected, weak or missing clip', () {
      final rejected = _clip('A', review: ReviewStatus.rejected, position: 1);
      final weak = _clip(
        'A',
        confidence: ReliabilityConfig.sureMinScore - .01,
        position: 2,
      );
      final gone = _clip('A', position: 3);
      final kept = _clip('A', confidence: .9, position: 4);
      expect(quizClip([rejected, weak], fileExists: (_) => true), isNull);
      expect(
        quizClip([gone, kept], fileExists: (p) => p != gone.clipPath),
        kept,
      );
    });
  });

  group('drawQuiz', () {
    test('needs four species', () {
      expect(drawQuiz(_species(3), Random(1)), isEmpty);
    });

    test('each species asked once, four different choices with the answer', () {
      final quiz = drawQuiz(_species(12), Random(2));
      expect(quiz, hasLength(GameConfig.quizQuestions));
      expect(
        quiz.map((q) => q.answer.scientificName).toSet(),
        hasLength(GameConfig.quizQuestions),
      );
      for (final q in quiz) {
        final names = q.choices.map((c) => c.scientificName).toSet();
        expect(names, hasLength(GameConfig.quizChoices));
        expect(names, contains(q.answer.scientificName));
      }
    });

    test('the order is drawn at random', () {
      String order(int seed) =>
          drawQuiz(
            _species(8),
            Random(seed),
          ).map((q) => q.answer.scientificName).join();
      expect(
        {for (var seed = 0; seed < 5; seed++) order(seed)}.length,
        greaterThan(1),
      );
    });
  });

  test('Oreille fine: right answers, tiers 10 / 50 / 150', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FineEarStore(await SharedPreferences.getInstance());
    for (var i = 0; i < 10; i++) {
      await store.addCorrect();
    }
    expect(store.correct(), 10);
    final badge = GameProgress(
      GameFacts(
        verifiedBirds: const {},
        dawnChoruses: 0,
        earlyStarts: 0,
        reviewed: 0,
        migrants: const {},
        streak: GameFacts.empty.streak,
        fineEarCorrect: store.correct(),
      ),
    ).badges.singleWhere((b) => b.kind == BadgeKind.fineEar);
    expect(badge.tier, 1);
    expect(badge.nextTarget, 50);
  });

  group('quiz screen', () {
    late SharedPreferences prefs;
    late _FakePlayer player;

    Future<void> pump(
      WidgetTester tester,
      Map<String, IndexedDetection> clips,
    ) async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      player = _FakePlayer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fineEarStoreProvider.overrideWithValue(FineEarStore(prefs)),
            speciesClipPlayerProvider.overrideWithValue(player),
          ],
          child: MaterialApp(
            theme: BirdyTheme.light(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FineEarQuizScreen(
              random: Random(3),
              loadClips: () async => clips,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('fewer than four birds: says what is missing', (tester) async {
      await pump(tester, _species(2));
      expect(find.text("Pas encore assez d'oiseaux"), findsOneWidget);
    });

    testWidgets('plays the clip, counts a right answer, then the next', (
      tester,
    ) async {
      await pump(tester, _species(4));
      expect(find.text('Question 1 sur 4'), findsOneWidget);
      expect(player.played, hasLength(1));

      final answer = player.played.single.split('/').last.split('-').first;
      await tester.tap(find.text('Common $answer'));
      await tester.pumpAndSettle();
      expect(find.text("Bien vu, c'est lui !"), findsOneWidget);
      expect(prefs.getInt(kFineEarCorrectPref), 1);

      await tester.tap(find.text('Question suivante'));
      await tester.pumpAndSettle();
      expect(find.text('Question 2 sur 4'), findsOneWidget);
      expect(player.played, hasLength(2));
    });

    testWidgets('a wrong answer names the bird and counts nothing', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final answer = player.played.single.split('/').last.split('-').first;
      final wrong = _species(4).keys.firstWhere((s) => s != answer);
      await tester.tap(find.text('Common $wrong'));
      await tester.pumpAndSettle();
      expect(find.text('C\'était : Common $answer'), findsOneWidget);
      expect(prefs.getInt(kFineEarCorrectPref), isNull);
    });
  });
}
