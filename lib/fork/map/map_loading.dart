/// Loading state of the contact map (J6g-f): while the contacts load, the map
/// area shows a skeleton shaped like the area sheet (title, summary line and
/// three species rows) instead of a spinner. Static: a skeleton never
/// animates, so it needs no reduced-motion branch.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_skeleton.dart';

/// Number of placeholder species rows.
const int kMapSkeletonRows = 3;

/// Announced once by screen readers while the map data loads.
class MapLoadingSkeleton extends StatelessWidget {
  const MapLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Semantics(
      liveRegion: true,
      label: l10n.forkMapLoading,
      child: ColoredBox(
        color: c.backgroundDeep,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.page,
              BirdySpace.page,
              BirdySpace.page,
              BirdySpace.xxxl,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(BirdyRadii.hero),
                boxShadow: c.floatShadow,
              ),
              child: const Padding(
                padding: EdgeInsets.all(BirdySpace.l),
                child: MapSheetSkeleton(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Same shape as the area sheet content: heading, caption, species rows.
class MapSheetSkeleton extends StatelessWidget {
  const MapSheetSkeleton({super.key, this.rows = kMapSkeletonRows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      key: const ValueKey('map-loading-skeleton'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BirdySkeleton.text(
          BirdyText.heading.copyWith(color: c.text1),
          placeholder: '00000000000000000000',
        ),
        const SizedBox(height: BirdySpace.xs),
        BirdySkeleton.text(BirdyText.caption, placeholder: '0000000000'),
        const SizedBox(height: BirdySpace.m),
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: BirdySpace.s),
          const _RowSkeleton(),
        ],
      ],
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    const avatar = 40 + 2 * BirdyMapStyle.avatarRing * 2;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.rowCompact),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BirdySpace.m,
            vertical: BirdySpace.s,
          ),
          child: Row(
            children: [
              BirdySkeleton.box(
                width: avatar,
                height: avatar,
                radius: avatar / 2,
              ),
              const SizedBox(width: BirdySpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BirdySkeleton.text(
                      BirdyText.species,
                      placeholder: '000000000000',
                    ),
                    BirdySkeleton.text(
                      BirdyText.latinCompact,
                      placeholder: '0000000000',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BirdySpace.s),
              BirdySkeleton.text(BirdyText.numberM, placeholder: '00'),
            ],
          ),
        ),
      ),
    );
  }
}
