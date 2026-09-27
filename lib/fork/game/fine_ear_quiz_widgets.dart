/// Pieces of the « Qui chante ? » screen (J6e, Quiz v2): the intro, the
/// trail of stones, the stage (mystery bird, then the revealed one), the
/// answer tiles and the end of a round.
library;

import 'dart:math' as math;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/models/taxonomy_species.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../species_photo/photo_credit.dart';
import '../species_photo/photo_credit_sheet.dart';
import 'fine_ear.dart';
import 'game_config.dart';
import 'game_progress.dart';
import 'game_text.dart';
import 'game_widgets.dart';

/// The bird of the question, as shown on screen.
class QuizBird {
  const QuizBird({
    required this.scientificName,
    required this.latin,
    required this.name,
    this.image,
    this.species,
  });

  final String scientificName;

  /// Scientific name to show (taxonomy-canonical).
  final String latin;

  /// Common name in the species language.
  final String name;

  /// Bundled photo, for the avatars.
  final ImageProvider? image;

  /// Taxonomy entry, for the photo credit.
  final TaxonomySpecies? species;

  SpeciesTint get tint => SpeciesAccents.tintOf(scientificName);
}

/// Oreille fine for [correct] right answers.
BadgeProgress fineEarBadge(int correct) =>
    BadgeProgress(kind: BadgeKind.fineEar, value: correct);

/// Share of the way from the badge's current tier to its next one.
double _toNextTier(BadgeProgress badge) {
  final next = badge.nextTarget;
  if (next == null) return 1;
  final from = badge.tier == 0 ? 0 : badge.tiers[badge.tier - 1];
  return ((badge.value - from) / (next - from)).clamp(0, 1).toDouble();
}

/// Text on the listening well, the same in both themes (the well is always
/// dark, like the Live screen).
const Color _onWell = BirdyBrand.mist;
final Color _onWellMuted = BirdyColors.dark.text2;

/// The dark « écoute » well: Encre gradient, radius 28.
class _Well extends StatelessWidget {
  const _Well({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(BirdyRadii.hero),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [BirdyBrand.wellTop, BirdyBrand.wellBottom],
      ),
    ),
    child: child,
  );
}

/// Still sound bars in Martin-pêcheur shades, the second one Loriot. Still
/// on purpose: DESIGN.md forbids looping effects; [lit] brightens them
/// while the clip plays.
class _SoundBars extends StatelessWidget {
  const _SoundBars({required this.heights, this.lit = true, this.width = 6});

  final List<double> heights;
  final bool lit;
  final double width;

