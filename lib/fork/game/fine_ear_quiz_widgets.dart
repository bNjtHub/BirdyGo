/// Pieces of the « Qui chante ? » screen (J6e): the stage card (mystery
/// bird, then the revealed one), the answer cards and the end of a round.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/models/taxonomy_species.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../species_photo/species_photo.dart';
import '../species_photo/species_photo_config.dart';
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

  /// Bundled photo, for the avatar.
  final ImageProvider? image;

  /// Taxonomy entry, for the big photo and its credit.
  final TaxonomySpecies? species;
}

/// The top card. Before the answer: a mystery card (dashed outline, like
/// the notebook's species to find) with the big play button, nothing that
/// gives the bird away. After: the same frame shows the bird's photo on its
/// tint, with its name and Latin name.
class QuizStage extends StatelessWidget {
  const QuizStage({
    super.key,
    required this.bird,
    required this.revealed,
    required this.right,
    required this.playing,
    required this.onPlay,
  });

  final QuizBird bird;
  final bool revealed;

  /// The player found it (the sentence of the revealed card).
  final bool right;

  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    // One effect only: the revealed card fades in and slides 8 px (fade
    // alone with reduced motion); the mystery card simply gives way.
    if (!revealed) {
      return _MysteryCard(
        key: ValueKey('mystery ${bird.scientificName}'),
        playing: playing,
        onPlay: onPlay,
      );
    }
    return BirdyEntrance(
      key: ValueKey('reveal ${bird.scientificName}'),
      child: _RevealCard(
        bird: bird,
        right: right,
        playing: playing,
        onPlay: onPlay,
      ),
    );
  }
}

