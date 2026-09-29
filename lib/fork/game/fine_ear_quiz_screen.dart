/// « Qui chante ? » (J6e, Quiz v2, badge Oreille fine). An intro, then up
/// to [GameConfig.quizQuestions] of your own recordings, each with four
/// birds (icon or photo and name in the species language), one right; a
/// trail of stones follows the round. A right answer bursts into confetti
/// with a jingle, a wrong one stays gentle. Each right answer counts toward
/// the badge; the round ends on stars, the score and the birds heard, with
/// a rain of confetti and a fanfare for a good score.
library;

import 'dart:async';
import 'dart:math';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_confetti.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../species_page/species_clip_player.dart';
import 'fine_ear.dart';
import 'fine_ear_quiz_widgets.dart';
import 'game_config.dart';
import 'game_loader.dart';
import 'quiz_fx.dart';
import 'quiz_sfx.dart';

class FineEarQuizScreen extends ConsumerStatefulWidget {
  const FineEarQuizScreen({
    super.key,
    this.random,
    this.fileExists,
    this.loadClips,
  });

  /// For tests: a seeded draw.
  final Random? random;

  /// For tests: which clip files exist.
  final bool Function(String path)? fileExists;

  /// For tests: the clips to ask, instead of the game and the index.
  final Future<Map<String, IndexedDetection>> Function()? loadClips;

  @override
  ConsumerState<FineEarQuizScreen> createState() => _FineEarQuizScreenState();
}

enum _Phase { intro, question, result }

class _FineEarQuizScreenState extends ConsumerState<FineEarQuizScreen> {
  static const double _maxWidth = 560;

  /// Mockup sizes of the stage and the answer cards (390 × 844).
  static const double _stage = QuizStage.defaultHeight;
  static const double _tile = QuizChoiceCard.defaultHeight;

  late final Random _random = widget.random ?? Random();
  late final SpeciesClipPlayer _player = ref.read(speciesClipPlayerProvider);
  Map<String, IndexedDetection>? _clips;
  List<QuizQuestion> _questions = const [];
  _Phase _phase = _Phase.intro;
  int _current = 0;
  String? _picked;

  /// Each answer of the round, in order.
  final List<bool> _results = [];

  /// Oreille fine right answers when the round started.
  int _startCorrect = 0;

  /// A right answer changed the badge: the game reloads on leaving.
  bool _scored = false;

  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _choiceKeys = List.generate(
    GameConfig.quizChoices,
    (_) => GlobalKey(),
  );
  final ConfettiController _burst = ConfettiController(
    duration: BirdyConfettiMotion.emission,
  );
  final ConfettiController _rain = ConfettiController(
    duration: BirdyConfettiMotion.emission,
  );

  /// The round ended well enough for the rain of confetti.
  bool _party = false;

