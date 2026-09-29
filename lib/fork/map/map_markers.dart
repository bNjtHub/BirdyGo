/// Marker looks of the contact map (fork/DESIGN.md « Carte », J6g-f): the
/// species marker, the cluster bubble and the user's position. Pure views:
/// colors and sizes come from [BirdyMapStyle] and [BirdyColors], no provider.
library;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/species_avatar.dart' as birdy;

/// A species at a spot: disc with a Martin-pêcheur ring (Loriot when its spot
/// is selected), the photo inside, and the number of contacts in a badge.
class SpeciesMarkerView extends StatelessWidget {
  const SpeciesMarkerView({
    super.key,
    required this.image,
    required this.count,
    required this.selected,
  });

  final ImageProvider? image;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          key: const ValueKey('map-marker-disc'),
          width: BirdyMapStyle.markerDisc,
          height: BirdyMapStyle.markerDisc,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BirdyMapStyle.disc,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: selected ? c.oriole : c.accent,
                spreadRadius: BirdyMapStyle.markerRing,
              ),
              ...BirdyMapStyle.lift,
            ],
          ),
          child: birdy.SpeciesAvatar(
            image: image,
            size: BirdyMapStyle.markerPhoto,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            key: const ValueKey('map-marker-badge'),
            constraints: const BoxConstraints(
              minWidth: BirdyMapStyle.badgeHeight,
            ),
            height: BirdyMapStyle.badgeHeight,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BirdyMapStyle.badge,
              borderRadius: BorderRadius.circular(BirdyRadii.pill),
            ),
            child: Text(
              '$count',
              style: BirdyText.badge.copyWith(
                color: BirdyMapStyle.onBadge,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Several markers close together: a Martin-pêcheur disc with the number of
/// species and its unit (« espèces ») under it.
class ClusterBubbleView extends StatelessWidget {
  const ClusterBubbleView({
    super.key,
    required this.species,
    required this.unit,
  });

  final int species;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      key: const ValueKey('map-cluster-disc'),
      width: BirdyMapStyle.cluster,
      height: BirdyMapStyle.cluster,
      decoration: BoxDecoration(
        color: c.accent,
        shape: BoxShape.circle,
        border: Border.all(
          color: BirdyMapStyle.disc,
          width: BirdyMapStyle.clusterBorder,
        ),
        boxShadow: BirdyMapStyle.lift,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$species',
                style: BirdyText.numberM.copyWith(
                  color: BirdyMapStyle.onCluster,
                  height: 1,
                ),
              ),
              Text(
                unit,
                style: BirdyText.caption.copyWith(
                  color: BirdyMapStyle.onCluster,
                  fontSize: BirdyMapStyle.clusterLabelSize,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The user's position: a Martin-pêcheur dot with a white border and a soft,
/// still halo (no endless animation on the map).
class UserDotView extends StatelessWidget {
  const UserDotView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.accent.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Container(
          width: BirdyMapStyle.userDot,
          height: BirdyMapStyle.userDot,
          decoration: BoxDecoration(
            color: c.accent,
            shape: BoxShape.circle,
            border: Border.all(
              color: BirdyMapStyle.disc,
              width: BirdyMapStyle.userDotBorder,
            ),
            boxShadow: const [
              BoxShadow(color: BirdyMapStyle.shadow, blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
