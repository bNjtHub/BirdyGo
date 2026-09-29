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
import 'quiz_decor.dart';
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

  /// How far the play button reaches past the disc, right and bottom, as a
  /// share of the disc (Quiz v2 mockup).
  static const double _buttonOverhangX = 0.16;
  static const double _buttonOverhangY = 0.09;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    // 112 px on the mockup's 212 px card; smaller on short screens. Leaves
    // room below for the full-width spectrum.
    final disc = (height - 96).clamp(48.0, 112.0);
    return QuizWell(
      highlightRadius: 190,
      highlightCenter: const Alignment(0, -0.16),
      child: Stack(
        children: [
          const Positioned.fill(child: QuizTwinkleField(count: 4, seed: 11)),
          Positioned(
            top: 12,
            left: 12,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: BirdyBrand.oriole,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '?',
                    style: BirdyText.badge.copyWith(
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: BirdyBrand.ink,
                    ),
                  ),
                ),
                const SizedBox(width: BirdySpace.xs),
                Flexible(
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
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 44,
            child: Center(
              child: SizedBox(
                // The disc sits in the middle; the same margin on every side
                // makes room for the play button overlapping its bottom-right
                // (inside the box, so all of it stays tappable). The bubble
                // overlaps the top-right corner (Clip.none: it adds nothing
                // to the card's own layout).
                width: disc + 2 * disc * _buttonOverhangX,
                height: disc + 2 * disc * _buttonOverhangY,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: disc * _buttonOverhangX,
                      top: disc * _buttonOverhangY,
                      width: disc,
                      height: disc,
                      child: QuizBounce(
                        child: Stack(
                          alignment: Alignment.center,
                          fit: StackFit.expand,
                          children: [
                            QuizRing(color: c.accent, running: playing),
                            QuizRing(
                              color: BirdyBrand.oriole,
                              delay: QuizMotion.ringStep,
                              running: playing,
                            ),
                            QuizMysteryDisc(
                              size: disc,
                              silhouette: disc * 92 / 116,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Mockup placement: overlapping the disc's top-right,
                    // tail pointing down toward it.
                    Positioned(
                      top: disc * _buttonOverhangY - 8,
                      left: disc * (_buttonOverhangX + 0.68),
                      child: QuizSpeechBubble(
                        label:
                            playing
                                ? l10n.forkQuizStageBubblePlaying
                                : l10n.forkQuizStageBubbleIdle,
                        tailLeft: 10,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _BigPlayButton(
                        playing: playing,
                        label:
                            playing ? l10n.forkQuizStop : l10n.forkQuizListen,
                        onPressed: onPlay,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 14,
            height: 26,
            child: _StageSpectrum(playing: playing),
          ),
        ],
      ),
    );
  }
}

/// The mockup's single 27-bar spectrum across the bottom of the well,
/// animated only while the clip plays, dimmed at rest.
class _StageSpectrum extends StatelessWidget {
  const _StageSpectrum({required this.playing});

  final bool playing;

  static const _heights = [8, 14, 22, 12, 26, 18, 10, 20, 28, 16, 9, 24, 14];
  static const _colors = [
    BirdyQuizColors.bar1,
    BirdyQuizColors.bar2,
    BirdyQuizColors.bar3,
    BirdyBrand.oriole,
    BirdyQuizColors.bar4,
    BirdyQuizColors.bar2,
  ];
  static const _count = 27;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Opacity(
      opacity: playing ? 1 : 0.4,
      child: Row(
        children: [
          for (var i = 0; i < _count; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Center(
                child: QuizBar(
                  width: 5,
                  height: _heights[i % _heights.length].toDouble(),
                  color: _colors[i % _colors.length],
                  period: Duration(milliseconds: 700 + (i % 5) * 90),
                  delay: Duration(milliseconds: (i * 70) % 600),
                  running: playing,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// 60 dp filled play button overlapping the disc, a wellBottom ring and the
/// Martin-pêcheur glow (Quiz v2 mockup).
class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({
    required this.playing,
    required this.label,
    required this.onPressed,
  });

  static const double size = 60;

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
              border: Border.all(color: BirdyBrand.wellBottom, width: 3),
              boxShadow: c.ctaGlow,
            ),
            child: Material(
              color: BirdyBrand.kingfisher,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(
                    playing ? AppIcons.quizStop : AppIcons.playArrowRounded,
                    size: playing ? size * 0.5 : size * 0.6,
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
    // « Bravo, c'est bien lui : Nom » / « C'était : Nom »: no article built
    // by hand, so no wrong gender.
    final named = bird.name;
    final sentence =
        right ? l10n.forkQuizRevealRight(named) : l10n.forkQuizWrong(named);
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
    if (species != null) {
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
                                    if (!right) ...[
                                      const SizedBox(height: BirdySpace.s),
                                      _EncouragePill(
                                        label: l10n.forkQuizEncourage(
                                          '${cheer % 3}',
                                        ),
                                      ),
                                    ],
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

/// « Réécoute-le, tu le retiendras »: the calm tonal pill under a wrong
/// answer's sentence (Quiz v2 mockup, J6f-e).
class _EncouragePill extends StatelessWidget {
  const _EncouragePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        color: c.tonal,
        borderRadius: BorderRadius.circular(BirdyRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.graphicEqRounded, size: 14, color: c.accentText),
          const SizedBox(width: BirdySpace.xs),
          Flexible(
            child: Text(
              label,
              style: BirdyText.badge.copyWith(
                height: 1.2,
                color: c.accentText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
