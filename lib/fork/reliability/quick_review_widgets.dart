/// Pieces of the quick review screen (J6c, SPEC.md 9.9 and 5.11): top bar,
/// progress, card stack, swipe hints, verdict buttons and the end message.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import 'clip_spectrogram.dart';

/// Answers of the quick review, in swipe order: left, up, right.
enum ReviewAnswer { itIs, itIsNot, dontKnow }

/// « Revue rapide » · « 3 sur 12 », with close and reliability buttons.
class ReviewTopBar extends StatelessWidget {
  const ReviewTopBar({
    super.key,
    required this.position,
    required this.total,
    required this.onClose,
    required this.onReliability,
  });

  /// 1-based position, or null when nothing is left.
  final int? position;
  final int total;
  final VoidCallback onClose;
  final VoidCallback onReliability;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return SizedBox(
      height: BirdySizes.topBar,
      child: Row(
        children: [
          BirdyIconButton(
            icon: AppIcons.close,
            semanticLabel: l10n.forkQuickReviewClose,
            onPressed: onClose,
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Text(
              l10n.forkQuickReview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
          if (position != null)
            Text(
              l10n.forkQuickReviewProgress(position!, total),
              style: BirdyText.label.copyWith(color: c.text1),
            ),
          const SizedBox(width: BirdySpace.s),
          BirdyIconButton(
            icon: AppIcons.verifiedRounded,
            semanticLabel: l10n.forkReliabilityTitle,
            onPressed: onReliability,
          ),
        ],
      ),
    );
  }
}

/// 6 px bar and « Tu as trié N détections. ».
class ReviewProgress extends StatelessWidget {
  const ReviewProgress({super.key, required this.value, required this.sorted});

  /// 0 to 1.
  final double value;
  final int sorted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: c.line),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: value.clamp(0, 1),
                  child: ColoredBox(color: c.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.forkQuickReviewSorted(sorted),
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
      ],
    );
  }
}

/// The top card over up to two back cards (8 and 16 px lower, 0.96 and
/// 0.92 scale), SPEC.md 9.9.
class ReviewCardStack extends StatelessWidget {
  const ReviewCardStack({super.key, required this.behind, required this.top});

  /// Cards waiting after the top one (0, 1, 2 or more).
  final int behind;
  final Widget top;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    Widget back(double dy, double scale, double opacity) => Positioned.fill(
      bottom: 0,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(BirdyRadii.hero),
                boxShadow: c.floatShadow,
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (behind >= 2) back(16, 0.92, 0.6),
          if (behind >= 1) back(8, 0.96, 0.85),
          top,
        ],
      ),
    );
  }
}