  static Color _shade(int i) =>
      i == 1
          ? BirdyBrand.oriole
          : Color.lerp(
            BirdyBrand.kingfisher,
            BirdyBrand.mist,
            0.25 + i * 0.12,
          )!;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedOpacity(
      opacity: lit ? 1 : 0.45,
      duration: BirdyMotion.exit,
      curve: BirdyMotion.standard,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < heights.length; i++) ...[
            if (i > 0) SizedBox(width: width * 0.8),
            Container(
              width: width,
              height: heights[i],
              decoration: BoxDecoration(
                color: _shade(i),
                borderRadius: BorderRadius.circular(BirdyRadii.pill),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// The mystery bird: a dashed circle on the well with a bird silhouette,
/// nothing that gives the bird away.
class _MysteryDisc extends StatelessWidget {
  const _MysteryDisc({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: _onWell.withValues(alpha: 0.32),
        radius: size / 2,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _onWell.withValues(alpha: 0.06),
        ),
        child: Icon(
          AppIcons.bird,
          size: size * 0.5,
          color: _onWell.withValues(alpha: 0.7),
        ),
      ),
    ),
  );
}

/// A bird's photo in a round halo of its tint.
class _HaloAvatar extends StatelessWidget {
  const _HaloAvatar({
    required this.bird,
    required this.size,
    this.muted = false,
  });

  final QuizBird bird;

  /// Outer size, halo included.
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tint = bird.tint;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: muted ? BirdyColors.of(context).lineOpaque : tint.halo,
      ),
      child: SpeciesAvatar(
        image: bird.image,
        tint: tint,
        size: size * 0.86,
        muted: muted,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Intro
// ---------------------------------------------------------------------------

/// Before a round: the well with four of the player's birds around the
/// mystery one, the title, what a round is, the Oreille fine progress and
/// « C'est parti ! ».
class QuizIntro extends StatelessWidget {
  const QuizIntro({
    super.key,
    required this.birds,
    required this.questions,
    required this.choices,
    required this.birdCount,
    required this.badge,
    required this.onStart,
  });

  /// Up to four of the player's birds, around the mystery one.
  final List<QuizBird> birds;

  final int questions;
  final int choices;

  /// Verified birds with a clip.
  final int birdCount;

  /// Oreille fine now.
  final BadgeProgress badge;

  final VoidCallback onStart;

  static const List<Alignment> _orbit = [
    Alignment(-0.82, -0.72),
    Alignment(0.82, -0.62),
    Alignment(-0.76, 0.74),
    Alignment(0.76, 0.66),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = (constraints.maxHeight * 0.36).clamp(168.0, 290.0);
        final orbitSize = (heroHeight * 0.22).clamp(44.0, 64.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: BirdyEntrance(
                  offset: Offset.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: heroHeight,
                        child: _Well(
                          child: Stack(
                            children: [
                              for (var i = 0; i < birds.length && i < 4; i++)
                                Align(
                                  alignment: _orbit[i],
                                  child: ExcludeSemantics(
                                    child: _HaloAvatar(
                                      bird: birds[i],
                                      size: orbitSize,
                                    ),
                                  ),
                                ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MysteryDisc(size: heroHeight * 0.44),
                                    SizedBox(height: heroHeight * 0.05),
                                    const _SoundBars(
                                      heights: [14, 26, 20, 12, 6],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                      Wrap(
                        spacing: BirdySpace.s,
                        runSpacing: BirdySpace.s,
                        children: [
                          _Chip(
                            icon: AppIcons.graphicEqRounded,
                            label: l10n.forkQuizSongs(questions),
                          ),
                          _Chip(
                            icon: AppIcons.gridViewRounded,
                            label: l10n.forkQuizChoiceCount(choices),
                          ),
                          _Chip(label: l10n.forkQuizBirdCount(birdCount)),
                        ],
                      ),
                      const SizedBox(height: BirdySpace.l),
                      _BadgeCard(badge: badge),
                      const SizedBox(height: BirdySpace.l),
                    ],
                  ),
                ),
              ),
            ),
            Pressable(
              child: FilledButton.icon(
                style: BirdyButtonStyles.primary(context).copyWith(
                  minimumSize: const WidgetStatePropertyAll(
                    Size(64, BirdySizes.listen),
                  ),
                  textStyle: WidgetStatePropertyAll(
                    BirdyText.label.copyWith(fontSize: 20),
                  ),
                  iconSize: const WidgetStatePropertyAll(28),
                ),
                onPressed: onStart,
                icon: const Icon(AppIcons.playArrowRounded, fill: 1),
                label: Text(l10n.forkQuizGo),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.m + 2,
        vertical: BirdySpace.xs,
      ),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.pill),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c.accentText),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: BirdyText.labelCompact.copyWith(color: c.text1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oreille fine on the intro: medal, progress to the next plume and why
/// right answers matter.
class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final BadgeProgress badge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final next = badge.nextTarget;
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
                size: BirdySizes.target,
              ),
            ),
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: BirdySpace.s,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        badgeName(l10n, badge.kind),
                        style: BirdyText.species.copyWith(color: c.text1),
                      ),
                    ),
                    if (next != null)
                      Text(
                        l10n.forkQuizProgress(badge.value, next),
                        style: BirdyText.caption.copyWith(
                          color: c.text2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _Bar(value: _toNextTier(badge)),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? l10n.forkBadgeAllTiers
                      : l10n.forkQuizTierHint(badge.tier + 1),
                  style: BirdyText.caption.copyWith(color: c.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lichen progress bar, 8 dp. With [from], it moves once from there to
/// [value] (with reduced motion it simply shows [value]).
class _Bar extends StatelessWidget {
  const _Bar({required this.value, this.from});

  final double value;
  final double? from;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    Widget bar(double v) => ClipRRect(
      borderRadius: BorderRadius.circular(BirdyRadii.pill),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 8,
        color: c.sure.foreground,
        backgroundColor: c.lineOpaque,
      ),
    );
    final start = from;
    if (start == null || BirdyMotion.reduced(context)) return bar(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: start, end: value),
      duration: BirdyMotion.celebrationMax,
      curve: BirdyMotion.standard,
      builder: (context, v, _) => bar(v),
    );
  }
}

// ---------------------------------------------------------------------------
// Question
// ---------------------------------------------------------------------------

/// The trail of stones, one per question. A found bird leaves its photo, a
/// missed one a small cross, the current one shows its number.
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
            final slot = constraints.maxWidth / total;
            final done = math.min(results.length, total - 1);
            final span = constraints.maxWidth - slot;
            return SizedBox(
              height: 32,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: slot / 2,
                    right: slot / 2,
                    child: Container(height: 3, color: c.lineOpaque),
                  ),
                  Positioned(
                    left: slot / 2,
                    child: AnimatedContainer(
                      duration: BirdyMotion.reorder,
                      curve: BirdyMotion.move,
                      width: total < 2 ? 0 : span * done / (total - 1),
                      height: 3,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(BirdyRadii.pill),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < total; i++)
                        SizedBox(
                          width: slot,
                          child: Center(child: _stone(context, i, slot)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _stone(BuildContext context, int i, double slot) {
    final c = BirdyColors.of(context);
    if (i < results.length) {
      final Widget stone;
      if (results[i]) {
        final tint = birds[i].tint;
        final size = math.min(26.0, slot);
        stone = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.cardBackground(c.brightness),
            border: Border.all(color: tint.accent, width: 2),
          ),
          child: SpeciesAvatar(
            image: birds[i].image,
            tint: tint,
            size: size - 4,
          ),
        );
      } else {
        final size = math.min(20.0, slot);
        stone = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface1,
            border: Border.all(color: c.border, width: 2),
          ),
          child: Icon(AppIcons.close, size: size * 0.5, color: c.text2),
        );
      }
      return BirdyEntrance(
        key: ValueKey('stone $i'),
        offset: Offset.zero,
        fromScale: BirdyMotion.appearScale,
        child: stone,
      );
    }
    if (i == current) {
      final size = math.min(30.0, slot);
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.surface1,
          border: Border.all(color: c.accent, width: 3),
        ),
        child: FittedBox(
          child: Text(
            '${i + 1}',
            textScaler: TextScaler.noScaling,
            style: BirdyText.badge.copyWith(
              color: c.accentText,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    final size = math.min(12.0, slot);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.border),
    );
  }
}

enum QuizStageState { listening, right, wrong }

/// The stage. Listening: the dark well with the mystery bird and the big
/// play button, nothing that gives the bird away. Right: the bird's tint,
/// its photo, a cheer, its name and « +1 Oreille fine ». Wrong: a calm
/// card, « Presque ! » and the bird's name.
class QuizStage extends StatelessWidget {
  const QuizStage({
    super.key,
    required this.bird,
    required this.state,
    required this.playing,
    required this.onPlay,
    required this.cheer,
    this.minHeight = 244,
  });

  final QuizBird bird;
  final QuizStageState state;
  final bool playing;
  final VoidCallback onPlay;

  /// Which cheer a right answer gets (it varies from one question to the
  /// next).
  final int cheer;

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    // One effect only: the revealed card fades in and slides 8 px (fade
    // alone with reduced motion); the mystery card simply gives way.
    return switch (state) {
      QuizStageState.listening => _ListeningCard(
        key: ValueKey('mystery ${bird.scientificName}'),
        playing: playing,
        onPlay: onPlay,
        minHeight: minHeight,
      ),
      _ => BirdyEntrance(
        key: ValueKey('reveal ${bird.scientificName}'),
        child: _RevealCard(
          bird: bird,
          right: state == QuizStageState.right,
          playing: playing,
          onPlay: onPlay,
          cheer: cheer,
          minHeight: minHeight,
        ),
      ),
    };
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({
    super.key,
    required this.playing,
    required this.onPlay,
    required this.minHeight,
  });

  final bool playing;
  final VoidCallback onPlay;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Well(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.all(BirdySpace.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.forkQuizMystery,
                style: BirdyText.badge.copyWith(color: _onWellMuted),
              ),
              const SizedBox(height: BirdySpace.xs),
              Center(child: _MysteryDisc(size: minHeight * 0.44)),
              const SizedBox(height: BirdySpace.m),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SoundBars(
                    heights: const [10, 20, 26],
                    lit: playing,
                    width: 5,
                  ),
                  const SizedBox(width: BirdySpace.m + 2),
                  _BigPlayButton(
                    playing: playing,
                    label: playing ? l10n.forkQuizStop : l10n.forkQuizListen,
                    onPressed: onPlay,
                  ),
                  const SizedBox(width: BirdySpace.m + 2),
                  _SoundBars(
                    heights: const [26, 18, 10],
                    lit: playing,
                    width: 5,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 64 dp filled play button of the well.
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
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Pressable(
          child: Material(
            color: BirdyBrand.kingfisher,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: BirdySizes.liveControl,
                child: Icon(
                  playing ? AppIcons.stop : AppIcons.playArrowRounded,
                  size: playing ? 26 : 32,
                  fill: 1,
                  color: BirdyBrand.ink,
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
    required this.minHeight,
  });

  final QuizBird bird;
  final bool right;
  final bool playing;
  final VoidCallback onPlay;
  final int cheer;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = bird.tint;
    final heading = right ? l10n.forkQuizCheer('$cheer') : l10n.forkQuizAlmost;
    final sentence =
        right
            ? l10n.forkQuizRightName(bird.name)
            : l10n.forkQuizWrong(bird.name);
    final species = bird.species;
    Widget photo = _HaloAvatar(bird: bird, size: minHeight * 0.44);
    if (species != null) {
      // Credit and license at a tap on the photo (DESIGN.md « Photos »).
      photo = Semantics(
        button: true,
        label: l10n.forkPhotoCredit,
        excludeSemantics: true,
        child: GestureDetector(
          onTap:
              () => showPhotoCreditSheet(
                context,
                PhotoCredit.fromSpecies(species),
              ),
          child: photo,
        ),
      );
    }
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: right ? tint.cardBackground(c.brightness) : c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        border: right ? null : Border.all(color: c.line, width: 1.5),
      ),
      child: Stack(
        children: [
          if (right)
            // A still glow of the bird's color, at 15 % at most.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BirdyRadii.hero),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 0.8,
                    colors: [
                      tint.accent.withValues(alpha: BirdyMotion.tintMaxOpacity),
                      tint.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.l,
              BirdySpace.xl,
              BirdySpace.l,
              BirdySpace.l,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  photo,
                  const SizedBox(height: BirdySpace.s),
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label: '$heading $sentence',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          Text(
                            heading,
                            textAlign: TextAlign.center,
                            style: (right ? BirdyText.display : BirdyText.title)
                                .copyWith(color: c.text1),
                          ),
                          const SizedBox(height: BirdySpace.xs),
                          _NameSentence(sentence: sentence, name: bird.name),
                        ],
                      ),
                    ),
                  ),
                  if (right) ...[
                    const SizedBox(height: BirdySpace.s),
                    BirdyEntrance(
                      delay: BirdyMotion.newStatusTextDelay,
                      offset: Offset.zero,
                      child: BirdyPill(
                        label: l10n.forkQuizPlusOne(
                          badgeName(l10n, BadgeKind.fineEar),
                        ),
                        foreground: c.onOriole,
                        background: c.oriole,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: BirdySpace.m,
            right: BirdySpace.m,
            child: ClipPlayButton(
              state: playing ? ClipPlayState.playing : ClipPlayState.idle,
              semanticLabel:
                  playing ? l10n.forkQuizStop : l10n.forkQuizListenAgain,
              onPressed: onPlay,
            ),
          ),
        ],
      ),
    );
  }
}

/// [sentence] with the bird's [name] in Fraunces.
class _NameSentence extends StatelessWidget {
  const _NameSentence({required this.sentence, required this.name});

