/// The stage of « Qui chante ? » (J6e, Quiz v2). Listening: the dark well,
/// the floating mystery bird and the play button between two equalizers
/// that move only while the clip plays. Right: the bird's light tint with
/// turning rays, the bird popping in, a cheer and « C'est bien le merle
/// noir ». Wrong: a calm white card, « Presque ! » and the bird's name.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    // 112 px on the mockup's 212 px card; smaller on short screens. Leaves
    // room below for the full-width spectrum.
    final geometry = _StageGeometry(height);
    final disc = geometry.disc;
    const overhangX = _StageGeometry.overhangX;
    const overhangY = _StageGeometry.overhangY;
    return QuizWell(
      highlightRadius: 190,
      highlightCenter: const Alignment(0, -0.16),
      child: Stack(
        children: [
          const Positioned.fill(child: QuizTwinkleField(count: 4, seed: 11)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: BirdyGlyph.disc44 + 2 * BirdySpace.s,
            child: Center(
              child: SizedBox(
                // The disc sits in the middle; the same margin on every side
                // makes room for the play button overlapping its bottom-right
                // (inside the box, so all of it stays tappable). The bubble
                // overlaps the top-right corner (Clip.none: it adds nothing
                // to the card's own layout).
                width: disc + 2 * disc * overhangX,
                height: disc + 2 * disc * overhangY,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: disc * overhangX,
                      top: disc * overhangY,
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
                      top: disc * overhangY - 8,
                      left: disc * (overhangX + 0.68),
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
            left: BirdySpace.xl,
            right: BirdySpace.xl,
            bottom: BirdySpace.comfy,
            height: BirdyGlyph.x4l,
            child: _StageSpectrum(playing: playing),
          ),
        ],
      ),
    );
  }
}

/// Where the stage puts its things, shared by the listening and the reveal
/// cards so the play button never moves between the two: the disc (or the
/// bird) is centered above the bottom band, the button overlaps its
/// bottom-right corner.
class _StageGeometry {
  const _StageGeometry(this.height);

  /// How far the play button reaches past the disc, right and bottom, as a
  /// share of the disc (Quiz v2 mockup).
  static const double overhangX = 0.16;
  static const double overhangY = 0.09;

  final double height;

  /// 116 px on the 212 px card (the top label is gone, so the disc grew); smaller on short screens.
  double get disc => (height - 90).clamp(48.0, 116.0);

  double get boxWidth => disc + 2 * disc * overhangX;
  double get boxHeight => disc + 2 * disc * overhangY;

  /// Vertical center of the disc.
  double get centerY => (height - BirdyGlyph.disc44) / 2 - BirdySpace.s;

  /// Bottom edge of the box holding the disc and the button.
  double get boxBottom => centerY + boxHeight / 2;

  /// Play button offsets from the card's right and bottom edges.
  double right(double width) => (width - boxWidth) / 2;
  double get bottom => height - boxBottom;
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
  Widget build(BuildContext context) => RepaintBoundary(
    child: ExcludeSemantics(
    child: Opacity(
      opacity: playing ? 1 : 0.4,
      child: Row(
        children: [
          for (var i = 0; i < _count; i++) ...[
            if (i > 0) const SizedBox(width: BirdySpace.thin),
            Expanded(
              child: Center(
                child: QuizBar(
                  width: BirdySpace.tight,
                  height: _heights[i % _heights.length].toDouble(),
                  color: _colors[i % _colors.length],
                  period: BirdyMotion.quizBarPeriod(i),
                  delay: BirdyMotion.quizBarDelay(i),
                  running: playing,
                ),
              ),
            ),
          ],
        ],
      ),
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
    this.ring = BirdyBrand.wellBottom,
  });

  static const double size = 60;

  /// Color of the ring cut around the button: the card behind it.
  final Color ring;

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
              border: Border.all(color: ring, width: BirdyStroke.thick),
              boxShadow: c.ctaGlow,
            ),
            child: Material(
              color: c.accent,
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

    // The bird takes the disc's place and the play button stays exactly
    // where it was during the question (same anchor, same size).
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final geometry = _StageGeometry(h);
        final artSize = geometry.disc * (right ? 0.96 : 0.86);
        Widget art = QuizBirdArt(
          bird: bird,
          size: artSize,
          iconSize: artSize * 0.86,
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

        final ringColor =
            right ? tint.cardBackground(c.brightness) : c.surface1;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: right ? tint.cardBackground(c.brightness) : c.surface1,
            borderRadius: BorderRadius.circular(BirdyRadii.hero),
          ),
          // Painted over, not around: the border must not push the content
          // (the play button stays where it was during the question).
          foregroundDecoration:
              right
                  ? null
                  : BoxDecoration(
                    borderRadius: BorderRadius.circular(BirdyRadii.hero),
                    border: Border.all(
                      color: c.lineOpaque,
                      width: BirdyStroke.thin,
                    ),
                  ),
          child: Stack(
            children: [
              if (right)
                Positioned(
                  left: w / 2 - 260,
                  top: geometry.centerY - 260,
                  child: QuizRays(color: tint.accent.withValues(alpha: 0.12)),
                ),
              Positioned(
                left: (w - artSize) / 2,
                top: geometry.centerY - artSize / 2,
                child: art,
              ),
              if (!right && h >= _pillMinHeight)
                Positioned(
                  top: BirdySpace.s,
                  left: BirdySpace.l,
                  right: BirdySpace.l,
                  child: Center(
                    child: _EncouragePill(
                      label: l10n.forkQuizEncourage('${cheer % 3}'),
                    ),
                  ),
                ),
              Positioned(
                left: BirdySpace.l,
                right: BirdySpace.l,
                top: geometry.boxBottom + BirdySpace.xxs,
                bottom: BirdySpace.xxs,
                // The mockup's sizes; the texts scale down when a short
                // stage or large text leaves too little room.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: w - 2 * BirdySpace.l,
                    child: Semantics(
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
                  ),
                ),
              ),
              Positioned(
                right: geometry.right(w),
                bottom: geometry.bottom,
                child: _BigPlayButton(
                  playing: playing,
                  label: playing ? l10n.forkQuizStop : l10n.forkQuizListen,
                  onPressed: onPlay,
                  ring: ringColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Below this stage height the encouragement pill would touch the bird.
  static const double _pillMinHeight = 190;
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
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.s,
        BirdySpace.xs,
        BirdySpace.m,
        BirdySpace.xs,
      ),
      decoration: BoxDecoration(
        color: c.tonal,
        borderRadius: BorderRadius.circular(BirdyRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.graphicEqRounded,
            size: BirdyGlyph.s,
            color: c.accentText,
          ),
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
