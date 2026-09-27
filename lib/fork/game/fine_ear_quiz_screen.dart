/// « Qui chante ? » (J6e, Quiz v2, badge Oreille fine). An intro, then up
/// to [GameConfig.quizQuestions] of your own recordings, each with four
/// birds (photo and name in the species language), one right; a trail of
/// stones follows the round. The answer reveals the bird. Each right answer
/// counts toward the badge; the round ends on stars, the score and the
/// birds heard.
library;

import 'dart:async';
import 'dart:math';

import 'package:birdnet_live/l10n/app_localizations.dart';
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
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../species_page/species_clip_player.dart';
import 'fine_ear.dart';
import 'fine_ear_quiz_widgets.dart';
import 'game_config.dart';
import 'game_loader.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
    setState(() {
      _questions = drawQuiz(clips, _random);
      _phase = _Phase.question;
      _current = 0;
      _picked = null;
      _results.clear();
      _startCorrect = ref.read(fineEarStoreProvider).correct();
    });
    _playCurrent();
  }

  void _toIntro() {
    unawaited(_player.stop());
    setState(() {
      _phase = _Phase.intro;
      _picked = null;
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

  Future<void> _answer(String scientificName) async {
    final question = _question;
    if (question == null || _picked != null) return;
    final right = scientificName == question.answer.scientificName;
    setState(() {
      _picked = scientificName;
      _results.add(right);
    });
    if (right) {
      _scored = true;
      unawaited(BirdyHaptics.light());
      await ref.read(fineEarStoreProvider).addCorrect();
    }
  }

  void _next() {
    if (_current + 1 >= _questions.length) {
      unawaited(_player.stop());
      setState(() {
        _phase = _Phase.result;
        _picked = null;
      });
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
  /// stored in the index as a fallback) and its bundled photo, the same
  /// way as the notebook and the sound library.
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
          header = SizedBox(
            height: BirdySizes.target,
            child: Row(
              children: [
                BirdyIconButton(
                  icon: AppIcons.arrowBackRounded,
                  semanticLabel: l10n.tooltipBack,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
          );
          body = _intro();
        case _Phase.question:
          header = _questionBar(context);
          body = _questionView(context);
        case _Phase.result:
          header = _titleBar(context, onBack: _toIntro);
          body = _result();
      }
    }

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
          child: Center(
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

  Widget _intro() {
    final clips = _clips!;
    final correct = ref.watch(fineEarStoreProvider).correct();
    return Padding(
      padding: const EdgeInsets.only(top: BirdySpace.l),
      child: QuizIntro(
        birds: [
          for (final q in _questions.take(4))
            _bird(q.answer.scientificName, q.answer.commonName),
        ],
        questions: _questions.length,
        choices: GameConfig.quizChoices,
        birdCount: clips.length,
        badge: fineEarBadge(correct),
        onStart: _start,
      ),
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
            icon: AppIcons.close,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Small phones get a shorter stage and shorter tiles; the page
        // scrolls under the pinned action.
        final stage = (constraints.maxHeight * 0.4).clamp(200.0, 244.0);
        final tile = (constraints.maxHeight * 0.24).clamp(112.0, 148.0);
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
                  if (streak >= 2)
                    BirdyEntrance(
                      key: ValueKey('streak $streak'),
                      offset: Offset.zero,
                      fromScale: BirdyMotion.appearScale,
                      child: BirdyPill(
                        label: l10n.forkQuizStreak(streak),
                        foreground: c.onOriole,
                        background: c.oriole,
                        leading: Icon(
                          AppIcons.sparkle,
                          size: 14,
                          color: c.onOriole,
                          fill: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: BirdySpace.m),
            Expanded(
              child: SingleChildScrollView(
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
                            minHeight: stage,
                          ),
                    ),
                    const SizedBox(height: BirdySpace.l),
                    QuizChoiceGrid(
                      children: [
                        for (final choice in question.choices)
                          QuizChoiceCard(
                            bird: _bird(
                              choice.scientificName,
                              choice.commonName,
                            ),
                            minHeight: tile,
                            state:
                                !answered
                                    ? QuizChoiceState.open
                                    : choice.scientificName ==
                                        answer.scientificName
                                    ? QuizChoiceState.right
                                    : choice.scientificName == _picked
                                    ? QuizChoiceState.wrong
                                    : QuizChoiceState.other,
                            onTap: () => _answer(choice.scientificName),
                          ),
                      ],
                    ),
                    const SizedBox(height: BirdySpace.s),
                  ],
                ),
              ),
            ),
            const SizedBox(height: BirdySpace.s),
            if (!answered)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: BirdySizes.mainAction,
                ),
                child: Center(
                  child: Text(
                    l10n.forkQuizHint,
                    textAlign: TextAlign.center,
                    style: BirdyText.bodyCompact.copyWith(color: c.text2),
                  ),
                ),
              )
            else
              BirdyEntrance(
                child: Pressable(
                  child: FilledButton.icon(
                    style: BirdyButtonStyles.primary(context),
                    onPressed: _next,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(AppIcons.arrowForwardRounded),
                    label: Text(last ? l10n.forkQuizFinish : l10n.forkQuizNext),
                  ),
                ),
              ),
          ],
        );
      },
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
      onAgain: _start,
      // pop, not maybePop: PopScope turns a back in a round into « intro ».
      onDone: () => Navigator.of(context).pop(),
    );
  }
}
