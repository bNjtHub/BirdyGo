/// End of a round of « Qui chante ? » (J6e, Quiz v2): the hero card with its
/// Loriot glow, three stars popping in one by one, the big score and a word;
/// the round's ten birds in a 5 × 2 grid (found in color with a check,
/// missed in grey with a cross, in cascade); the Oreille fine medal and its
/// bar filling up; then « Terminer » and « Rejouer ».
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/pressable.dart';
import 'fine_ear.dart';
import 'fine_ear_quiz_widgets.dart';
import 'game_config.dart';
import 'game_progress.dart';
import 'game_text.dart';
import 'game_widgets.dart';
import 'quiz_fx.dart';

class QuizResult extends StatelessWidget {
  const QuizResult({
    super.key,
    required this.birds,
    required this.results,
    required this.badge,
    required this.before,
    required this.onAgain,
    required this.onDone,
  });

  /// The bird of each question.
  final List<QuizBird> birds;

  /// Each answer, right or not.
  final List<bool> results;

  /// Oreille fine, this round's answers included.
  final BadgeProgress badge;

  /// Oreille fine when the round started.
  final BadgeProgress before;

  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final right = results.where((r) => r).length;
    final total = results.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuizRise(
                  child: _ScoreCard(
                    right: right,
                    total: total,
                    stars: quizStars(right, total),
                  ),
                ),
                const SizedBox(height: BirdySpace.m),
                QuizRise(
                  delay: QuizMotion.cardStep,
                  child: _RecapCard(birds: birds, results: results),
                ),
                const SizedBox(height: BirdySpace.m),
                QuizRise(
                  delay: QuizMotion.cardStep * 2,
                  child: _MedalCard(badge: badge, before: before, right: right),
                ),
                const SizedBox(height: BirdySpace.m),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Pressable(
                child: OutlinedButton(
                  style: BirdyButtonStyles.secondary(context).copyWith(
                    backgroundColor: WidgetStatePropertyAll(
                      BirdyColors.of(context).surface1,
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: BirdySpace.s),
                    ),
                  ),
                  onPressed: onDone,
                  child: Text(l10n.forkQuizDone, textAlign: TextAlign.center),
                ),
              ),
            ),
            const SizedBox(width: BirdySpace.s),
            Expanded(
              child: Pressable(
                child: FilledButton(
                  style: BirdyButtonStyles.primary(context).copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: BirdySpace.s),
                    ),
                  ),
                  onPressed: onAgain,
                  child: Text(l10n.forkQuizAgain, textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.right,
    required this.total,
    required this.stars,
  });

  final int right;
  final int total;
  final int stars;

  static const double glowRadius = 190;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    // The glow is the card's own decoration: Loriot at 32 % over the card
    // color, fading to the card color at 190 px.
    final glow = Color.alphaBlend(c.oriole.withValues(alpha: 0.32), c.surface1);
    return Container(
      key: const ValueKey('quiz-score-card'),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1,
          colors: [glow, c.surface1],
          transform: const QuizFixedRadius(glowRadius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l10n.forkQuizStars(stars),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      QuizPop(
                        duration: QuizMotion.star,
                        delay: QuizMotion.starDelay + QuizMotion.starStep * i,
                        child: Icon(
                          AppIcons.quizStar,
                          key: ValueKey('quiz-star-$i'),
                          size: i == 1 ? 56 : 42,
                          fill: 1,
                          color: i < stars ? c.oriole : c.lineOpaque,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: BirdySpace.s),
          Semantics(
            liveRegion: true,
            label: l10n.forkQuizScore(right, total),
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$right',
                      style: BirdyText.numberHero.copyWith(color: c.text1),
                    ),
                    TextSpan(
                      text: '/$total',
                      style: BirdyText.numberL.copyWith(color: c.text2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            l10n.forkQuizResultTitle('$stars'),
            textAlign: TextAlign.center,
            style: BirdyText.title.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkQuizResultLine(right, total),
            textAlign: TextAlign.center,
            style: BirdyText.bodyCompact.copyWith(color: c.text2),
          ),
        ],
      ),
    );
  }
}