/// Content of the top card.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.name,
    required this.latin,
    required this.when,
    required this.detail,
    required this.badge,
    required this.image,
    required this.clipPath,
    required this.playing,
    required this.onPlay,
    required this.onReference,
    this.hint,
  });

  final String name;
  final String? latin;

  /// « aujourd'hui à 7:38 ».
  final String when;

  /// « Score 0,87 ».
  final String detail;
  final Widget badge;
  final ImageProvider? image;
  final String? clipPath;
  final bool playing;
  final VoidCallback onPlay;

  /// Opens the reference song, or null without one.
  final VoidCallback? onReference;

  /// Answer the current drag would give: tints the card's outline.
  final ReviewAnswer? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final outline = switch (hint) {
      ReviewAnswer.itIs => BirdyBrand.lichen,
      ReviewAnswer.itIsNot => c.toCheck.foreground,
      ReviewAnswer.dontKnow => c.probable.foreground,
      null => Colors.transparent,
    };
    final clip = clipPath;
    return AnimatedContainer(
      duration: BirdyMotion.press,
      curve: BirdyMotion.standard,
      padding: const EdgeInsets.all(BirdySpace.xl),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        border: Border.all(color: outline, width: 3),
        boxShadow: c.floatShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(height: BirdySpace.m),
          Row(
            children: [
              SpeciesAvatar(image: image, scientificName: latin, size: 96),
              const SizedBox(width: BirdySpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: BirdyText.title.copyWith(color: c.text1)),
                    if (latin != null)
                      Text(
                        latin!,
                        style: BirdyText.latin.copyWith(color: c.text2),
                      ),
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      when,
                      style: BirdyText.bodyCompact.copyWith(color: c.text1),
                    ),
                    Text(
                      detail,
                      style: BirdyText.caption.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          if (clip != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(BirdyRadii.inset),
              child: Stack(
                children: [
                  ClipSpectrogram(path: clip, height: 80),
                  if (playing)
                    PositionedDirectional(
                      start: 10,
                      top: 8,
                      child: Text(
                        l10n.forkQuickReviewPlaying,
                        style: BirdyText.caption.copyWith(
                          color: BirdyBrand.mist,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: BirdySpace.m),
          ] else ...[
            Text(
              l10n.forkQuickReviewNoClip,
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
            const SizedBox(height: BirdySpace.m),
          ],
          Wrap(
            spacing: BirdySpace.s,
            runSpacing: BirdySpace.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (clip != null)
                ClipPlayButton(
                  state: playing ? ClipPlayState.playing : ClipPlayState.idle,
                  semanticLabel:
                      playing
                          ? l10n.forkReplayStop
                          : '${l10n.forkReplay} : $name',
                  onPressed: onPlay,
                ),
              if (onReference != null)
                Pressable(
                  child: FilledButton.icon(
                    style: BirdyButtonStyles.tonal(context),
                    onPressed: onReference,
                    icon: const Icon(AppIcons.openInNew),
                    label: Text(l10n.forkFicheReference),
                  ),
                ),
            ],
          ),
          if (clip != null || onReference != null) ...[
            const SizedBox(height: BirdySpace.xs),
            Text(
              l10n.forkQuickReviewHeadphones,
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
          ],
        ],
      ),
    );
  }
}

/// « Ce n'est pas lui » ‹ · ˄ « Je ne sais pas » · « C'est bien lui » ›.
class SwipeHints extends StatelessWidget {
  const SwipeHints({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final style = BirdyText.caption.copyWith(color: c.text2);
    Widget hint(IconData icon, String label, {bool trailing = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!trailing) Icon(icon, size: 16, color: c.text2),
        Flexible(child: Text(label, style: style)),
        if (trailing) Icon(icon, size: 16, color: c.text2),
      ],
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: hint(AppIcons.chevronLeft, l10n.forkReviewItIsNot),
            ),
          ),
          Expanded(
            child: Center(
              child: hint(AppIcons.chevronUp, l10n.forkReviewDontKnow),
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: hint(
                AppIcons.chevronRight,
                l10n.forkReviewItIs,
                trailing: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three verdict buttons, in swipe order (SPEC.md 5.11, light 104 px).
class VerdictButtons extends StatelessWidget {
  const VerdictButtons({
    super.key,
    required this.enabled,
    required this.onAnswer,
  });

  final bool enabled;
  final void Function(ReviewAnswer answer) onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget button({
      required ReviewAnswer answer,
      required String label,
      required IconData icon,
      required Color iconColor,
      required Color circle,
      Color? ring,
      required Color background,
      required Color border,
    }) => Expanded(
      child: Pressable(
        enabled: enabled,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BirdyRadii.card),
            side: BorderSide(color: border, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => onAnswer(answer) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 104),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: BirdySpace.s,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: circle,
                        shape: BoxShape.circle,
                        border:
                            ring == null
                                ? null
                                : Border.all(color: ring, width: 2),
                      ),
                      child: Icon(icon, size: 26, color: iconColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: BirdyText.labelCompact.copyWith(color: c.text1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Same height for the three, the tallest label's.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button(
            answer: ReviewAnswer.itIsNot,
            label: l10n.forkReviewItIsNot,
            icon: AppIcons.close,
            iconColor: c.toCheck.foreground,
            circle: c.surface1,
            ring: c.toCheck.foreground,
            background: c.surface1,
            border: c.borderStrong,
          ),
          const SizedBox(width: 10),
          button(
            answer: ReviewAnswer.dontKnow,
            label: l10n.forkReviewDontKnow,
            icon: AppIcons.question,
            iconColor: c.probable.foreground,
            circle: c.probable.background,
            background: c.surface1,
            border: c.borderStrong,
          ),
          const SizedBox(width: 10),
          button(
            answer: ReviewAnswer.itIs,
            label: l10n.forkReviewItIs,
            icon: AppIcons.check,
            iconColor: BirdyBrand.ink,
            circle: BirdyBrand.lichen,
            background: c.sure.background,
            border: c.sure.background,
          ),
        ],
      ),
    );
  }
}

/// Nothing left: empty queue or all sorted.
class ReviewAllDone extends StatelessWidget {
  const ReviewAllDone({super.key, required this.sorted});

  final int sorted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: BirdyBrand.lichen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.check,
                size: 40,
                color: BirdyBrand.ink,
              ),
            ),
            const SizedBox(height: BirdySpace.l),
            Text(
              sorted == 0
                  ? l10n.forkQuickReviewEmpty
                  : l10n.forkQuickReviewDone,
              textAlign: TextAlign.center,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
            if (sorted > 0) ...[
              const SizedBox(height: BirdySpace.s),
              Text(
                l10n.forkQuickReviewSorted(sorted),
                textAlign: TextAlign.center,
                style: BirdyText.body.copyWith(color: c.text2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
