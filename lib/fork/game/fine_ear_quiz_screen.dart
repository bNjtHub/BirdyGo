/// « Qui chante ? » (J6e, badge Oreille fine): one of your own recordings,
/// four names, one right. A round is up to [GameConfig.quizQuestions]
/// questions; each right answer counts toward the badge.
library;

import 'dart:async';
import 'dart:math';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/pressable.dart';
import '../species_page/species_clip_player.dart';
import 'fine_ear.dart';
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
      _current = 0;
      _right = 0;
      _picked = null;
    });
    _playCurrent();
  }

  void _restart() {
    final clips = _clips;
    if (clips == null) return;
    setState(() {
      _questions = drawQuiz(clips, _random);
      _current = 0;
      _right = 0;
      _picked = null;
    });
    _playCurrent();
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
      body = BirdyEmptyState(
        icon: AppIcons.headphones,
        title: l10n.forkQuizEmptyTitle,
        body: l10n.forkQuizEmpty,
      );
    } else if (_question == null) {
      body = _Result(
        right: _right,
        total: questions.length,
        onAgain: _restart,
        onDone: () => Navigator.of(context).maybePop(),
      );
    } else {
      body = _QuestionView(
        question: _question!,
        number: _current + 1,
        total: questions.length,
        picked: _picked,
        player: _player,
        onPlay: _togglePlay,
        onAnswer: _answer,
        onNext: _next,
        last: _current + 1 == questions.length,
      );
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
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.number,
    required this.total,
    required this.picked,
    required this.player,
    required this.onPlay,
    required this.onAnswer,
    required this.onNext,
    required this.last,
  });

  final QuizQuestion question;
  final int number;
  final int total;
  final String? picked;
  final SpeciesClipPlayer player;
  final VoidCallback onPlay;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final answered = picked != null;
    final right = picked == question.answer.scientificName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.forkQuizQuestion(number, total),
          style: BirdyText.label.copyWith(color: c.text2),
        ),
        const SizedBox(height: BirdySpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
          child: LinearProgressIndicator(
            value: (number - 1 + (answered ? 1 : 0)) / total,
            minHeight: 4,
            color: c.accent,
            backgroundColor: c.line,
          ),
        ),
        const SizedBox(height: BirdySpace.xxl),
        Center(
          child: ValueListenableBuilder<String?>(
            valueListenable: player.playing,
            builder: (context, playing, _) {
              final isPlaying = playing == question.answer.clipPath;
              return Transform.scale(
                scale: 1.5,
                child: ClipPlayButton(
                  state: isPlaying ? ClipPlayState.playing : ClipPlayState.idle,
                  semanticLabel:
                      isPlaying ? l10n.forkQuizStop : l10n.forkQuizListen,
                  onPressed: onPlay,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: BirdySpace.xxl),
        Expanded(
          child: ListView(
            children: [
              for (final choice in question.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: BirdySpace.s),
                  child: _Choice(
                    label: choice.commonName,
                    state:
                        !answered
                            ? _ChoiceState.open
                            : choice.scientificName ==
                                question.answer.scientificName
                            ? _ChoiceState.right
                            : choice.scientificName == picked
                            ? _ChoiceState.wrong
                            : _ChoiceState.other,
                    onTap: () => onAnswer(choice.scientificName),
                  ),
                ),
              AnimatedSwitcher(
                duration: BirdyMotion.enter,
                child:
                    answered
                        ? Padding(
                          key: ValueKey(picked),
                          padding: const EdgeInsets.only(top: BirdySpace.s),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              right
                                  ? l10n.forkQuizRight
                                  : l10n.forkQuizWrong(
                                    question.answer.commonName,
                                  ),
                              textAlign: TextAlign.center,
                              style: BirdyText.label.copyWith(
                                color: right ? c.sure.foreground : c.text1,
                              ),
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        if (answered)
          Pressable(
            child: FilledButton(
              style: BirdyButtonStyles.primary(context),
              onPressed: onNext,
              child: Text(last ? l10n.forkQuizFinish : l10n.forkQuizNext),
            ),
          ),
      ],
    );
  }
}

enum _ChoiceState { open, right, wrong, other }

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.state, this.onTap});

  final String label;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final (background, foreground, border) = switch (state) {
      _ChoiceState.open => (c.surface1, c.text1, c.border),
      _ChoiceState.right => (
        c.sure.background,
        c.sure.foreground,
        c.sure.foreground,
      ),
      _ChoiceState.wrong => (c.lineOpaque, c.text1, c.borderStrong),
      _ChoiceState.other => (c.surface1, c.text2, c.line),
    };
    final icon = switch (state) {
      _ChoiceState.right => AppIcons.check,
      _ChoiceState.wrong => AppIcons.close,
      _ => null,
    };
    return Semantics(
      button: state == _ChoiceState.open,
      selected: state == _ChoiceState.right || state == _ChoiceState.wrong,
      child: Pressable(
        enabled: state == _ChoiceState.open,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: state == _ChoiceState.open ? onTap : null,
            borderRadius: BorderRadius.circular(BirdyRadii.card),
            child: AnimatedContainer(
              duration: BirdyMotion.enter,
              curve: BirdyMotion.standard,
              constraints: const BoxConstraints(
                minHeight: BirdySizes.mainAction,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.l,
                vertical: BirdySpace.m,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(BirdyRadii.card),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: BirdyText.species.copyWith(color: foreground),
                    ),
                  ),
                  if (icon != null) Icon(icon, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.right,
    required this.total,
    required this.onAgain,
    required this.onDone,
  });

  final int right;
  final int total;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: BirdyEmptyState.fullDisc,
                height: BirdyEmptyState.fullDisc,
                decoration: BoxDecoration(
                  color: c.tonal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.headphones,
                  size: BirdyEmptyState.fullIcon,
                  color: c.accentText,
                ),
              ),
            ),
          ),
          const SizedBox(height: BirdySpace.l),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.forkQuizScore(right, total),
              textAlign: TextAlign.center,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
          const SizedBox(height: BirdySpace.xxl),
          Pressable(
            child: FilledButton(
              style: BirdyButtonStyles.primary(context),
              onPressed: onAgain,
              child: Text(l10n.forkQuizAgain),
            ),
          ),
          const SizedBox(height: BirdySpace.s),
          Pressable(
            child: FilledButton(
              style: BirdyButtonStyles.secondary(context),
              onPressed: onDone,
              child: Text(l10n.forkQuizDone),
            ),
          ),
        ],
      ),
    );
  }
}