/// The round's birds, five per row, popping in 50 ms apart.
class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.birds, required this.results});

  final List<QuizBird> birds;
  final List<bool> results;

  static const int perRow = 5;
  static const double gap = 6;
  static const double runGap = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final count = birds.length < results.length ? birds.length : results.length;
    return Container(
      padding: const EdgeInsets.all(BirdySpace.l),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.forkQuizRecap,
                    style: BirdyText.species.copyWith(color: c.text1),
                  ),
                ),
              ),
              Text(
                l10n.forkQuizFoundCount(
                  results.where((r) => r).length,
                ),
                style: BirdyText.caption.copyWith(
                  color: c.sure.foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final cell =
                  ((constraints.maxWidth - gap * (perRow - 1)) / perRow)
                      .floorToDouble();
              final size = cell < 54 ? cell : 54.0;
              final rows = <Widget>[];
              for (var r = 0; r * perRow < count; r++) {
                if (r > 0) rows.add(const SizedBox(height: runGap));
                rows.add(
                  Row(
                    key: ValueKey('quiz-recap-row-$r'),
                    children: [
                      for (var j = 0; j < perRow; j++) ...[
                        if (j > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: cell,
                          child:
                              r * perRow + j < count
                                  ? Center(
                                    child: QuizPop(
                                      duration: QuizMotion.recap,
                                      delay:
                                          QuizMotion.recapDelay +
                                          QuizMotion.recapStep *
                                              (r * perRow + j),
                                      child: _RecapBird(
                                        bird: birds[r * perRow + j],
                                        right: results[r * perRow + j],
                                        size: size,
                                        label:
                                            '${birds[r * perRow + j].name}, '
                                            '${results[r * perRow + j] ? l10n.forkQuizChoiceRight : l10n.forkQuizMissed}',
                                      ),
                                    ),
                                  )
                                  : null,
                        ),
                      ],
                    ],
                  ),
                );
              }
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _RecapBird extends StatelessWidget {
  const _RecapBird({
    required this.bird,
    required this.right,
    required this.size,
    required this.label,
  });

  final QuizBird bird;
  final bool right;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final mark = size * 20 / 54;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            QuizBirdArt(
              bird: bird,
              size: size,
              iconSize: size * 46 / 54,
              muted: !right,
              background: right ? null : c.background,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: mark,
                height: mark,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      right
                          ? c.sure.foreground
                          : c.isDark
                          ? BirdyQuizColors.missedDark
                          : BirdyQuizColors.missedLight,
                  boxShadow: [BoxShadow(color: c.surface1, spreadRadius: 2)],
                ),
                child: Icon(
                  right ? AppIcons.quizCheck : AppIcons.quizClose,
                  size: mark * (right ? 0.7 : 0.65),
                  weight: 600,
                  color: c.surface1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oreille fine after the round: the medal, « Nouvelle plume » when a tier
/// was just reached, the bar filling up to the new count.
class _MedalCard extends StatelessWidget {
  const _MedalCard({required this.badge, required this.before, required this.right});

  final BadgeProgress badge;
  final BadgeProgress before;

  /// Right answers this round (the card's « +N cette partie »).
  final int right;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final newTier = badge.tier > before.tier;
    final next = badge.nextTarget;
    Widget medal = BadgeMedal(
      tier: badge.tier,
      icon: badgeIcon(badge.kind),
      glyph: badgeGlyph(badge.kind),
      size: BirdySizes.liveControl,
    );
    if (badge.tier > 0) {
      medal = QuizPop(
        duration: QuizMotion.medal,
        delay: QuizMotion.medalDelay,
        child: medal,
      );
    }
    // The medal's own metal wash once earned; a plain card while locked. A
    // soft blend in dark mode, the flat mockup tone in light.
    final cardColor =
        badge.tier == 0
            ? c.surface1
            : c.isDark
            ? Color.alphaBlend(
              GameConfig.badgeMedals[badge.tier - 1].tone.withValues(
                alpha: 0.14,
              ),
              c.surface1,
            )
            : GameConfig.badgeMedals[badge.tier - 1].tone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Row(
        children: [
          Semantics(
            label:
                '${badgeName(l10n, badge.kind)}, '
                '${l10n.forkBadgeTier(badge.tier)}',
            child: ExcludeSemantics(child: medal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: BirdySpace.s,
                  runSpacing: BirdySpace.xs,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        badgeName(l10n, badge.kind),
                        style: BirdyText.species.copyWith(color: c.text1),
                      ),
                    ),
                    if (newTier)
                      QuizPop(
                        duration: QuizMotion.newTier,
                        delay: QuizMotion.newTierDelay,
                        child: BirdyPill(
                          label: l10n.forkQuizNewTier,
                          foreground: c.onOriole,
                          background: c.oriole,
                          leading: Icon(
                            AppIcons.quizSpark,
                            size: 14,
                            color: c.onOriole,
                            fill: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                QuizBadgeBar(
                  key: const ValueKey('quiz-medal-bar'),
                  value: toNextTier(badge),
                  from: newTier ? 0 : toNextTier(before),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: BirdyText.caption.copyWith(color: c.text2),
                    children: [
                      TextSpan(
                        text: l10n.forkQuizThisRoundCount(right),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: c.sure.foreground,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' · ${next == null ? l10n.forkBadgeAllTiers : l10n.forkQuizToTier(badge.value, next, badge.tier + 1)}',
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
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
