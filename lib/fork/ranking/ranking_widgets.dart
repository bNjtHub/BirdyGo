/// Pieces of the palmarès (J6c, SPEC.md 9.12): header, period chips,
/// podium and the rows under it.
library;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';

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
        Text(caption, style: BirdyText.caption.copyWith(color: c.text2)),
      ],
    );
  }
}

/// Rank disc colors: gold, silver, bronze (SPEC.md 9.12).
Color _discColor(BirdyColors c, int rank) => switch (rank) {
  1 => BirdyBrand.oriole,
  2 => c.line,
  _ => c.rarityMuted.withValues(alpha: 0.25),
};

/// The first three, second on the left and third on the right.
class RankingPodium extends StatelessWidget {
  const RankingPodium({super.key, required this.top, required this.onOpen});

  /// One to three species, best first.
  final List<RankedSpecies> top;
  final void Function(RankedSpecies species) onOpen;

  @override
  Widget build(BuildContext context) {
    // Visual order: 2, 1, 3. Heights follow the rank.
    const heights = {1: 184.0, 2: 150.0, 3: 136.0};
    final slots = [if (top.length > 1) 2, 1, if (top.length > 2) 3];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, rank) in slots.indexed) ...[
          if (i > 0) const SizedBox(width: BirdySpace.s),
          Expanded(
            child: _PodiumStep(
              rank: rank,
              species: top[rank - 1],
              minHeight: heights[rank]!,
              onTap: () => onOpen(top[rank - 1]),
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
    return Semantics(
      button: true,
      label: '$rank. ${species.name}, ${species.value} ${species.unit}',
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: tint.cardBackground(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(BirdyRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _discColor(c, rank),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$rank',
                        style: BirdyText.labelCompact.copyWith(
                          color: BirdyBrand.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    SpeciesAvatar(
                      image: species.image,
                      scientificName: species.scientificName,
                      tint: tint,
                      size: rank == 1 ? 80 : 64,
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      species.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BirdyText.speciesCompact.copyWith(color: c.text1),
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
            ),
          ),
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
    required this.onTap,
  });

  final int rank;
  final RankedSpecies species;

  /// Value over the leader's, 0 to 1.
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(species.scientificName);
    return Semantics(
      button: true,
      label: '$rank. ${species.name}, ${species.value} ${species.unit}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
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
                SpeciesAvatar(
                  image: species.image,
                  scientificName: species.scientificName,
                  tint: tint,
                  size: 36,
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(BirdyRadii.pill),
                        child: SizedBox(
                          height: 8,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: c.line),
                              FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: fraction.clamp(0.02, 1),
                                child: ColoredBox(color: tint.deep),
                              ),
                            ],
                          ),
                        ),
                      ),
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
