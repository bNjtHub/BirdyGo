/// The intro of « Qui chante ? » (J6e, Quiz v2): the well with four of the
/// player's birds floating around the mystery one, the title, the round in
/// one strip (songs, choices, birds), the Oreille fine progress and
/// « C'est parti ! ». The sound switch sits in the header.
library;

import 'dart:math' as math;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/pressable.dart';
import 'fine_ear_quiz_widgets.dart';
import 'game_progress.dart';
import 'game_text.dart';
import 'game_widgets.dart';
import 'quiz_decor.dart';
import 'quiz_fx.dart';

class QuizIntro extends StatelessWidget {
  const QuizIntro({
    super.key,
    required this.birds,
    required this.questions,
    required this.choices,
    required this.badge,
    required this.onStart,
  });

  /// Up to four of the player's birds, around the mystery one.
  final List<QuizBird> birds;

  final int questions;
  final int choices;

  /// Oreille fine now.
  final BadgeProgress badge;

  final VoidCallback onStart;

  static const double heroMax = 290;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return QuizFade(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The illustrated zone gives room first: 210 when the phone is tall
          // enough, down to a floor; then the gaps tighten from 12 to 8 and
          // the zone goes down to its minimum. The scroll below is the last
          // resort, for a very short screen or a huge font.
          final k = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
          // The go button under the scroll is 72 whatever the font scale.
          final fixed = BirdySizes.quizIntroRest * k + BirdySizes.listen;
          double room(double gap) =>
              constraints.maxHeight -
              (fixed + 4 * gap + BirdySpace.s + BirdySizes.quizIntroSlack);
          var gap = BirdySpace.m;
          double hero =
              room(gap)
                  .clamp(
                    BirdySizes.quizIntroHeroFloor,
                    BirdySizes.quizIntroHero,
                  )
                  .toDouble();
          if (room(gap) < BirdySizes.quizIntroHeroFloor) {
            gap = BirdySpace.s;
            hero =
                room(gap)
                    .clamp(
                      // A big font makes the speech bubble taller: keep the floor.
                      k > 1.15
                          ? BirdySizes.quizIntroHeroFloor
                          : BirdySizes.quizIntroHeroMin,
                      BirdySizes.quizIntroHeroFloor,
                    )
                    .toDouble();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: hero, child: _IntroWell(birds: birds)),
                      SizedBox(height: gap),
                      Semantics(
                        header: true,
                        label: l10n.forkQuizTitle,
                        excludeSemantics: true,
                        child: Text.rich(
                          TextSpan(
                            style: BirdyText.display.copyWith(color: c.text1),
                            children: [
                              TextSpan(text: l10n.forkQuizTitleWord),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: SizedBox(width: 2),
                              ),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                baseline: TextBaseline.alphabetic,
                                child: _QuizTitleMark(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: BirdySpace.s),
                      Text(
                        l10n.forkQuizIntro,
                        style: BirdyText.body.copyWith(color: c.text1),
                      ),
                      SizedBox(height: gap),
                      _StepCards(questions: questions, choices: choices),
                      SizedBox(height: gap),
                      _IntroBadgeCard(badge: badge),
                      SizedBox(height: gap),
                    ],
                  ),
                ),
              ),
              _GoButton(label: l10n.forkQuizGo, onPressed: onStart),
            ],
          );
        },
      ),
    );
  }
}

class _IntroWell extends StatelessWidget {
  const _IntroWell({required this.birds});

  final List<QuizBird> birds;

  /// Tilt of each orbit bird, mockup order.
  static const _tilts = [-8.0, 6.0, 5.0, -6.0];

