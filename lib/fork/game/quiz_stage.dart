/// The stage of « Qui chante ? » (J6e, Quiz v2). Listening: the dark well,
/// the floating mystery bird and the play button between two equalizers
/// that move only while the clip plays. Right: the bird's light tint with
/// turning rays, the bird popping in, a cheer and « C'est bien le merle
/// noir ». Wrong: a calm white card, « Presque ! » and the bird's name.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/pressable.dart';
import '../species_photo/photo_credit.dart';
import '../species_photo/photo_credit_sheet.dart';
import 'fine_ear_quiz_widgets.dart';
import 'french_article.dart';
import 'quiz_fx.dart';

enum QuizStageState { listening, right, wrong }

class QuizStage extends StatelessWidget {
  const QuizStage({
    super.key,
    required this.bird,
    required this.state,
    required this.playing,
    required this.onPlay,
    required this.cheer,
    this.height = defaultHeight,
  });

  static const double defaultHeight = 212;

  final QuizBird bird;
  final QuizStageState state;
  final bool playing;
  final VoidCallback onPlay;

  /// Which cheer a right answer gets (it varies from one question to the
  /// next).
  final int cheer;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: switch (state) {
        QuizStageState.listening => _ListeningCard(
          key: ValueKey('mystery ${bird.scientificName}'),
          playing: playing,
          onPlay: onPlay,
          height: height,
        ),
        QuizStageState.right => QuizFade(
          key: ValueKey('right ${bird.scientificName}'),
          duration: QuizMotion.revealFade,
          curve: QuizMotion.out,
          child: _RevealCard(
            bird: bird,
            right: true,
            playing: playing,
            onPlay: onPlay,
            cheer: cheer,
          ),
        ),
        QuizStageState.wrong => QuizFade(
          key: ValueKey('wrong ${bird.scientificName}'),
          duration: QuizMotion.revealFade,
          curve: QuizMotion.out,
          child: _RevealCard(
            bird: bird,
            right: false,
            playing: playing,
            onPlay: onPlay,
            cheer: cheer,
          ),
        ),
      },
    );
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({
    super.key,
    required this.playing,
    required this.onPlay,
    required this.height,
  });

  final bool playing;
  final VoidCallback onPlay;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 116 px on the mockup's 212 px card; smaller on short screens.
    final disc = (height - 96).clamp(48.0, 116.0);
    return QuizWell(
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Text(
              l10n.forkQuizMystery,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BirdyText.badge.copyWith(
                height: 1.2,
                color: BirdyColors.dark.text2,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuizFloat(
                  child: QuizMysteryDisc(
                    size: disc,
                    silhouette: disc * 92 / 116,
                  ),
                ),
                SizedBox(height: height >= 200 ? 12 : 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QuizBars(
                      key: const ValueKey('quiz-bars-left'),
                      heights: const [10, 20, 26],
                      colors: BirdyQuizColors.barsLeft,
                      delays: const [
                        Duration(milliseconds: 240),
                        Duration(milliseconds: 120),
                        Duration.zero,
                      ],
                      running: playing,
                      dimmed: !playing,
                    ),
                    const SizedBox(width: 14),
                    _BigPlayButton(
                      playing: playing,
                      label: playing ? l10n.forkQuizStop : l10n.forkQuizListen,
                      onPressed: onPlay,
                    ),
                    const SizedBox(width: 14),
                    QuizBars(
                      key: const ValueKey('quiz-bars-right'),
                      heights: const [26, 18, 10],
                      colors: BirdyQuizColors.barsRight,
                      delays: const [
                        Duration(milliseconds: 60),
                        Duration(milliseconds: 180),
                        Duration(milliseconds: 300),
                      ],
                      running: playing,
                      dimmed: !playing,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 64 dp filled play button of the well, with the Martin-pêcheur glow.
class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({
    required this.playing,
    required this.label,
    required this.onPressed,
  });

  final bool playing;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Pressable(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: c.ctaGlow,
            ),
            child: Material(
              color: BirdyBrand.kingfisher,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: BirdySizes.liveControl,
                  child: Icon(
                    playing ? AppIcons.quizStop : AppIcons.playArrowRounded,
                    size: playing ? 30 : 36,
                    fill: 1,
                    color: BirdyBrand.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.bird,
    required this.right,
    required this.playing,
    required this.onPlay,
    required this.cheer,
  });

  final QuizBird bird;
  final bool right;
  final bool playing;
  final VoidCallback onPlay;
  final int cheer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = bird.tint;
    final heading = right ? l10n.forkQuizCheer('$cheer') : l10n.forkQuizAlmost;
    // « C'est bien le merle noir »: the article when the name's gender is
    // known, « C'est bien : Nom » otherwise (french_article.dart).
    final withArticle =
        Localizations.localeOf(context).languageCode == 'fr'
            ? frenchWithArticle(bird.name)
            : null;
    final named = withArticle ?? bird.name;
    final sentence =
        withArticle != null
            ? (right
                ? l10n.forkQuizRightArticle(withArticle)
                : l10n.forkQuizWrongArticle(withArticle))
            : (right
                ? l10n.forkQuizRightName(bird.name)
                : l10n.forkQuizWrong(bird.name));
    final at = sentence.indexOf(named);
    final span = TextSpan(
      style: BirdyText.body.copyWith(height: 1.3, color: c.text1),
      children:
          at < 0
              ? [TextSpan(text: sentence)]
              : [
                TextSpan(text: sentence.substring(0, at)),
                TextSpan(
                  text: named,
                  style: BirdyText.species.copyWith(
                    height: 1.3,
                    color: c.text1,
                  ),
                ),
                TextSpan(text: sentence.substring(at + named.length)),
              ],
    );

    Widget art = QuizBirdArt(
      bird: bird,
      size: right ? 132 : 116,
      iconSize: right ? 116 : 100,
    );
    final species = bird.species;
    if (bird.icon == null && species != null) {
      // A photo: credit and license at a tap (DESIGN.md « Photos »).
      art = Semantics(
        button: true,
        label: l10n.forkPhotoCredit,
        excludeSemantics: true,
        child: GestureDetector(
          onTap:
              () => showPhotoCreditSheet(
                context,
                PhotoCredit.fromSpecies(species),
              ),
          child: art,
        ),
      );
    }
    art =
        right
            ? QuizPop(duration: QuizMotion.birdPop, child: art)
            : QuizRise(child: art);

    // The right reveal's texts rise after the bird; the wrong one is calm.
    Widget rise(Duration delay, Widget child) =>
        right ? QuizRise(delay: delay, child: child) : child;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: right ? tint.cardBackground(c.brightness) : c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        border: right ? null : Border.all(color: c.lineOpaque, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              if (right)
                Positioned(
                  left: w / 2 - 260,
                  top: h * 0.42 - 260,
                  child: QuizRays(color: tint.accent.withValues(alpha: 0.12)),
                ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BirdySpace.l,
                    vertical: BirdySpace.s,
                  ),
                  // The mockup's sizes; the whole reveal scales down when a
                  // short stage or large text leaves too little room.
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: w - 2 * BirdySpace.l,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            art,
                            SizedBox(height: right ? 8 : 10),
                            Semantics(
                              container: true,
                              liveRegion: true,
                              label: '$heading $sentence',
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    rise(
                                      QuizMotion.cheerDelay,
                                      Text(
                                        heading,
                                        textAlign: TextAlign.center,
                                        style: (right
                                                ? BirdyText.display
                                                : BirdyText.title)
                                            .copyWith(color: c.text1),
                                      ),
                                    ),
                                    const SizedBox(height: BirdySpace.xs),
                                    rise(
                                      QuizMotion.sentenceDelay,
                                      QuizBalancedText(span, maxWidth: 250),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: BirdySpace.m,
                right: BirdySpace.m,
                child: _ReplayButton(
                  playing: playing,
                  onTint: right,
                  onPressed: onPlay,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Réécouter, 48 dp, top right of the reveal (never over the text).
class _ReplayButton extends StatelessWidget {
  const _ReplayButton({
    required this.playing,
    required this.onTint,
    required this.onPressed,
  });

  final bool playing;
  final bool onTint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final label = playing ? l10n.forkQuizStop : l10n.forkQuizListenAgain;
    final background =
        !onTint
            ? c.surface1
            : c.isDark
            ? c.surface1.withValues(alpha: 0.6)
            : BirdyQuizColors.replayOnTint;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Pressable(
          child: Material(
            color: background,
            shape: CircleBorder(
              side: BorderSide(color: c.accentText, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: BirdySizes.target,
                child: Icon(
                  playing ? AppIcons.quizStop : AppIcons.playArrowRounded,
                  size: 28,
                  fill: 1,
                  color: c.accentText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
