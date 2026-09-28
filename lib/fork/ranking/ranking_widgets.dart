/// Pieces of the palmarès (J6f-f, `AppPalmares` mockup): header, period
/// chips, podium and the rows under it.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../game/game_widgets.dart' show BadgeMedal;

/// One ranked species, ready to draw.
class RankedSpecies {
  const RankedSpecies({
    required this.scientificName,
    required this.name,
    required this.value,
    required this.unit,
    required this.isNew,
    this.image,
  });

  final String scientificName;
  final String name;

  /// Contacts or days, as sorted.
  final int value;

  /// « contacts », « jours ».
  final String unit;

  /// First heard this year.
  final bool isNew;
  final ImageProvider? image;
}

/// « 17 » « espèces en 30 jours », then « 9 nouvelles en 2026 · du … ».
class RankingHeader extends StatelessWidget {
  const RankingHeader({
    super.key,
    required this.count,
    required this.label,
    required this.caption,
  });

  final int count;

  /// « espèces en 30 jours ».
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: BirdySpace.s,
          children: [
            Text('$count', style: BirdyText.numberXL.copyWith(color: c.text1)),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                label,
                style: BirdyText.body.copyWith(color: c.text1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Capped so its loading skeleton (ranking_screen.dart) can reserve
        // a fixed number of lines instead of however many this sentence
        // (period + new-this-year count) happens to wrap to.
        Text(
          caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
      ],
    );
  }
}

/// A round species visual on a tinted disc with an accent inset ring
/// (mockup: white/light disc, 1.5 to 2 dp ring). [SpeciesAvatar] already
/// draws a photo or a tinted silhouette; this only adds the ring around it.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({
    required this.image,
    required this.tint,
    required this.size,
    required this.discColor,
    required this.ringColor,
    this.ringWidth = 2,
  });

  final ImageProvider? image;
  final SpeciesTint tint;
  final double size;
  final Color discColor;
  final Color ringColor;
  final double ringWidth;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: discColor,
      border: Border.all(color: ringColor, width: ringWidth),
    ),
    child: SpeciesAvatar(image: image, tint: tint, size: size - ringWidth * 2),
  );
}

/// The medal metal of a podium rank: gold (1st), silver (2nd), bronze (3rd),
/// same face, rim and inner ring as [BadgeMedal] (`lib/fork/game`).
class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank});

  final int rank;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) => BadgeMedal(
    tier: 4 - rank,
    size: _size,
    child:
        (ink) => Text(
          '$rank',
          style: BirdyText.labelCompact.copyWith(
            color: ink,
            fontWeight: FontWeight.w800,
          ),
        ),
  );
}

/// Static sparkle marks around the first-place card. Drawn once, never
/// looping: DESIGN.md bans looping scintillation outside the quiz, unlike
/// the mockup's `pm-twinkle` keyframes.
class _PodiumTwinkles extends StatelessWidget {
  const _PodiumTwinkles({required this.colors});

  final List<Color> colors;

  static const List<Alignment> _positions = [
    Alignment(-0.85, -0.85),
    Alignment(0.9, -0.6),
    Alignment(0.75, 0.35),
  ];

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        for (final (i, alignment) in _positions.indexed)
          Align(
            alignment: alignment,
            child: Icon(
              AppIcons.sparkle,
              size: i == 1 ? 10 : 12,
              color: colors[i % colors.length],
              fill: 1,
            ),
          ),
      ],
    ),
  );
}

/// The first three, second on the left and third on the right.
class RankingPodium extends StatelessWidget {
  const RankingPodium({super.key, required this.top, required this.onOpen});

  /// One to three species, best first.
  final List<RankedSpecies> top;
  final void Function(RankedSpecies species) onOpen;

