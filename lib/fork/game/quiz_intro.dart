/// The intro of « Qui chante ? » (J6e, Quiz v2): the well with four of the
/// player's birds floating around the mystery one, the title, the round in
/// one strip (songs, choices, birds), the Oreille fine progress and
/// « C'est parti ! ». The sound switch sits in the header.
library;

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
          final hero = (constraints.maxHeight * 0.4).clamp(168.0, heroMax);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: hero, child: _IntroWell(birds: birds)),
                      const SizedBox(height: BirdySpace.l),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.forkQuizTitle,
                          style: BirdyText.display.copyWith(color: c.text1),
                        ),
                      ),
                      const SizedBox(height: BirdySpace.s),
                      Text(
                        l10n.forkQuizIntro,
                        style: BirdyText.body.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: BirdySpace.l),
                      _StepCards(questions: questions, choices: choices),
                      const SizedBox(height: BirdySpace.l),
                      _IntroBadgeCard(badge: badge),
                      const SizedBox(height: BirdySpace.l),
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

  @override
  Widget build(BuildContext context) {
    return QuizWell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final k = (h / QuizIntro.heroMax).clamp(0.6, 1.0);
          final orbit = 64 * k;
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
              for (var i = 0; i < birds.length && i < 4; i++)
                Positioned(
                  left: spots[i].left,
                  right: spots[i].right,
                  top: spots[i].top,
                  bottom: spots[i].bottom,
                  child: QuizFloat(
                    period: QuizMotion.floatIntro,
                    delay: QuizMotion.floatStep * i,
                    child: QuizBirdArt(
                      bird: birds[i],
                      size: orbit,
                      iconSize: 54 * k,
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QuizSpeechBubble(
                      label: AppLocalizations.of(context)!.forkQuizIntroBubble,
                    ),
                    SizedBox(height: 10 * k),
                    QuizMysteryDisc(size: 128 * k, silhouette: 104 * k),
                    SizedBox(height: 14 * k),
                    QuizBars(
                      heights: const [14, 26, 20, 12, 6],
                      colors: BirdyQuizColors.barsIntro,
                      delays: [
                        for (var i = 0; i < 5; i++) QuizMotion.barIntroStep * i,
                      ],
                      width: 6,
                      gap: 5,
                      period: QuizMotion.barIntro,
                    ),
                  ],
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
              child: QuizPop(
                duration: const Duration(milliseconds: 380),
                delay: Duration(milliseconds: 120 + i * 100),
                child: Transform.rotate(
                  angle: steps[i].tilt,
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
                          child: Icon(steps[i].icon, size: 26, color: steps[i].ink),
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
                          style: BirdyText.caption.copyWith(color: steps[i].ink),
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

/// « Avec son / Sans son »: the quiz's sound effects (never the bird song).
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
      label: l10n.forkQuizSoundSwitch,
      value: on ? l10n.forkQuizSoundOn : l10n.forkQuizSoundOff,
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
                        on ? l10n.forkQuizSoundOn : l10n.forkQuizSoundOff,
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