  final String sentence;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final at = sentence.indexOf(name);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Text.rich(
        at < 0
            ? TextSpan(text: sentence)
            : TextSpan(
              children: [
                TextSpan(text: sentence.substring(0, at)),
                TextSpan(
                  text: name,
                  style: BirdyText.species.copyWith(color: c.text1),
                ),
                TextSpan(text: sentence.substring(at + name.length)),
              ],
            ),
        textAlign: TextAlign.center,
        style: BirdyText.body.copyWith(color: c.text1),
      ),
    );
  }
}

enum QuizChoiceState { open, right, wrong, other }

/// One answer tile: the bird's photo in its halo and its name. After the
/// answer, the right one turns Lichen with a check, a wrong pick goes
/// neutral with a cross, the others fade.
class QuizChoiceCard extends StatelessWidget {
  const QuizChoiceCard({
    super.key,
    required this.bird,
    required this.state,
    this.onTap,
    this.minHeight = 148,
  });

  final QuizBird bird;
  final QuizChoiceState state;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final open = state == QuizChoiceState.open;
    final (background, foreground, border, width) = switch (state) {
      QuizChoiceState.open => (c.surface1, c.text1, c.line, 1.5),
      QuizChoiceState.right => (
        c.sure.background,
        c.sure.foreground,
        c.sure.foreground,
        2.5,
      ),
      QuizChoiceState.wrong => (c.lineOpaque, c.text1, c.borderStrong, 1.5),
      QuizChoiceState.other => (c.surface1, c.text2, c.line, 1.5),
    };
    final (IconData? mark, Color? markColor) = switch (state) {
      QuizChoiceState.right => (AppIcons.check, c.sure.foreground),
      QuizChoiceState.wrong => (AppIcons.close, c.text2),
      _ => (null, null),
    };
    final value = switch (state) {
      QuizChoiceState.right => l10n.forkQuizChoiceRight,
      QuizChoiceState.wrong => l10n.forkQuizChoiceWrong,
      _ => null,
    };
    // Shorter tiles on small phones: the photo shrinks with them.
    final avatar = (minHeight * 0.57).clamp(48.0, 84.0);
    return Semantics(
      button: open,
      enabled: open,
      label: bird.name,
      value: value,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: state == QuizChoiceState.other ? 0.45 : 1,
        duration: BirdyMotion.exit,
        curve: BirdyMotion.standard,
        child: Pressable(
          enabled: open,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: open ? onTap : null,
              borderRadius: BorderRadius.circular(BirdyRadii.card),
              child: AnimatedContainer(
                duration: BirdyMotion.enter,
                curve: BirdyMotion.standard,
                constraints: BoxConstraints(minHeight: minHeight),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(BirdyRadii.card),
                  border: Border.all(color: border, width: width),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BirdySpace.m,
                        vertical: BirdySpace.s + 2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: _HaloAvatar(bird: bird, size: avatar)),
                          const SizedBox(height: BirdySpace.s),
                          Text(
                            bird.name,
                            textAlign: TextAlign.center,
                            style: BirdyText.species.copyWith(
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mark != null)
                      Positioned(
                        top: BirdySpace.s,
                        right: BirdySpace.s,
                        child: BirdyEntrance(
                          offset: Offset.zero,
                          fromScale: BirdyMotion.appearScale,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: markColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              mark,
                              size: 18,
                              weight: 700,
                              color: c.background,
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

/// Answer tiles two by two, equal heights on each row.
class QuizChoiceGrid extends StatelessWidget {
  const QuizChoiceGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: BirdySpace.m));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: BirdySpace.m),
              Expanded(
                child:
                    i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

/// End of a round: stars, the big score and a word, the round's birds
/// (found in color, missed in grey), the Oreille fine medal moving toward
/// its next plume, then « Terminer » and « Rejouer ».
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
    final c = BirdyColors.of(context);
    final right = results.where((r) => r).length;
    final total = results.length;
    final newTier = badge.tier > before.tier;
    final next = badge.nextTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BirdyEntrance(
                  duration: BirdyMotion.newStatus,
                  child: _ScoreCard(
                    right: right,
                    total: total,
                    stars: quizStars(right, total),
                  ),
                ),
                const SizedBox(height: BirdySpace.m),
                BirdyEntrance(
                  delay: BirdyMotion.staggerDelay(1),
                  child: _RecapCard(birds: birds, results: results),
                ),
                const SizedBox(height: BirdySpace.m),
                BirdyEntrance(
                  delay: BirdyMotion.staggerDelay(2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BirdySpace.l,
                      vertical: BirdySpace.m + 2,
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
                              size: BirdySizes.liveControl,
                            ),
                          ),
                        ),
                        const SizedBox(width: BirdySpace.m + 2),
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
                                      style: BirdyText.species.copyWith(
                                        color: c.text1,
                                      ),
                                    ),
                                  ),
                                  if (newTier)
                                    BirdyPill(
                                      label: l10n.forkQuizNewTier,
                                      foreground: c.onOriole,
                                      background: c.oriole,
                                      leading: Icon(
                                        AppIcons.sparkle,
                                        size: 14,
                                        color: c.onOriole,
                                        fill: 1,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _Bar(
                                value: _toNextTier(badge),
                                from: newTier ? 0 : _toNextTier(before),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                next == null
                                    ? l10n.forkBadgeAllTiers
                                    : l10n.forkQuizToTier(
                                      badge.value,
                                      next,
                                      badge.tier + 1,
                                    ),
                                style: BirdyText.caption.copyWith(
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: BirdySpace.l),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.xl,
        BirdySpace.xl,
        BirdySpace.xl,
        BirdySpace.l + 2,
      ),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
      ),
      child: Stack(
        children: [
          // A still Loriot glow behind the stars, at 15 % at most.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    c.oriole.withValues(alpha: BirdyMotion.tintMaxOpacity),
                    c.oriole.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: l10n.forkQuizStars(stars),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        BirdyEntrance(
                          delay: BirdyMotion.staggerDelay(i + 1),
                          offset: Offset.zero,
                          fromScale: BirdyMotion.appearScale,
                          child: _Star(
                            earned: i < stars,
                            size: i == 1 ? 50 : 38,
                          ),
                        ),
                      ],
                    ],
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
        ],
      ),
    );
  }
}

