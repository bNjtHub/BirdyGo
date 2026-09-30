import 'dart:math';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/species_avatar.dart';
import 'package:birdnet_live/fork/game/fine_ear.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_screen.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_widgets.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart';
import 'package:birdnet_live/fork/game/quiz_fx.dart';
import 'package:birdnet_live/fork/game/quiz_sfx.dart';
import 'package:birdnet_live/fork/game/quiz_stop_sheet.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/species_page/species_clip_player.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:confetti/confetti.dart';
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

class _FakeSfx implements QuizSfxPlayer {
  final played = <QuizSound>[];

  @override
  Future<void> play(QuizSound sound) async => played.add(sound);

  @override
  Future<void> dispose() async {}
}

/// Pumps frames for [seconds]: the quiz has looping animations, so
/// pumpAndSettle would never return.
Future<void> settle(WidgetTester tester, {double seconds = 3}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

  test('stars: 40 %, 70 % and all right answers', () {
    expect(quizStars(0, 10), 0);
    expect(quizStars(3, 10), 0);
    expect(quizStars(4, 10), 1);
    expect(quizStars(7, 10), 2);
    expect(quizStars(9, 10), 2);
    expect(quizStars(10, 10), 3);
    expect(quizStars(4, 4), 3);
    expect(quizStars(0, 0), 0);
  });

  test('streak: right answers in a row at the end', () {
    expect(quizStreak(const []), 0);
    expect(quizStreak(const [true, true, false]), 0);
    expect(quizStreak(const [false, true, true]), 2);
    expect(quizStreak(const [true, true, true]), 3);
  });

  group('quiz screen', () {
    late SharedPreferences prefs;
    late _FakePlayer player;
    late _FakeSfx sfx;

    /// French names for species 0 to 5; others keep the index's name.
    TaxonomyService taxonomy() =>
        TaxonomyService()..loadFromCsv(
          [
            'birdnet_id,scientific_name,common_name,common_name_fr',
            for (var i = 0; i < 6; i++) 'BN$i,Species $i,English $i,Oiseau $i',
          ].join('\n'),
        );

    Future<void> pump(
      WidgetTester tester,
      Map<String, IndexedDetection> clips, {
      bool dark = false,
      double textScale = 1,
      Size size = const Size(390, 844),
      int correct = 0,
      bool start = true,
      bool reduced = false,
      bool? soundOn,
    }) async {
      SharedPreferences.setMockInitialValues({
        if (correct > 0) kFineEarCorrectPref: correct,
        if (soundOn != null) kQuizSoundPref: soundOn,
      });
      prefs = await SharedPreferences.getInstance();
      player = _FakePlayer();
      sfx = _FakeSfx();
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fineEarStoreProvider.overrideWithValue(FineEarStore(prefs)),
            speciesClipPlayerProvider.overrideWithValue(player),
            quizSfxPlayerProvider.overrideWithValue(sfx),
            taxonomyServiceProvider.overrideWith((ref) async => taxonomy()),
            effectiveSpeciesLocaleProvider.overrideWith((ref) => 'fr'),
          ],
          child: MaterialApp(
            theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    disableAnimations: reduced,
                  ),
                  child: child!,
                ),
            home: FineEarQuizScreen(
              random: Random(3),
              loadClips: () async => clips,
            ),
          ),
        ),
      );
      await settle(tester);
      if (start && find.text("C'est parti !").evaluate().isNotEmpty) {
        await tester.tap(find.text("C'est parti !"));
        await settle(tester);
      }
    }

    /// Scientific name of the bird being played.
    String playing() => player.played.last.split('/').last.split('-').first;

    Future<void> tapChoice(WidgetTester tester, String name) async {
      final choice = find.descendant(
        of: find.byType(QuizChoiceCard),
        matching: find.text(name),
      );
      await tester.ensureVisible(choice);
      await tester.pump();
      await tester.tap(choice);
      await settle(tester);
    }

    /// The name shown: French for species 0 to 5, the index's otherwise.
    String french(String scientificName) {
      final i = int.parse(scientificName.split(' ').last);
      return i < 6 ? 'Oiseau $i' : 'Common $scientificName';
    }

    Future<void> next(WidgetTester tester, {required bool last}) async {
      final button = find.text(last ? 'Voir mon score' : 'Continuer');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await settle(tester);
    }

    testWidgets('fewer than four birds: says what is missing', (tester) async {
      await pump(tester, _species(2));
      expect(find.text("Pas encore assez d'oiseaux"), findsOneWidget);
      expect(find.text("C'est parti !"), findsNothing);
    });

    testWidgets('the intro: the round, the badge, nothing played yet', (
      tester,
    ) async {
      await pump(tester, _species(4), correct: 5, start: false);
      expect(find.bySemanticsLabel('Qui chante ?'), findsOneWidget);
      expect(find.text('Écoute'), findsOneWidget);
      expect(find.text('4 chants de tes sorties'), findsOneWidget);
      expect(find.text('Devine'), findsOneWidget);
      expect(find.text('le bon oiseau parmi 4'), findsOneWidget);
      expect(find.text('Gagne'), findsOneWidget);
      expect(find.text('+1 à chaque bonne réponse'), findsOneWidget);
      expect(find.text('Badge Oreille fine'), findsOneWidget);
      expect(find.text('Ta première plume'), findsOneWidget);
      expect(find.text('Encore 5 bonnes réponses · 5 sur 10'), findsOneWidget);
      expect(find.byType(BadgeMedal), findsOneWidget);
      expect(player.played, isEmpty);

      await tester.tap(find.text("C'est parti !"));
      await settle(tester);
      expect(find.bySemanticsLabel(RegExp('^Chant 1 sur 4,')), findsOneWidget);
      expect(player.played, hasLength(1));
      expect(find.byType(QuizTrail), findsOneWidget);
    });

    testWidgets('names in the species language, with the bird photos', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final cards = find.byType(QuizChoiceCard);
      expect(cards, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(
          find.descendant(of: cards, matching: find.text('Oiseau $i')),
          findsOneWidget,
        );
      }
      expect(find.textContaining('English'), findsNothing);
      expect(find.textContaining('Common'), findsNothing);
      expect(
        find.descendant(of: cards, matching: find.byType(SpeciesAvatar)),
        findsNWidgets(4),
      );
    });

    testWidgets('a species the taxonomy lacks keeps the index name', (
      tester,
    ) async {
      await pump(tester, {
        for (var i = 4; i < 8; i++) 'Species $i': _clip('Species $i'),
      });
      expect(find.text('Oiseau 4'), findsOneWidget);
      expect(find.text('Common Species 7'), findsOneWidget);
    });

    testWidgets('the bird stays a mystery until the answer, then shows', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final stage = find.byType(QuizStage);
      expect(find.text('Oiseau mystère'), findsNothing);
      expect(
        find.descendant(of: stage, matching: find.byType(SpeciesAvatar)),
        findsNothing,
      );
      final answer = playing();
      expect(
        find.descendant(of: stage, matching: find.textContaining('Oiseau ')),
        findsNothing, // the bubble only
      );

      await tapChoice(tester, french(answer));
      expect(
        find.descendant(of: stage, matching: find.byType(SpeciesAvatar)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: stage,
          matching: find.text("Bravo, c'est bien lui : ${french(answer)}"),
        ),
        findsOneWidget,
      );
    });

    testWidgets('plays the clip, counts a right answer, then the next', (
      tester,
    ) async {
      await pump(tester, _species(4));
      expect(find.bySemanticsLabel(RegExp('^Chant 1 sur 4,')), findsOneWidget);
      expect(player.played, hasLength(1));
      expect(find.text("Touche l'oiseau qui chante"), findsOneWidget);

      await tapChoice(tester, french(playing()));
      expect(find.text('Bravo !'), findsOneWidget);
      expect(find.text('+1 Oreille fine'), findsOneWidget);
      expect(prefs.getInt(kFineEarCorrectPref), 1);
      expect(
        find.bySemanticsLabel('Chant 1 sur 4, 1 bonne réponse'),
        findsOneWidget, // the trail
      );

      await next(tester, last: false);
      expect(find.bySemanticsLabel(RegExp('^Chant 2 sur 4,')), findsOneWidget);
      expect(player.played, hasLength(2));
      expect(find.text('Oiseau mystère'), findsNothing);
    });

    testWidgets('two right answers in a row show the streak', (tester) async {
      await pump(tester, _species(4));
      await tapChoice(tester, french(playing()));
      expect(find.textContaining("d'affilée"), findsNothing);
      await next(tester, last: false);
      await tapChoice(tester, french(playing()));
      expect(find.text("2 d'affilée !"), findsOneWidget);
    });

    testWidgets('a wrong answer names the bird and counts nothing', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final answer = playing();
      final wrong = _species(4).keys.firstWhere((s) => s != answer);
      await tapChoice(tester, french(wrong));
      expect(find.text('Presque !'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp("^Presque ! C'était : ${french(answer)}")),
        findsOneWidget,
      );
      expect(find.text('+1 Oreille fine'), findsNothing);
      expect(prefs.getInt(kFineEarCorrectPref), isNull);
    });

    testWidgets('a wrong answer shows an encourage line', (tester) async {
      await pump(tester, _species(4));
      final answer = playing();
      final wrong = _species(4).keys.firstWhere((s) => s != answer);
      await tapChoice(tester, french(wrong));
      expect(find.text('Réécoute-le, tu le retiendras'), findsOneWidget);
    });

    testWidgets('a wrong answer replays the right song after the soft note', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final answer = playing();
      final wrong = _species(4).keys.firstWhere((s) => s != answer);
      expect(player.played, hasLength(1));
      await tapChoice(tester, french(wrong)); // settles 3 s
      expect(sfx.played, [QuizSound.soft]);
      expect(player.played, hasLength(2));
      expect(playing(), answer);
      expect(player.playing.value, player.played.last);
    });

    testWidgets('a right answer never replays the song', (tester) async {
      await pump(tester, _species(4));
      await tapChoice(tester, french(playing()));
      expect(player.played, hasLength(1));
      expect(player.playing.value, isNull);
    });

    testWidgets('the replay waits for the soft note to end', (tester) async {
      await pump(tester, _species(4));
      final wrong = _species(4).keys.firstWhere((s) => s != playing());
      final choice = find.descendant(
        of: find.byType(QuizChoiceCard),
        matching: find.text(french(wrong)),
      );
      await tester.tap(choice);
      await tester.pump(const Duration(milliseconds: 100));
      expect(sfx.played, [QuizSound.soft]);
      expect(player.played, hasLength(1)); // not yet
      await settle(tester, seconds: 1);
      expect(player.played, hasLength(2));
    });

    testWidgets('the play button keeps its place and size in the reveal', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final button = find.descendant(
        of: find.byType(QuizStage),
        matching: find.byTooltip("Arrêter l'extrait"),
      );
      final question = tester.getRect(button);
      await tapChoice(
        tester,
        french(_species(4).keys.firstWhere((s) => s != playing())),
      );
      final wrong = tester.getRect(button);
      expect(
        wrong.center,
        offsetMoreOrLessEquals(question.center, epsilon: .01),
      );
      expect(wrong.width, closeTo(question.width, .01));
      expect(wrong.height, closeTo(question.height, .01));
      // A right answer: the same spot again on the next question.
      await next(tester, last: false);
      final again = find.descendant(
        of: find.byType(QuizStage),
        matching: find.byTooltip("Arrêter l'extrait"),
      );
      final second = tester.getRect(again);
      await tapChoice(tester, french(playing()));
      final right = find.descendant(
        of: find.byType(QuizStage),
        matching: find.byTooltip("Écouter l'extrait"),
      );
      expect(
        tester.getCenter(right),
        offsetMoreOrLessEquals(second.center, epsilon: .01),
      );
      expect(tester.getSize(right).width, closeTo(second.width, .01));
    });

    testWidgets('no empty band above the stage, disc close to its top', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final trail = tester.getRect(find.byType(QuizTrail));
      final stage = tester.getRect(find.byType(QuizStage));
      final disc = tester.getRect(find.byType(QuizMysteryDisc));
      expect(stage.top - trail.bottom, lessThanOrEqualTo(BirdySpace.xl));
      expect(disc.top - stage.top, lessThanOrEqualTo(BirdySpace.l + 2));
    });

    testWidgets('the mystery card has no label, only the bubble', (
      tester,
    ) async {
      await pump(tester, _species(4));
      expect(find.text('Oiseau mystère'), findsNothing);
      expect(find.text('Qui suis-je ?'), findsOneWidget);
    });

    testWidgets('the end lists the missed birds, each with its clip', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final missed = <String>[];
      for (var i = 0; i < 4; i++) {
        final answer = playing();
        if (i.isEven) {
          await tapChoice(tester, french(answer));
        } else {
          missed.add(answer);
          final wrong = _species(4).keys.firstWhere((s) => s != answer);
          await tapChoice(tester, french(wrong));
        }
        await next(tester, last: i == 3);
      }
      expect(find.text('Sons à retenir'), findsOneWidget);
      final card = find.byKey(const ValueKey('quiz-missed-card'));
      await tester.ensureVisible(card);
      await tester.pump();
      for (final name in missed) {
        expect(
          find.descendant(of: card, matching: find.text(french(name))),
          findsOneWidget,
        );
      }
      final before = player.played.length;
      final play = find.byKey(ValueKey('quiz-missed-play ${missed.first}'));
      await tester.tap(play);
      await tester.pump();
      expect(player.played, hasLength(before + 1));
      expect(player.played.last, contains(missed.first));
      // One sound at a time: another row takes over, a second tap stops.
      await tester.tap(find.byKey(ValueKey('quiz-missed-play ${missed.last}')));
      await tester.pump();
      expect(player.playing.value, contains(missed.last));
      await tester.tap(find.byKey(ValueKey('quiz-missed-play ${missed.last}')));
      await tester.pump();
      expect(player.playing.value, isNull);
      // Leaving the screen stops the sound.
      await tester.tap(play);
      await tester.pump();
      expect(player.playing.value, isNotNull);
      await tester.pumpWidget(const SizedBox());
      expect(player.playing.value, isNull);
    });

    testWidgets('a perfect round has no « Sons à retenir »', (tester) async {
      await pump(tester, _species(4));
      for (var i = 0; i < 4; i++) {
        await tapChoice(tester, french(playing()));
        await next(tester, last: i == 3);
      }
      expect(find.text('Sons à retenir'), findsNothing);
    });

    testWidgets('the trail says the song and the right answers so far', (
      tester,
    ) async {
      await pump(tester, _species(4));
      expect(
        find.bySemanticsLabel('Chant 1 sur 4, aucune bonne réponse'),
        findsOneWidget,
      );
      await tapChoice(tester, french(playing()));
      expect(
        find.bySemanticsLabel('Chant 1 sur 4, 1 bonne réponse'),
        findsOneWidget,
      );
      await next(tester, last: false);
      expect(
        find.bySemanticsLabel('Chant 2 sur 4, 1 bonne réponse'),
        findsOneWidget,
      );
    });

    testWidgets('the stage bubble switches text with playback', (tester) async {
      // The round's first clip plays right away (« Qui suis-je ? »).
      await pump(tester, _species(4));
      expect(find.text('Qui suis-je ?'), findsOneWidget);
      expect(find.text('Écoute-moi !'), findsNothing);
      await tester.tap(find.byTooltip("Arrêter l'extrait"));
      await settle(tester, seconds: 0.5);
      expect(find.text('Écoute-moi !'), findsOneWidget);
      expect(find.text('Qui suis-je ?'), findsNothing);
    });

    testWidgets('the step cards keep their tilt while they pop in', (
      tester,
    ) async {
      await pump(tester, _species(4), start: false);
      final cards = find.byType(QuizPop);
      expect(cards, findsNWidgets(3));
      for (final card in cards.evaluate()) {
        final parent = find.ancestor(
          of: find.byWidget(card.widget),
          matching: find.byType(Transform),
        );
        expect(parent, findsWidgets);
      }
    });

    testWidgets('the cross asks first, and keeps the round on « Continuer »', (
      tester,
    ) async {
      await pump(tester, _species(4));
      expect(player.playing.value, isNotNull);
      expect(find.byTooltip('Retour'), findsNothing);
      await tester.tap(find.byTooltip('Quitter le quiz'));
      await settle(tester);
      expect(find.text('Arrêter la partie ?'), findsOneWidget);
      expect(
        find.text('Rien n\'est perdu : tu pourras rejouer quand tu veux.'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(QuizStopSheet),
          matching: find.text('Continuer'),
        ),
      );
      await settle(tester);
      expect(find.text('Arrêter la partie ?'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Chant 1 sur 4,')), findsOneWidget);
    });

    testWidgets('the sheet counts the right answers so far', (tester) async {
      await pump(tester, _species(4));
      await tapChoice(tester, french(playing()));
      await tester.tap(find.byTooltip('Quitter le quiz'));
      await settle(tester);
      expect(
        find.text('Ta bonne réponse est gardée pour le badge Oreille fine.'),
        findsOneWidget,
      );
    });

    testWidgets('the system back asks the same way', (tester) async {
      await pump(tester, _species(4));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Arrêter la partie ?'), findsOneWidget);
      expect(find.byType(FineEarQuizScreen), findsOneWidget);
    });

    testWidgets('no confirmation on the intro or on the score', (tester) async {
      await pump(tester, _species(4), start: false);
      await tester.tap(find.byTooltip('Retour'));
      await settle(tester);
      expect(find.byType(QuizStopSheet), findsNothing);

      await pump(tester, _species(4));
      for (var i = 0; i < 4; i++) {
        await tapChoice(tester, french(playing()));
        await next(tester, last: i == 3);
      }
      expect(find.byTooltip('Quitter le quiz'), findsOneWidget);
      await tester.tap(find.byTooltip('Quitter le quiz'));
      await settle(tester);
      expect(find.byType(QuizStopSheet), findsNothing);
    });

    testWidgets('the reveal: no article built by hand', (tester) async {
      await pump(tester, _species(4));
      final answer = playing();
      await tapChoice(tester, french(answer));
      expect(
        find.text('Bravo, c\'est bien lui : ${french(answer)}'),
        findsOneWidget,
      );
      await next(tester, last: false);
      final wrong = _species(4).keys.firstWhere((s) => s != playing());
      await tapChoice(tester, french(wrong));
      expect(find.text('C\'était : ${french(playing())}'), findsOneWidget);
    });

    testWidgets('the end of a round: stars, score, birds and a new plume', (
      tester,
    ) async {
      await pump(tester, _species(4), correct: 8);
      for (var i = 0; i < 4; i++) {
        await tapChoice(tester, french(playing()));
        await next(tester, last: i == 3);
      }
      expect(find.text('4/4'), findsOneWidget);
      expect(find.bySemanticsLabel('4 bonnes réponses sur 4'), findsOneWidget);
      expect(find.bySemanticsLabel('3 étoiles sur 3'), findsOneWidget);
      expect(find.text('Parfait !'), findsOneWidget);
      expect(
        find.text('Tu as reconnu 4 oiseaux sur 4 à leur chant.'),
        findsOneWidget,
      );
      expect(find.text('Tes oiseaux du jour'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r', bonne réponse$')),
        findsNWidgets(4),
      );
      expect(find.byType(BadgeMedal), findsOneWidget);
      expect(find.text('Oreille fine'), findsOneWidget);
      expect(find.text('Nouvelle plume'), findsOneWidget);
      expect(
        find.text(
          '+4 cette partie · 12 sur 50 vers la 2e plume',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Rejouer'), findsOneWidget);
      expect(find.text('Terminer'), findsOneWidget);

      await tester.tap(find.text('Rejouer'));
      await settle(tester);
      expect(find.bySemanticsLabel(RegExp('^Chant 1 sur 4,')), findsOneWidget);
      expect(player.played, hasLength(5));
    });

    testWidgets('a round with no right answer stays kind', (tester) async {
      await pump(tester, _species(4));
      for (var i = 0; i < 4; i++) {
        final answer = playing();
        final wrong = _species(4).keys.firstWhere((s) => s != answer);
        await tapChoice(tester, french(wrong));
        await next(tester, last: i == 3);
      }
      expect(find.text('0/4'), findsOneWidget);
      expect(find.text('Bon début !'), findsOneWidget);
      expect(
        find.text('Réécoute-les dans la sonothèque, puis retente ta chance.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r', manqué$')), findsNWidgets(4));
      expect(find.text('Nouvelle plume'), findsNothing);
      expect(
        find.text(
          '+0 cette partie · 0 sur 10 pour ta 1re plume',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    for (final dark in [false, true]) {
      testWidgets('small phone, text at 130 %, ${dark ? 'dark' : 'light'}: '
          'no overflow', (tester) async {
        await pump(
          tester,
          _species(4),
          dark: dark,
          textScale: 1.3,
          size: const Size(320, 568),
          start: false,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text("C'est parti !"));
        await settle(tester);
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 4; i++) {
          final answer = playing();
          final wrong = _species(4).keys.firstWhere((s) => s != answer);
          await tapChoice(tester, french(i.isEven ? answer : wrong));
          expect(tester.takeException(), isNull);
          await next(tester, last: i == 3);
        }
        expect(find.byType(BadgeMedal), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ten questions fit the trail on a small phone', (tester) async {
      await pump(
        tester,
        _species(12),
        textScale: 1.3,
        size: const Size(320, 568),
      );
      expect(find.bySemanticsLabel(RegExp('^Chant 1 sur 10,')), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        await tapChoice(tester, french(playing()));
        expect(tester.takeException(), isNull);
        await next(tester, last: i == 9);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sound switch: on by default, remembered, effects only', (
      tester,
    ) async {
      await pump(tester, _species(4), start: false);
      final toggle = find.byType(QuizSoundSwitch);
      expect(toggle, findsOneWidget);
      expect(find.text('Avec effets'), findsOneWidget);
      await tester.tap(toggle);
      await settle(tester, seconds: 0.5);
      expect(find.text('Sans effets'), findsOneWidget);
      expect(prefs.getBool(kQuizSoundPref), isFalse);

      await tester.tap(find.text("C'est parti !"));
      await settle(tester);
      expect(player.played, hasLength(1)); // the bird still sings
      await tapChoice(tester, french(playing()));
      expect(sfx.played, isEmpty);
    });

    testWidgets('the sound switch starts from the remembered choice', (
      tester,
    ) async {
      await pump(tester, _species(4), start: false, soundOn: false);
      expect(find.text('Sans effets'), findsOneWidget);
      await tester.tap(find.byType(QuizSoundSwitch));
      await settle(tester, seconds: 0.5);
      expect(prefs.getBool(kQuizSoundPref), isTrue);
    });

    testWidgets('a right answer: confetti from the card, a jingle', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final name = french(playing());
      final card = find.ancestor(
        of: find.text(name),
        matching: find.byType(QuizChoiceCard),
      );
      final center = tester.getCenter(card);
      await tester.tap(find.text(name));
      await tester.pump();
      await tester.pump();
      final confetti = tester.widget<ConfettiWidget>(
        find.byType(ConfettiWidget),
      );
      expect(
        confetti.confettiController.state,
        ConfettiControllerState.playing,
      );
      expect(confetti.numberOfParticles, 110);
      final at = tester.getTopLeft(find.byType(ConfettiWidget));
      expect((at - center).distance, lessThan(1));
      expect(sfx.played, [QuizSound.success]);
      await settle(tester);
      expect(find.text('+1 Oreille fine'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuizStage),
          matching: find.byType(QuizRays),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a wrong answer: no confetti, a soft note, a gentle card', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final answer = playing();
      final wrong = _species(4).keys.firstWhere((s) => s != answer);
      await tester.tap(find.text(french(wrong)));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(sfx.played, [QuizSound.soft]);
      await settle(tester);
      expect(find.byType(QuizRays), findsNothing);
      final picked = tester.widget<QuizChoiceCard>(
        find.ancestor(
          of: find.text(french(wrong)),
          matching: find.byType(QuizChoiceCard),
        ),
      );
      expect(picked.state, QuizChoiceState.wrong);
      final states = tester
          .widgetList<QuizChoiceCard>(find.byType(QuizChoiceCard))
          .map((c) => c.state);
      expect(states.where((s) => s == QuizChoiceState.other), hasLength(2));
      expect(states.where((s) => s == QuizChoiceState.right), hasLength(1));
    });

    testWidgets('reduced motion: no confetti, nothing moves', (tester) async {
      await pump(tester, _species(4), reduced: true);
      // No loop runs: the screen settles.
      await tester.pumpAndSettle();
      await tester.tap(find.text(french(playing())));
      await tester.pumpAndSettle();
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(sfx.played, [QuizSound.success]);
    });

    testWidgets('the result: stars, a 5 × 2 grid, buttons, rain, fanfare', (
      tester,
    ) async {
      await pump(tester, _species(12));
      for (var i = 0; i < 10; i++) {
        await tapChoice(tester, french(playing()));
        await next(tester, last: i == 9);
      }
      expect(find.text('10/10'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        final star = tester.widget<QuizRimStar>(
          find.byKey(ValueKey('quiz-star-$i')),
        );
        expect(star.color, BirdyColors.light.oriole);
        expect(star.rim, BirdyQuizColors.starRim);
        expect(star.size, i == 1 ? 56 : 42);
      }
      for (var r = 0; r < 2; r++) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('quiz-recap-row-$r')),
            matching: find.byType(QuizBirdArt),
          ),
          findsNWidgets(5),
        );
      }
      expect(find.byKey(const ValueKey('quiz-recap-row-2')), findsNothing);
      expect(find.byType(ConfettiWidget), findsNWidgets(3));
      expect(sfx.played.last, QuizSound.fanfare);
      expect(find.widgetWithText(OutlinedButton, 'Terminer'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Rejouer'), findsOneWidget);
      // The glow is the card's own decoration.
      final card = tester.widget<Container>(
        find.byKey(const ValueKey('quiz-score-card')),
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<RadialGradient>());
      expect(decoration.borderRadius, BorderRadius.circular(28));
    });

    testWidgets('a weak round: grey stars, no rain, no fanfare', (
      tester,
    ) async {
      await pump(tester, _species(4));
      for (var i = 0; i < 4; i++) {
        final answer = playing();
        final wrong = _species(4).keys.firstWhere((s) => s != answer);
        await tapChoice(tester, french(i == 0 ? answer : wrong));
        await next(tester, last: i == 3);
      }
      final star = tester.widget<QuizRimStar>(
        find.byKey(const ValueKey('quiz-star-0')),
      );
      expect(star.color, BirdyColors.light.lineOpaque);
      expect(star.rim, BirdyColors.light.border);
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(sfx.played, isNot(contains(QuizSound.fanfare)));
    });

    for (final size in const [Size(390, 844), Size(360, 640), Size(320, 640)]) {
      testWidgets('${size.width.toInt()} × ${size.height.toInt()}: the '
          'bottom cards and the button stay in view', (tester) async {
        await pump(tester, _species(4), size: size);
        final bottom = size.height;
        for (final e in find.byType(QuizChoiceCard).evaluate()) {
          final box = e.renderObject! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          expect(rect.bottom, lessThanOrEqualTo(bottom));
        }
        expect(
          tester.getRect(find.text("Touche l'oiseau qui chante")).bottom,
          lessThanOrEqualTo(bottom),
        );
        await tester.tap(find.text(french(playing())));
        await settle(tester);
        expect(
          tester.getRect(find.byType(FilledButton)).bottom,
          lessThanOrEqualTo(bottom),
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final dark in [false, true]) {
      for (final size in const [Size(360, 640), Size(320, 640)]) {
        testWidgets('${size.width.toInt()} × ${size.height.toInt()}, text at '
            '130 %, ${dark ? 'dark' : 'light'}: no overflow', (tester) async {
          await pump(
            tester,
            _species(12),
            dark: dark,
            textScale: 1.3,
            size: size,
            start: false,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text("C'est parti !"));
          await settle(tester);
          for (var i = 0; i < 10; i++) {
            final answer = playing();
            final wrong = tester
                .widgetList<QuizChoiceCard>(find.byType(QuizChoiceCard))
                .map((c) => c.bird.scientificName)
                .firstWhere((s) => s != answer);
            await tapChoice(tester, french(i.isEven ? answer : wrong));
            expect(tester.takeException(), isNull);
            await next(tester, last: i == 9);
          }
          expect(find.byType(BadgeMedal), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('trail of stones', () {
    Future<void> pumpTrail(
      WidgetTester tester, {
      required List<bool> results,
      required int current,
      double width = 300,
      bool dark = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: QuizTrail(
                  birds: [
                    for (var i = 0; i < 10; i++)
                      QuizBird(
                        scientificName: 'Species $i',
                        latin: 'Species $i',
                        name: 'Oiseau $i',
                      ),
                  ],
                  results: results,
                  current: current,
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester, seconds: 1);
    }

    Finder stone(int i) => find.descendant(
      of: find.byKey(ValueKey('quiz-stone-$i')),
      matching: find.byType(QuizStone),
    );

    Finder disc(int i) =>
        find.descendant(of: stone(i), matching: find.byType(Container)).first;

    testWidgets('upcoming, current, right and wrong steps', (tester) async {
      await pumpTrail(tester, results: const [true, false], current: 2);
      QuizStoneState stateOf(int i) => tester.widget<QuizStone>(stone(i)).state;
      expect(stateOf(0), QuizStoneState.right);
      expect(stateOf(1), QuizStoneState.wrong);
      expect(stateOf(2), QuizStoneState.current);
      for (var i = 3; i < 10; i++) {
        expect(stateOf(i), QuizStoneState.upcoming);
      }
      expect(
        find.bySemanticsLabel('Chant 3 sur 10, 1 bonne réponse'),
        findsOneWidget,
      );
      expect(tester.getSize(disc(0)), const Size(26, 26));
      expect(tester.getSize(disc(1)), const Size(20, 20));
      expect(tester.getSize(disc(2)), const Size(30, 30));
      expect(tester.getSize(disc(5)), const Size(12, 12));
    });

    testWidgets('fixed 24 px steps, the line from the first center to the '
        'last, the fill up to the current step', (tester) async {
      await pumpTrail(tester, results: const [true, true, false], current: 3);
      final left = tester.getTopLeft(find.byType(QuizTrail)).dx;
      const width = 300.0;
      const span = width - QuizTrail.slot;
      for (var i = 0; i < 10; i++) {
        final slot = tester.getRect(find.byKey(ValueKey('quiz-stone-$i')));
        expect(slot.width, QuizTrail.slot);
        expect(
          slot.center.dx - left,
          moreOrLessEquals(12 + span * i / 9, epsilon: 0.01),
        );
        // Each step is centered in its slot, on the line.
        final rect = tester.getRect(disc(i));
        expect(rect.center.dx, moreOrLessEquals(slot.center.dx, epsilon: .01));
        expect(rect.center.dy, moreOrLessEquals(slot.center.dy, epsilon: .01));
      }
      final line = tester.getRect(
        find.byKey(const ValueKey('quiz-trail-line')),
      );
      expect(line.left - left, 12);
      expect(line.right - left, width - 12);
      expect(line.height, QuizTrail.line);
      expect(
        line.center.dy,
        moreOrLessEquals(tester.getRect(disc(5)).center.dy, epsilon: .01),
      );
      final fill = tester.getRect(
        find.byKey(const ValueKey('quiz-trail-fill')),
      );
      expect(fill.left - left, 12);
      expect(fill.width, moreOrLessEquals(span * 3 / 9, epsilon: 0.01));
    });

    testWidgets('an upcoming dot wears a ring of the page color', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await pumpTrail(tester, results: const [], current: 0, dark: dark);
        final dot = tester.widget<Container>(disc(4));
        final decoration = dot.decoration! as BoxDecoration;
        final c = dark ? BirdyColors.dark : BirdyColors.light;
        expect(decoration.boxShadow!.single.color, c.background);
        expect(decoration.boxShadow!.single.spreadRadius, 3);
      }
    });

    testWidgets('narrow: ten steps still fit', (tester) async {
      await pumpTrail(tester, results: const [], current: 0, width: 200);
      final trail = tester.getRect(find.byType(QuizTrail));
      final last = tester.getRect(find.byKey(const ValueKey('quiz-stone-9')));
      expect(last.right, lessThanOrEqualTo(trail.right + .01));
      expect(tester.takeException(), isNull);
    });
  });
}