  @override
  Widget build(BuildContext context) {
    // Visual order: 2, 1, 3. Heights follow the rank (AppPalmares mockup).
    const heights = {1: 240.0, 2: 212.0, 3: 196.0};
    final slots = [if (top.length > 1) 2, 1, if (top.length > 2) 3];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, rank) in slots.indexed) ...[
          if (i > 0) const SizedBox(width: BirdySpace.s),
          Expanded(
            child: BirdyEntrance(
              delay: BirdyMotion.podiumPopInDelay[i],
              duration: BirdyMotion.podiumPopIn,
              offset: Offset.zero,
              fromScale: BirdyMotion.appearScale,
              child: _PodiumStep(
                rank: rank,
                species: top[rank - 1],
                minHeight: heights[rank]!,
                onTap: () => onOpen(top[rank - 1]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.rank,
    required this.species,
    required this.minHeight,
    required this.onTap,
  });

  final int rank;
  final RankedSpecies species;
  final double minHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(species.scientificName);
    final first = rank == 1;
    return Semantics(
      button: true,
      label: '$rank. ${species.name}, ${species.value} ${species.unit}',
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: tint.cardBackground(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(BirdyRadii.card),
          clipBehavior: Clip.antiAlias,
          elevation: first ? 3 : 0,
          shadowColor: first ? tint.accent.withValues(alpha: 0.4) : null,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Stack(
                children: [
                  if (first) _PodiumTwinkles(colors: [BirdyBrand.oriole, c.accent, tint.accent]),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _RankMedal(rank: rank),
                        const SizedBox(height: BirdySpace.xs),
                        _RingedAvatar(
                          image: species.image,
                          tint: tint,
                          size: first ? 80 : 60,
                          discColor: c.surface1,
                          ringColor: tint.accent,
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          species.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BirdyText.speciesCompact.copyWith(
                            color: c.text1,
                          ),
                        ),
                        Text(
                          '${species.value}',
                          style: BirdyText.numberM.copyWith(color: c.text1),
                        ),
                        Text(
                          species.unit,
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A proportional bar (rank 4+), growing from 0 to [fraction] once, like a
/// live counter bump rather than the mockup's uncapped per-row stagger
/// (DESIGN.md caps a list's stagger at [BirdyMotion.staggerMaxItems]).
class _RankingBar extends StatefulWidget {
  const _RankingBar({
    required this.fraction,
    required this.index,
    required this.tint,
  });

  final double fraction;
  final int index;
  final SpeciesTint tint;

  @override
  State<_RankingBar> createState() => _RankingBarState();
}

class _RankingBarState extends State<_RankingBar> {
  double _value = 0;
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final target = widget.fraction.clamp(0.02, 1.0);
    if (BirdyMotion.reduced(context)) {
      _value = target;
    } else {
      _timer = Timer(BirdyMotion.staggerDelay(widget.index), () {
        if (mounted) setState(() => _value = target);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(BirdyRadii.pill),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.line),
            AnimatedFractionallySizedBox(
              duration: BirdyMotion.rankingBarGrow,
              curve: BirdyMotion.standard,
              alignment: AlignmentDirectional.centerStart,
              widthFactor: _value,
              child: ColoredBox(color: widget.tint.deep),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rank 4 and below: rank, photo, name over a bar, count.
class RankingRow extends StatelessWidget {
  const RankingRow({
    super.key,
    required this.rank,
    required this.species,
    required this.fraction,
    required this.index,
    required this.onTap,
  });

  final int rank;
  final RankedSpecies species;

  /// Value over the leader's, 0 to 1.
  final double fraction;

  /// Position in the list under the podium (0-based), for the bar's
  /// staggered entrance.
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(species.scientificName);
    final label =
        '$rank. ${species.name}, ${species.value} ${species.unit}'
        '${species.isNew ? ', ${l10n.forkNewThisYear.toLowerCase()}' : ''}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BirdySpace.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rank',
                    style: BirdyText.label.copyWith(color: c.rarityMuted),
                  ),
                ),
                _RingedAvatar(
                  image: species.image,
                  tint: tint,
                  size: 36,
                  discColor: tint.cardBackground(Theme.of(context).brightness),
                  ringColor: tint.accent.withValues(alpha: 0.5),
                  ringWidth: 1.5,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: BirdySpace.s,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            species.name,
                            style: BirdyText.species.copyWith(color: c.text1),
                          ),
                          if (species.isNew)
                            const NoveltyPill(kind: NoveltyKind.newThisYear),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _RankingBar(fraction: fraction, index: index, tint: tint),
                    ],
                  ),
                ),
                const SizedBox(width: BirdySpace.m),
                Text(
                  '${species.value}',
                  style: BirdyText.numberM.copyWith(color: c.text1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