/// A star: Loriot with a darker rim when earned, neutral otherwise.
class _Star extends StatelessWidget {
  const _Star({required this.earned, required this.size});

  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            AppIcons.star,
            size: size,
            fill: 1,
            color: earned ? c.orioleText : c.border,
          ),
          Icon(
            AppIcons.star,
            size: size - 6,
            fill: 1,
            color: earned ? c.oriole : c.lineOpaque,
          ),
        ],
      ),
    );
  }
}

/// The round's birds: found ones in color with a check, missed ones in grey
/// with a cross; five per row.
class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.birds, required this.results});

  final List<QuizBird> birds;
  final List<bool> results;

  static const int _perRow = 5;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Container(
      padding: const EdgeInsets.all(BirdySpace.l),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.forkQuizRecap,
              style: BirdyText.species.copyWith(color: c.text1),
            ),
          ),
          const SizedBox(height: BirdySpace.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final cell =
                  ((constraints.maxWidth - _gap * (_perRow - 1)) / _perRow)
                      .floorToDouble();
              final size = math.min(54.0, cell);
              return Wrap(
                spacing: _gap,
                runSpacing: BirdySpace.s + 2,
                children: [
                  for (var i = 0; i < birds.length && i < results.length; i++)
                    SizedBox(
                      width: cell,
                      child: Center(
                        child: _RecapBird(
                          bird: birds[i],
                          right: results[i],
                          size: size,
                          label:
                              '${birds[i].name}, '
                              '${results[i] ? l10n.forkQuizChoiceRight : l10n.forkQuizMissed}',
                        ),
                      ),
                    ),
                ],
              );
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
    final mark = size * 0.37;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _HaloAvatar(bird: bird, size: size, muted: !right),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: mark,
                height: mark,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: right ? c.sure.foreground : c.text2,
                  border: Border.all(color: c.surface1, width: 2),
                ),
                child: Icon(
                  right ? AppIcons.check : AppIcons.close,
                  size: mark * 0.6,
                  weight: 700,
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