  /// Where the last burst starts (center of the tapped card) and its colors.
  Offset? _burstOrigin;
  List<Color> _burstColors = BirdyConfettiColors.burst;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _burst.dispose();
    _rain.dispose();
    super.dispose();
  }

  Future<Map<String, IndexedDetection>> _clipsFromIndex() async {
    final progress = await ref.read(gameProgressProvider.future);
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    return loadQuizClips(
      index,
      progress.facts.verifiedBirds,
      fileExists: widget.fileExists,
    );
  }

  Future<void> _load() async {
    final clips = await (widget.loadClips ?? _clipsFromIndex)();
    if (!mounted) return;
    setState(() {
      _clips = clips;
      _questions = drawQuiz(clips, _random);
    });
  }

  /// A new round, straight to its first question.
  void _start() {
    final clips = _clips;
    if (clips == null) return;
    _burst.stop(clearAllParticles: true);
    _rain.stop(clearAllParticles: true);
    setState(() {
      _questions = drawQuiz(clips, _random);
      _phase = _Phase.question;
      _current = 0;
      _picked = null;
      _burstOrigin = null;
      _results.clear();
      _startCorrect = ref.read(fineEarStoreProvider).correct();
    });
    _playCurrent();
  }

  void _toIntro() {
    unawaited(_player.stop());
    _burst.stop(clearAllParticles: true);
    _rain.stop(clearAllParticles: true);
    setState(() {
      _phase = _Phase.intro;
      _picked = null;
      _burstOrigin = null;
    });
  }

  QuizQuestion? get _question =>
      _phase == _Phase.question && _current < _questions.length
          ? _questions[_current]
          : null;

  void _playCurrent() {
    final path = _question?.answer.clipPath;
    if (path != null) unawaited(_player.play(path));
  }

  void _togglePlay() {
    final path = _question?.answer.clipPath;
    if (path == null) return;
    unawaited(
      _player.playing.value == path ? _player.stop() : _player.play(path),
    );
  }

  bool get _reduced => BirdyMotion.reduced(context);

  /// Center of answer card [index] in the screen's stack.
  Offset? _centerOf(int index) {
    final card =
        _choiceKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (card == null || stack == null || !card.hasSize) return null;
    return stack.globalToLocal(
      card.localToGlobal(card.size.center(Offset.zero)),
    );
  }

  Future<void> _answer(int index, String scientificName) async {
    final question = _question;
    if (question == null || _picked != null) return;
    final right = scientificName == question.answer.scientificName;
    final tint = SpeciesAccents.tintOf(question.answer.scientificName);
    setState(() {
      _picked = scientificName;
      _results.add(right);
      if (right) {
        _burstOrigin = _centerOf(index);
        _burstColors = [tint.accent, ...BirdyConfettiColors.burst, tint.deep];
      }
    });
    // The clip stops: the reveal takes the stage.
    unawaited(_player.stop());
    if (right) {
      _scored = true;
      if (!_reduced) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _burst.play();
        });
      }
      playQuizSound(ref, QuizSound.success);
      unawaited(BirdyHaptics.light());
      await ref.read(fineEarStoreProvider).addCorrect();
    } else {
      playQuizSound(ref, QuizSound.soft);
    }
  }

  void _next() {
    if (_current + 1 >= _questions.length) {
      unawaited(_player.stop());
      final right = _results.where((r) => r).length;
      final party =
          _results.isNotEmpty &&
          right >= (_results.length * GameConfig.quizPartyShare).ceil();
      setState(() {
        _phase = _Phase.result;
        _picked = null;
        _burstOrigin = null;
        _party = party;
      });
      if (party) {
        if (!_reduced) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _rain.play();
          });
        }
        playQuizSound(ref, QuizSound.fanfare);
      }
      return;
    }
    setState(() {
      _current++;
      _picked = null;
    });
    _playCurrent();
  }

  void _leave() {
    unawaited(_player.stop());
    if (_scored) ref.invalidate(gameProgressProvider);
  }

  /// How a bird is shown: its name in the species language (the name
  /// stored in the index as a fallback), its drawn icon or its bundled
  /// photo, the same way as the notebook and the sound library.
  QuizBird _bird(String scientificName, String fallbackName) {
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final locale = ref.watch(effectiveSpeciesLocaleProvider);
    return _birdOf(taxonomy, locale, scientificName, fallbackName);
  }

  static QuizBird _birdOf(
    TaxonomyService? taxonomy,
    String locale,
    String scientificName,
    String fallbackName,
  ) {
    final species = taxonomy?.lookup(scientificName);
    final path = taxonomy?.assetImagePath(scientificName);
    return QuizBird(
      scientificName: scientificName,
      latin: taxonomy?.displayScientificName(scientificName) ?? scientificName,
      name: species?.commonNameForLocale(locale) ?? fallbackName,
      image: path == null ? null : AssetImage(path),
      species: species,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final loading = _clips == null;
    final empty = !loading && _questions.isEmpty;
    final inRound = !loading && !empty && _phase != _Phase.intro;
    final reduced = BirdyMotion.reduced(context);

    final Widget body;
    final Widget header;
    if (loading || empty) {
      header = _titleBar(context, onBack: () => Navigator.maybePop(context));
      body =
          loading
              ? const Center(child: CircularProgressIndicator())
              : BirdyEntrance(
                child: BirdyEmptyState(
                  icon: AppIcons.headphones,
                  title: l10n.forkQuizEmptyTitle,
                  body: l10n.forkQuizEmpty,
                ),
              );
    } else {
      switch (_phase) {
        case _Phase.intro:
          header = _introBar(context);
          body = _intro();
        case _Phase.question:
          header = _questionBar(context);
          body = _questionView(context);
        case _Phase.result:
          header = _titleBar(context, onBack: _toIntro);
          body = _result();
      }
    }

    final origin = _burstOrigin;
    return PopScope(
      // In a round, back returns to the intro, like the on-screen button.
      canPop: !inRound,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _leave();
        } else {
          _toIntro();
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Stack(
            key: _stackKey,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BirdySpace.xl,
                      BirdySpace.l,
                      BirdySpace.xl,
                      BirdySpace.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [header, Expanded(child: body)],
                    ),
                  ),
                ),
              ),
              // Confetti, never with reduced motion.
              if (!reduced && origin != null && _phase == _Phase.question)
                Positioned(
                  left: origin.dx,
                  top: origin.dy,
                  child: BirdyConfetti.burst(
                    key: ValueKey('quiz-burst $_current'),
                    controller: _burst,
                    colors: _burstColors,
                  ),
                ),
              if (!reduced && _party && _phase == _Phase.result)
                for (final spot in BirdyConfettiMotion.rainSpots)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(spot * 2 - 1, -1),
                      child: BirdyConfetti.rain(
                        key: ValueKey('quiz-rain $spot'),
                        controller: _rain,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar(BuildContext context, {required VoidCallback onBack}) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BirdySpace.m),
      child: SizedBox(
        height: BirdySizes.target,
        child: Row(
          children: [
            BirdyIconButton(
              icon: AppIcons.arrowBackRounded,
              semanticLabel: l10n.tooltipBack,
              onPressed: onBack,
            ),
            const SizedBox(width: BirdySpace.m),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.forkQuizTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BirdyText.title.copyWith(color: c.text1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Back on the left, « Avec son / Sans son » on the right.
  Widget _introBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: BirdySpace.l),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BirdySizes.target),
        child: Row(
          children: [
            BirdyIconButton(
              icon: AppIcons.arrowBackRounded,
              semanticLabel: l10n.tooltipBack,
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: BirdySpace.m),
            const Spacer(),
            Flexible(
              flex: 4,
              child: Align(
                alignment: Alignment.centerRight,
                child: QuizSoundSwitch(
                  on: ref.watch(quizSoundOnProvider),
                  onChanged:
                      (on) => ref.read(quizSoundOnProvider.notifier).set(on),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    final correct = ref.watch(fineEarStoreProvider).correct();
    return QuizIntro(
      birds: [
        for (final q in _questions.take(4))
          _bird(q.answer.scientificName, q.answer.commonName),
      ],
      questions: _questions.length,
      choices: GameConfig.quizChoices,
      badge: fineEarBadge(correct),
      onStart: _start,
    );
  }

  /// Close (back to the intro) and the trail of stones.
  Widget _questionBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: BirdySizes.target,
      child: Row(
        children: [
          BirdyIconButton(
            icon: AppIcons.quizClose,
            semanticLabel: l10n.forkQuizQuit,
            onPressed: _toIntro,
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: QuizTrail(
              birds: [
                for (final q in _questions)
                  _bird(q.answer.scientificName, q.answer.commonName),
              ],
              results: _results,
              current: _current,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionView(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final question = _question!;
    final answer = question.answer;
    final answered = _picked != null;
    final right = _picked == answer.scientificName;
    final last = _current + 1 == _questions.length;
    final streak = quizStreak(_results);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: BirdySpace.s),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.forkQuizQuestion(_current + 1, _questions.length),
                  style: BirdyText.labelCompact.copyWith(
                    color: c.text2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: BirdySpace.xs),
              // A Wrap, not a Row: at 130 % text on a small phone, the
              // streak pill and the score chip together can be wider than
              // the space left; they wrap to a second line instead of
              // overflowing.
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: BirdySpace.xs,
                  runSpacing: 4,
                  children: [
                    if (streak >= 2)
                      QuizPop(
                        key: ValueKey('streak $streak'),
                        duration: QuizMotion.pill,
                        child: _StreakPill(label: l10n.forkQuizStreak(streak)),
                      ),
                    _ScoreChip(right: _results.where((r) => r).length),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BirdySpace.m),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The mockup's 212 px stage and 136 px cards when they fit;
              // shorter on small phones, so the bottom cards stay in view.
              // Scrolling is the last resort.
              const ideal = _stage + BirdySpace.l + 2 * _tile + 10;
              final room = constraints.maxHeight;
              final stage =
                  room >= ideal ? _stage : (room * 0.4).clamp(128.0, _stage);
              final fitted =
                  room >= ideal
                      ? _tile
                      : ((room - stage - BirdySpace.l - 10) / 2).clamp(
                        96.0,
                        _tile,
                      );
              // Never shorter than a card needs for its name.
              final cardWidth = (constraints.maxWidth - QuizChoiceGrid.gap) / 2;
              var tile = fitted;
              for (final choice in question.choices) {
                final need = QuizChoiceCard.minHeightFor(
                  context,
                  _bird(choice.scientificName, choice.commonName).name,
                  cardWidth,
                );
                if (need > tile) tile = need;
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: _player.playing,
                      builder:
                          (context, playing, _) => QuizStage(
                            bird: _bird(
                              answer.scientificName,
                              answer.commonName,
                            ),
                            state:
                                !answered
                                    ? QuizStageState.listening
                                    : right
                                    ? QuizStageState.right
                                    : QuizStageState.wrong,
                            playing: playing == answer.clipPath,
                            onPlay: _togglePlay,
                            cheer: _current % 4,
                            height: stage,
                          ),
                    ),
                    const SizedBox(height: BirdySpace.l),
                    QuizChoiceGrid(
                      children: [
                        for (var i = 0; i < question.choices.length; i++)
                          KeyedSubtree(
                            key: _choiceKeys[i % _choiceKeys.length],
                            child: _choiceCard(
                              i,
                              question.choices[i],
                              answer,
                              tile,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: BirdySpace.m),
        if (!answered)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BirdySizes.mainAction),
            child: Center(
              child: Text(
                l10n.forkQuizHint,
                textAlign: TextAlign.center,
                style: BirdyText.bodyCompact.copyWith(color: c.text2),
              ),
            ),
          )
        else
          QuizRise(
            key: ValueKey('next $_current'),
            duration: QuizMotion.nextRise,
            delay: QuizMotion.nextDelay,
            child: Pressable(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BirdyRadii.pill),
                  boxShadow: c.ctaGlow,
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.onAccent,
                    minimumSize: const Size(64, BirdySizes.listen),
                    shape: const StadiumBorder(),
                    textStyle: BirdyText.label.copyWith(fontSize: 20),
                    iconSize: 22,
                  ),
                  onPressed: _next,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(AppIcons.arrowForwardRounded),
                  label: Text(last ? l10n.forkQuizFinish : l10n.forkQuizNext),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _choiceCard(
    int index,
    ({String scientificName, String commonName}) choice,
    IndexedDetection answer,
    double tile,
  ) {
    final answered = _picked != null;
    final isAnswer = choice.scientificName == answer.scientificName;
    final state =
        !answered
            ? QuizChoiceState.open
            : isAnswer
            ? QuizChoiceState.right
            : choice.scientificName == _picked
            ? QuizChoiceState.wrong
            : QuizChoiceState.other;
    return QuizChoiceCard(
      key: ValueKey('choice $_current ${choice.scientificName}'),
      bird: _bird(choice.scientificName, choice.commonName),
      height: tile,
      state: state,
      found: isAnswer && _picked == answer.scientificName,
      onTap: () => _answer(index, choice.scientificName),
    );
  }

  Widget _result() {
    final store = ref.read(fineEarStoreProvider);
    return QuizResult(
      birds: [
        for (final q in _questions.take(_results.length))
          _bird(q.answer.scientificName, q.answer.commonName),
      ],
      results: _results,
      badge: fineEarBadge(store.correct()),
      before: fineEarBadge(_startCorrect),
      party: _party,
      onAgain: _start,
      // pop, not maybePop: PopScope turns a back in a round into « intro ».
      onDone: () => Navigator.of(context).pop(),
    );
  }
}

/// « 3 d'affilée ! », Loriot, ringed with its container tint and a small
/// twinkling star disc (Quiz v2 mockup, J6f-e).
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
      decoration: BoxDecoration(
        color: c.oriole,
        borderRadius: BorderRadius.circular(BirdyRadii.pill),
        boxShadow: [BoxShadow(color: c.orioleContainer, spreadRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface1, shape: BoxShape.circle),
            child: QuizLoop(
              period: const Duration(milliseconds: 1600),
              builder:
                  (context, t, child) => Opacity(
                    opacity: quizKeyframes(
                      t,
                      const [0, 0.5, 1],
                      const [0.3, 1, 0.3],
                      QuizMotion.inOut,
                    ),
                    child: child,
                  ),
              child: Icon(AppIcons.quizSpark, size: 13, fill: 1, color: c.oriole),
            ),
          ),
          const SizedBox(width: BirdySpace.xs),
          Flexible(
            child: Text(
              label,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: BirdyText.badge.copyWith(
                height: 1.2,
                color: c.onOriole,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The always-visible score chip: right answers so far (Quiz v2 mockup,
/// J6f-e), Sûr green.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.right});

  final int right;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Semantics(
      label: l10n.forkQuizRightSoFar(right),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
        decoration: BoxDecoration(
          color: c.sure.background,
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.quizCheck, size: 16, color: c.sure.foreground),
            const SizedBox(width: BirdySpace.xs),
            Text(
              '$right',
              style: BirdyText.badge.copyWith(
                color: c.sure.foreground,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