class _MysteryCard extends StatelessWidget {
  const _MysteryCard({super.key, required this.playing, required this.onPlay});

  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: c.dashed,
        radius: BirdyRadii.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: kSpeciesPhotoAspectRatio,
            child: Center(
              child: Transform.scale(
                scale: 1.5,
                child: ClipPlayButton(
                  state: playing ? ClipPlayState.playing : ClipPlayState.idle,
                  semanticLabel:
                      playing ? l10n.forkQuizStop : l10n.forkQuizListen,
                  onPressed: onPlay,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.l,
              0,
              BirdySpace.l,
              BirdySpace.l,
            ),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: SpeciesAvatar(size: 40, muted: true),
                ),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.forkQuizMystery,
                        style: BirdyText.heading.copyWith(color: c.text2),
                      ),
                      const SizedBox(height: BirdySpace.xs),
                      Text(
                        l10n.forkQuizHint,
                        style: BirdyText.caption.copyWith(color: c.text2),
                      ),
                    ],
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

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.bird,
    required this.right,
    required this.playing,
    required this.onPlay,
  });

  final QuizBird bird;
  final bool right;
  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(bird.scientificName);
    final sentence = right ? l10n.forkQuizRight : l10n.forkQuizWrong(bird.name);
    return Material(
      color: tint.cardBackground(c.brightness),
      borderRadius: BorderRadius.circular(BirdyRadii.hero),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: kSpeciesPhotoAspectRatio,
            child: SpeciesPhoto(species: bird.species),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.l,
              BirdySpace.m,
              BirdySpace.m,
              BirdySpace.l,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: '$sentence, ${bird.latin}',
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            right ? l10n.forkQuizRight : l10n.forkQuizAnswerWas,
                            style: BirdyText.label.copyWith(
                              color: right ? c.sure.foreground : c.text2,
                            ),
                          ),
                          const SizedBox(height: BirdySpace.xs),
                          Text(
                            bird.name,
                            style: BirdyText.heading.copyWith(color: c.text1),
                          ),
                          Text(
                            bird.latin,
                            style: BirdyText.latinCompact.copyWith(
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: BirdySpace.s),
                ClipPlayButton(
                  state: playing ? ClipPlayState.playing : ClipPlayState.idle,
                  semanticLabel:
                      playing ? l10n.forkQuizStop : l10n.forkQuizListenAgain,
                  onPressed: onPlay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum QuizChoiceState { open, right, wrong, other }

/// One answer: the bird's photo and its name. After the answer, the right
/// one turns Lichen with a check, a wrong pick goes neutral with a cross,
/// the others fade.
class QuizChoiceCard extends StatelessWidget {
  const QuizChoiceCard({
    super.key,
    required this.bird,
    required this.state,
    this.onTap,
  });

  final QuizBird bird;
  final QuizChoiceState state;
  final VoidCallback? onTap;

  static const double _avatar = 44;
  static const double _minHeight = 64;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final open = state == QuizChoiceState.open;
    final (background, foreground, border) = switch (state) {
      QuizChoiceState.open => (c.surface1, c.text1, c.border),
      QuizChoiceState.right => (
        c.sure.background,
        c.sure.foreground,
        c.sure.foreground,
      ),
      QuizChoiceState.wrong => (c.lineOpaque, c.text1, c.borderStrong),
      QuizChoiceState.other => (c.surface1, c.text2, c.line),
    };
    final icon = switch (state) {
      QuizChoiceState.right => AppIcons.check,
      QuizChoiceState.wrong => AppIcons.close,
      _ => null,
    };
    final value = switch (state) {
      QuizChoiceState.right => l10n.forkQuizChoiceRight,
      QuizChoiceState.wrong => l10n.forkQuizChoiceWrong,
      _ => null,
    };
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
                constraints: const BoxConstraints(minHeight: _minHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: BirdySpace.m,
                  vertical: BirdySpace.s,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(BirdyRadii.card),
                  border: Border.all(
                    color: border,
                    width: state == QuizChoiceState.right ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SpeciesAvatar(
                      image: bird.image,
                      tint: SpeciesAccents.tintOf(bird.scientificName),
                      size: _avatar,
                    ),
                    const SizedBox(width: BirdySpace.m),
                    Expanded(
                      child: Text(
                        bird.name,
                        style: BirdyText.species.copyWith(color: foreground),
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: BirdySpace.s),
                      Icon(icon, color: foreground),
                    ],
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

/// End of a round: the score, the Oreille fine medal and the way to its
/// next plume.
class QuizResult extends StatelessWidget {
  const QuizResult({
    super.key,
    required this.right,
    required this.total,
    required this.badge,
    required this.newTier,
    required this.onAgain,
    required this.onDone,
  });

  final int right;
  final int total;

  /// Oreille fine, this round's answers included.
  final BadgeProgress badge;

  /// This round won a plume.
  final bool newTier;

  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final next = badge.nextTarget;
    final from = badge.tier == 0 ? 0 : badge.tiers[badge.tier - 1];
    final toNext =
        next == null ? 1.0 : ((badge.value - from) / (next - from)).clamp(0, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: BirdyEntrance(
              duration: BirdyMotion.newStatus,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: BirdySpace.xl),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.forkQuizScore(right, total),
                      textAlign: TextAlign.center,
                      style: BirdyText.title.copyWith(color: c.text1),
                    ),
                  ),
                  const SizedBox(height: BirdySpace.xxl),
                  Container(
                    padding: const EdgeInsets.all(BirdySpace.xl),
                    decoration: BoxDecoration(
                      color: c.surface1,
                      borderRadius: BorderRadius.circular(BirdyRadii.card),
                      border: Border.all(color: c.line),
                    ),
                    child: Column(
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
                              size: 88,
                            ),
                          ),
                        ),
                        const SizedBox(height: BirdySpace.m),
                        ExcludeSemantics(
                          child: Text(
                            badgeName(l10n, badge.kind),
                            textAlign: TextAlign.center,
                            style: BirdyText.heading.copyWith(color: c.text1),
                          ),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        if (badge.tier > 0)
                          ExcludeSemantics(child: TierDots(filled: badge.tier)),
                        if (newTier) ...[
                          const SizedBox(height: BirdySpace.s),
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
                        const SizedBox(height: BirdySpace.l),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(BirdyRadii.pill),
                          child: LinearProgressIndicator(
                            value: toNext.toDouble(),
                            minHeight: 8,
                            color: c.sure.foreground,
                            backgroundColor: c.line,
                          ),
                        ),
                        const SizedBox(height: BirdySpace.s),
                        Text(
                          next == null
                              ? l10n.forkBadgeAllTiers
                              : l10n.forkQuizToNextTier(badge.value, next),
                          textAlign: TextAlign.center,
                          style: BirdyText.bodyCompact.copyWith(color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: BirdySpace.l),
                ],
              ),
            ),
          ),
        ),
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
    );
  }
}

/// Oreille fine for [correct] right answers.
BadgeProgress fineEarBadge(int correct) =>
    BadgeProgress(kind: BadgeKind.fineEar, value: correct);
