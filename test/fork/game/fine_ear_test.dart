import 'dart:math';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/species_avatar.dart';
import 'package:birdnet_live/fork/game/fine_ear.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_screen.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_widgets.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/species_page/species_clip_player.dart';
import 'package:birdnet_live/fork/species_photo/species_photo.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
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
    }) async {
      SharedPreferences.setMockInitialValues({
        if (correct > 0) kFineEarCorrectPref: correct,
      });
      prefs = await SharedPreferences.getInstance();
      player = _FakePlayer();
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fineEarStoreProvider.overrideWithValue(FineEarStore(prefs)),
            speciesClipPlayerProvider.overrideWithValue(player),
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
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
            home: FineEarQuizScreen(
              random: Random(3),
              loadClips: () async => clips,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Scientific name of the bird being played.
    String playing() => player.played.last.split('/').last.split('-').first;

    Future<void> tapChoice(WidgetTester tester, String name) async {
      await tester.tap(
        find.descendant(
          of: find.byType(QuizChoiceCard),
          matching: find.text(name),
        ),
      );
      await tester.pumpAndSettle();
    }

    String french(String scientificName) =>
        'Oiseau ${scientificName.split(' ').last}';

    Future<void> next(WidgetTester tester, {required bool last}) async {
      await tester.ensureVisible(
        find.text(last ? 'Voir le résultat' : 'Question suivante'),
      );
      await tester.tap(
        find.text(last ? 'Voir le résultat' : 'Question suivante'),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('fewer than four birds: says what is missing', (tester) async {
      await pump(tester, _species(2));
      expect(find.text("Pas encore assez d'oiseaux"), findsOneWidget);
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
      expect(find.text('Oiseau mystère'), findsOneWidget);
      expect(find.byType(SpeciesPhoto), findsNothing);
      final answer = playing();
      expect(find.text(answer), findsNothing);

      await tapChoice(tester, french(answer));
      expect(find.text('Oiseau mystère'), findsNothing);
      expect(find.byType(SpeciesPhoto), findsOneWidget);
      expect(find.text(answer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuizStage),
          matching: find.text(french(answer)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('plays the clip, counts a right answer, then the next', (
      tester,
    ) async {
      await pump(tester, _species(4));
      expect(find.text('Question 1 sur 4'), findsOneWidget);
      expect(player.played, hasLength(1));

      await tapChoice(tester, french(playing()));
      expect(find.text("Bien vu, c'est lui !"), findsOneWidget);
      expect(prefs.getInt(kFineEarCorrectPref), 1);

      await next(tester, last: false);
      expect(find.text('Question 2 sur 4'), findsOneWidget);
      expect(player.played, hasLength(2));
      expect(find.text('Oiseau mystère'), findsOneWidget);
    });

    testWidgets('a wrong answer names the bird and counts nothing', (
      tester,
    ) async {
      await pump(tester, _species(4));
      final answer = playing();
      final wrong = _species(4).keys.firstWhere((s) => s != answer);
      await tapChoice(tester, french(wrong));
      expect(find.text('La bonne réponse'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp("^C'était : ${french(answer)}")),
        findsOneWidget,
      );
      expect(prefs.getInt(kFineEarCorrectPref), isNull);
    });

    testWidgets('the end of a round: score, medal and a new plume', (
      tester,
    ) async {
      await pump(tester, _species(4), correct: 8);
      for (var i = 0; i < 4; i++) {
        await tapChoice(tester, french(playing()));
        await next(tester, last: i == 3);
      }
      expect(find.text('4 bonnes réponses sur 4'), findsOneWidget);
      expect(find.byType(BadgeMedal), findsOneWidget);
      expect(find.text('Oreille fine'), findsOneWidget);
      expect(find.text('Nouvelle plume'), findsOneWidget);
      expect(find.text('12 sur 50 vers la prochaine plume'), findsOneWidget);
      expect(find.text('Rejouer'), findsOneWidget);
      expect(find.text('Terminer'), findsOneWidget);
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
        );
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 4; i++) {
          final answer = playing();
          final wrong = _species(4).keys.firstWhere((s) => s != answer);
          final pick = french(i.isEven ? answer : wrong);
          await tester.ensureVisible(find.text(pick).last);
          await tapChoice(tester, pick);
          expect(tester.takeException(), isNull);
          await next(tester, last: i == 3);
        }
        expect(find.byType(BadgeMedal), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
