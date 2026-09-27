/// « Qui chante ? » (J6e, badge Oreille fine): one of your own recordings,
/// four birds (photo and name in the species language), one right. The
/// answer reveals the bird's photo. A round is up to
/// [GameConfig.quizQuestions] questions; each right answer counts toward
/// the badge.
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
import '../design/widgets/empty_state.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../species_page/species_clip_player.dart';
import 'fine_ear.dart';
import 'fine_ear_quiz_widgets.dart';
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

class _FineEarQuizScreenState extends ConsumerState<FineEarQuizScreen> {
  static const double _maxWidth = 560;

  late final Random _random = widget.random ?? Random();
  late final SpeciesClipPlayer _player = ref.read(speciesClipPlayerProvider);
  Map<String, IndexedDetection>? _clips;
  List<QuizQuestion>? _questions;
  int _current = 0;
  int _right = 0;
  String? _picked;

  /// Oreille fine plumes when the round started.
  int _startTier = 0;

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
      _startRound(clips);
    });
    _playCurrent();
  }

  void _restart() {
    final clips = _clips;
    if (clips == null) return;
    setState(() => _startRound(clips));
    _playCurrent();
  }

  void _startRound(Map<String, IndexedDetection> clips) {
    _questions = drawQuiz(clips, _random);
    _current = 0;
    _right = 0;
    _picked = null;
    _startTier = fineEarBadge(ref.read(fineEarStoreProvider).correct()).tier;
  }

  QuizQuestion? get _question {
    final questions = _questions;
    if (questions == null || _current >= questions.length) return null;
    return questions[_current];
  }

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
      if (right) _right++;
    });
    if (right) {
      _scored = true;
      unawaited(BirdyHaptics.light());
      await ref.read(fineEarStoreProvider).addCorrect();
    }
  }

  void _next() {
    setState(() {
      _current++;
      _picked = null;
    });
    if (_question == null) {
      unawaited(_player.stop());
    } else {
      _playCurrent();
    }
  }

  void _leave() {
    unawaited(_player.stop());
    if (_scored) ref.invalidate(gameProgressProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final questions = _questions;

    final Widget body;
    if (questions == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (questions.isEmpty) {
      body = BirdyEntrance(
        child: BirdyEmptyState(
          icon: AppIcons.headphones,
          title: l10n.forkQuizEmptyTitle,
          body: l10n.forkQuizEmpty,
        ),
      );
    } else if (_question == null) {
      final badge = fineEarBadge(ref.read(fineEarStoreProvider).correct());
      body = QuizResult(
        right: _right,
        total: questions.length,
        badge: badge,
        newTier: badge.tier > _startTier,
        onAgain: _restart,
        onDone: () => Navigator.of(context).maybePop(),
      );
    } else {
      body = _questionView(context, questions.length);
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
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
                  children: [
                    SizedBox(
                      height: BirdySizes.topBar,
                      child: Row(
                        children: [
                          BirdyIconButton(
                            icon: AppIcons.arrowBackRounded,
                            semanticLabel: l10n.tooltipBack,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: BirdySpace.m),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                l10n.forkQuizTitle,
                                style: BirdyText.title.copyWith(color: c.text1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: BirdySpace.l),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How a bird is shown: its name in the species language (the name
  /// stored in the index as a fallback) and its bundled photo, the same
  /// way as the notebook and the sound library.
  QuizBird _bird(
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

  Widget _questionView(BuildContext context, int total) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final question = _question!;
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final locale = ref.watch(effectiveSpeciesLocaleProvider);
    final answer = question.answer;
    final answered = _picked != null;
    final right = _picked == answer.scientificName;
    final last = _current + 1 == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.forkQuizQuestion(_current + 1, total),
          style: BirdyText.label.copyWith(color: c.text2),
        ),
        const SizedBox(height: BirdySpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
          child: LinearProgressIndicator(
            value: (_current + (answered ? 1 : 0)) / total,
            minHeight: 4,
            color: c.accent,
            backgroundColor: c.line,
          ),
        ),
        const SizedBox(height: BirdySpace.l),
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
                          taxonomy,
                          locale,
                          answer.scientificName,
                          answer.commonName,
                        ),
                        revealed: answered,
                        right: right,
                        playing: playing == answer.clipPath,
                        onPlay: _togglePlay,
                      ),
                ),
                const SizedBox(height: BirdySpace.l),
                for (final choice in question.choices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: BirdySpace.s),
                    child: QuizChoiceCard(
                      bird: _bird(
                        taxonomy,
                        locale,
                        choice.scientificName,
                        choice.commonName,
                      ),
                      state:
                          !answered
                              ? QuizChoiceState.open
                              : choice.scientificName == answer.scientificName
                              ? QuizChoiceState.right
                              : choice.scientificName == _picked
                              ? QuizChoiceState.wrong
                              : QuizChoiceState.other,
                      onTap: () => _answer(choice.scientificName),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (answered) ...[
          const SizedBox(height: BirdySpace.s),
          BirdyEntrance(
            child: Pressable(
              child: FilledButton(
                style: BirdyButtonStyles.primary(context),
                onPressed: _next,
                child: Text(last ? l10n.forkQuizFinish : l10n.forkQuizNext),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
