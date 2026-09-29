/// The trail of stones of « Qui chante ? » (J6e, Quiz v2): one step per
/// question on a 3 px line. A found bird leaves its icon, a missed one a
/// small cross, the current step shows its number with a pulsing halo, the
/// steps to come are dots ringed with the page color so the line never
/// crosses them.
library;

import 'dart:math' as math;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'fine_ear_quiz_widgets.dart';
import 'quiz_fx.dart';

enum QuizStoneState { upcoming, current, right, wrong }

class QuizTrail extends StatelessWidget {
  const QuizTrail({
    super.key,
    required this.birds,
    required this.results,
    required this.current,
  });

  /// The bird of each question, in order.
  final List<QuizBird> birds;

  /// Answers given so far, in order.
  final List<bool> results;

  /// Question on screen.
  final int current;

  /// Fixed width of a step, and the trail's height.
  static const double slot = 24;
  static const double height = 32;
  static const double line = 3;

  QuizStoneState stateOf(int i) {
    if (i < results.length) {
      return results[i] ? QuizStoneState.right : QuizStoneState.wrong;
    }
    return i == current ? QuizStoneState.current : QuizStoneState.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final total = birds.length;
    final right = results.where((r) => r).length;
    return Semantics(
      label: results.isEmpty ? null : l10n.forkQuizScore(right, results.length),
      container: true,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Steps keep 24 px unless ten of them don't fit.
            final step = total == 0 ? slot : math.min(slot, width / total);
            final k = step / slot;
            final span = width - step;
            double centerOf(int i) =>
                step / 2 + (total < 2 ? 0 : span * i / (total - 1));
            final done = math.min(results.length, total - 1);
            final fill = total < 2 ? 0.0 : span * done / (total - 1);
            const top = (height - line) / 2;
            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    key: const ValueKey('quiz-trail-line'),
                    left: step / 2,
                    right: step / 2,
                    top: top,
                    height: line,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.lineOpaque,
                        borderRadius: BorderRadius.circular(BirdyRadii.pill),
                      ),
                    ),
                  ),
                  Positioned(
                    left: step / 2,
                    top: top,
                    height: line,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: fill),
                      duration: QuizMotion.trail,
                      curve: QuizMotion.ease,
                      builder:
                          (context, w, _) => Container(
                            key: const ValueKey('quiz-trail-fill'),
                            width: w,
                            height: line,
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(
                                BirdyRadii.pill,
                              ),
                            ),
                          ),
                    ),
                  ),
                  for (var i = 0; i < total; i++)
                    Positioned(
                      key: ValueKey('quiz-stone-$i'),
                      left: centerOf(i) - step / 2,
                      top: 0,
                      width: step,
                      height: height,
                      child: OverflowBox(
                        minWidth: 0,
                        minHeight: 0,
                        maxWidth: 30 * k + 20,
                        maxHeight: height + 20,
                        child: QuizStone(
                          key: ValueKey('stone $i ${stateOf(i).name}'),
                          state: stateOf(i),
                          number: i + 1,
                          bird: birds[i],
                          scale: k,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One step of the trail.
class QuizStone extends StatelessWidget {
  const QuizStone({
    super.key,
    required this.state,
    required this.number,
    required this.bird,
    this.scale = 1,
  });

  final QuizStoneState state;
  final int number;
  final QuizBird bird;
  final double scale;

  /// Diameters of each state (before [scale]).
  static const double upcomingSize = 12;
  static const double ring = 3;
  static const double currentSize = 30;
  static const double rightSize = 26;
  static const double wrongSize = 20;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    switch (state) {
      case QuizStoneState.upcoming:
        final size = upcomingSize * scale;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.border,
            // The page color around the dot: the line stops short of it.
            boxShadow: [
              BoxShadow(color: c.background, spreadRadius: ring * scale),
            ],
          ),
        );
      case QuizStoneState.current:
        final size = currentSize * scale;
        return QuizPulse(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface1,
              border: Border.all(color: c.accent, width: BirdyStroke.thick * scale),
            ),
            child: Text(
              '$number',
              textScaler: TextScaler.noScaling,
              style: BirdyText.badge.copyWith(
                fontSize: BirdyText.captionSize * scale,
                color: c.accentText,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      case QuizStoneState.right:
        final size = rightSize * scale;
        final tint = bird.tint;
        return QuizPop(
          duration: QuizMotion.stoneRight,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.cardBackground(c.brightness),
              border: Border.all(color: tint.accent, width: BirdyStroke.regular * scale),
            ),
            child: QuizBirdArt(
              bird: bird,
              size: size - 4 * scale,
              iconSize: 20 * scale,
              background: Colors.transparent,
            ),
          ),
        );
      case QuizStoneState.wrong:
        final size = wrongSize * scale;
        return QuizPop(
          duration: QuizMotion.stoneWrong,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface1,
              border: Border.all(color: c.border, width: BirdyStroke.regular * scale),
            ),
            child: Icon(AppIcons.quizClose, size: BirdyGlyph.s * scale, color: c.text2),
          ),
        );
    }
  }
}