  @override
  Widget build(BuildContext context) {
    return QuizWell(
      highlightRadius: 240,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final k = (h / QuizIntro.heroMax).clamp(0.6, 1.0);
          final orbit = 58 * k;
          // Mockup positions on a 350 × 290 card.
          final spots =
              <({double? left, double? right, double? top, double? bottom})>[
                (left: 22, right: null, top: 24 * k, bottom: null),
                (left: null, right: 2, top: 36 * k, bottom: null),
                (left: 30, right: null, top: null, bottom: 30 * k),
                (left: null, right: 10, top: null, bottom: 40 * k),
              ];
          return Stack(
            children: [
              // Background glow: 16 radiating sparks and 5 twinkles, one
              // controller each, both under the birds and the disc.
              const Positioned.fill(child: QuizSparkField(maxRadius: 130)),
              const Positioned.fill(child: QuizTwinkleField(count: 5, seed: 7)),
              for (var i = 0; i < birds.length && i < 4; i++)
                Positioned(
                  left: spots[i].left,
                  right: spots[i].right,
                  top: spots[i].top,
                  bottom: spots[i].bottom,
                  child: QuizFloat(
                    period: QuizMotion.floatIntro,
                    delay: QuizMotion.floatStep * i,
                    child: Transform.rotate(
                      angle: _tilts[i] * math.pi / 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: birds[i].tint.accent.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 3,
                              spreadRadius: 3,
                            ),
                            const BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: QuizBirdArt(
                          bird: birds[i],
                          size: orbit,
                          iconSize: 54 * k,
                          background: birds[i].tint.cardBackground(
                            Brightness.light,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Center(
                child: FittedBox(
                  // A short well (or a big font) scales its center down.
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QuizSpeechBubble(
                        label:
                            AppLocalizations.of(context)!.forkQuizIntroBubble,
                      ),
                      SizedBox(height: 10 * k),
                      QuizBounce(
                        child: QuizMysteryDisc(
                          size: 128 * k,
                          silhouette: 104 * k,
                        ),
                      ),
                      SizedBox(height: 14 * k),
                      QuizBars(
                        heights: const [14, 26, 20, 12, 6],
                        colors: BirdyQuizColors.barsIntro,
                        delays: [
                          for (var i = 0; i < 5; i++)
                            QuizMotion.barIntroStep * i,
                        ],
                        width: 6,
                        gap: 5,
                        period: QuizMotion.barIntro,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// « Comment on joue »: three tilted, numbered cards (Écoute, Devine, Gagne),
/// popping in one after another (Quiz v2 mockup, J6f-e).
class _StepCards extends StatelessWidget {
  const _StepCards({required this.questions, required this.choices});

  final int questions;
  final int choices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final steps = [
      (
        title: l10n.forkQuizStepListenTitle,
        body: l10n.forkQuizStepListenBody(questions),
        icon: AppIcons.graphicEqRounded,
        bg: c.tonal,
        ink: c.accentText,
        tilt: -0.035,
      ),
      (
        title: l10n.forkQuizStepGuessTitle,
        body: l10n.forkQuizStepGuessBody(choices),
        icon: AppIcons.helpOutlineRounded,
        bg: c.orioleContainer,
        ink: c.orioleText,
        tilt: 0.026,
      ),
      (
        title: l10n.forkQuizStepWinTitle,
        body: l10n.forkQuizStepWinBody,
        icon: AppIcons.quizSpark,
        bg: c.sure.background,
        ink: c.sure.foreground,
        tilt: -0.017,
      ),
    ];
    return Semantics(
      label: l10n.forkQuizHowWePlay,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: BirdySpace.s),
            Expanded(
              // The tilt sits outside the pop: the entrance scales and fades
              // the card without ever replacing its rotation.
              child: Transform.rotate(
                angle: steps[i].tilt,
                child: QuizPop(
                  duration: const Duration(milliseconds: 380),
                  delay: Duration(milliseconds: 120 + i * 100),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      BirdySpace.xs,
                      BirdySpace.m,
                      BirdySpace.xs,
                      BirdySpace.s,
                    ),
                    decoration: BoxDecoration(
                      color: steps[i].bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: BirdyBrand.ink,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: BirdyText.badge.copyWith(
                              color: BirdyBrand.mist,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.surface1,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            steps[i].icon,
                            size: 26,
                            color: steps[i].ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i].title,
                          style: BirdyText.species.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].body,
                          textAlign: TextAlign.center,
                          style: BirdyText.caption.copyWith(
                            color: steps[i].ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Oreille fine on the intro: medal, progress to the next plume and why
/// right answers matter.
class _IntroBadgeCard extends StatelessWidget {
  const _IntroBadgeCard({required this.badge});

  final BadgeProgress badge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final next = badge.nextTarget;
    final from = badge.tier == 0 ? 0 : badge.tiers[badge.tier - 1];
    // A dot per right answer when the next feather is close (as the mockup
    // shows for the first one, 10 answers); a continuous bar for a bigger
    // gap (the mockup's own segments would be unreadable past ~25).
    final segmented = next != null && next - from <= 25;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.l,
        vertical: BirdySpace.m,
      ),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Row(
        children: [
          Semantics(
            label:
                '${badgeName(l10n, badge.kind)}, '
                '${l10n.forkBadgeTier(badge.tier)}',
            child: ExcludeSemantics(
              child: BadgeMedal(
                tier: badge.tier,
                icon: badgeIcon(badge.kind),
                glyph: badgeGlyph(badge.kind),
                size: 44,
              ),
            ),
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Text(
                    l10n.forkQuizBadgeKicker(badgeName(l10n, badge.kind)),
                    style: BirdyText.caption.copyWith(
                      color: c.sure.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    next == null
                        ? badgeName(l10n, badge.kind)
                        : l10n.forkQuizNextFeather(badge.tier + 1),
                    style: BirdyText.species.copyWith(
                      color: c.text1,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (segmented)
                  QuizProgressSegments(total: next, filled: badge.value)
                else
                  QuizBadgeBar(value: toNextTier(badge)),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? l10n.forkBadgeAllTiers
                      : l10n.forkQuizLeftToGo(
                        next - badge.value,
                        l10n.forkQuizProgress(badge.value, next),
                      ),
                  style: BirdyText.caption.copyWith(
                    color: c.text1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 40 dp oriole disc standing in for the title's own « ? », tilted
/// like the mockup.
class _QuizTitleMark extends StatelessWidget {
  const _QuizTitleMark();

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Transform.rotate(
      angle: -8 * math.pi / 180,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: BirdyBrand.oriole,
          shape: BoxShape.circle,
        ),
        child: Text(
          '?',
          style: BirdyText.display.copyWith(color: c.text1, height: 1),
        ),
      ),
    );
  }
}

/// « C'est parti ! »: 72 dp, Martin-pêcheur, with its glow.
class _GoButton extends StatelessWidget {
  const _GoButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Pressable(
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
            iconSize: 32,
          ),
          onPressed: onPressed,
          icon: const Icon(AppIcons.playArrowRounded, fill: 1),
          label: Text(label),
        ),
      ),
    );
  }
}

/// « Avec effets / Sans effets »: the quiz's sound effects (never the bird song).
class QuizSoundSwitch extends StatelessWidget {
  const QuizSoundSwitch({super.key, required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    return Semantics(
      toggled: on,
      label: l10n.forkSettingsQuizEffects,
      value: on ? l10n.forkQuizEffectsOn : l10n.forkQuizEffectsOff,
      excludeSemantics: true,
      onTap: () => onChanged(!on),
      child: Pressable(
        child: Material(
          color: c.surface1,
          shape: StadiumBorder(side: BorderSide(color: c.lineOpaque)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(!on),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BirdySizes.target),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      on ? AppIcons.volumeUpRounded : AppIcons.volumeOffRounded,
                      size: 22,
                      fill: 1,
                      color: on ? c.accentText : c.text2,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        on ? l10n.forkQuizEffectsOn : l10n.forkQuizEffectsOff,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BirdyText.labelCompact.copyWith(color: c.text1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedContainer(
                      duration: reduced ? Duration.zero : QuizMotion.knob,
                      curve: QuizMotion.out,
                      width: 44,
                      height: 28,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: on ? c.accent : c.border,
                        borderRadius: BorderRadius.circular(BirdyRadii.pill),
                      ),
                      child: AnimatedAlign(
                        duration: reduced ? Duration.zero : QuizMotion.knob,
                        curve: QuizMotion.ease,
                        alignment:
                            on ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: BirdyQuizColors.knob,
                            boxShadow: [
                              BoxShadow(
                                color: BirdyQuizColors.knobShadow,
                                offset: Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
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
    );
  }
}
