/// Visuals of the notebook cards (J6e). The one place the species icons of
/// J6d will plug in: until then, the bundled photo for a species, and the
/// BirdyGo bird silhouette for a mystery card (J6f-b: never a species-giving
/// icon).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../design/birdy_tokens.dart';
import '../design/species_accents.dart';
import '../design/widgets/species_avatar.dart';
import '../game/game_config.dart';
import 'notebook_model.dart';
import '../design/birdy_icons.dart';

abstract final class NotebookVisuals {
  /// A species heard: photo on the species tint, grey when [muted]. A rare
  /// species wears a metal ring like the badge medals (silver for an
  /// uncommon one, gold for a rare or exceptional one), and [badge] marks
  /// its state (a check for a discovery, a question mark to confirm).
  /// The box is always [size] wide and high.
  static Widget species(
    WidgetRef ref,
    String scientificName, {
    required double size,
    bool muted = false,
    RarityMark rarity = RarityMark.none,
    NotebookBadge badge = NotebookBadge.none,
  }) {
    final path = ref
        .watch(taxonomyServiceProvider)
        .value
        ?.assetImagePath(scientificName);
    final metal = metalOf(rarity);
    final tint = SpeciesAccents.tintOf(scientificName);
    Widget avatar = SpeciesAvatar(
      image: path == null ? null : AssetImage(path),
      tint: tint,
      size: metal == null ? size : size - 2 * (_ringWidth + _ringGap),
      muted: muted,
    );
    if (metal != null) {
      avatar = DecoratedBox(
        key: const ValueKey('notebook-metal-ring'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: metal.base, width: _ringWidth),
        ),
        child: Padding(padding: const EdgeInsets.all(_ringGap), child: avatar),
      );
    }
    if (badge == NotebookBadge.none) return avatar;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          PositionedDirectional(
            bottom: -2,
            end: -2,
            child: _StateBadge(badge: badge),
          ),
        ],
      ),
    );
  }

  static const double _ringWidth = 3;
  static const double _ringGap = 2;

  /// Metal of a rarity mark: silver (uncommon), gold (rare, exceptional).
  static MedalMetal? metalOf(RarityMark mark) => switch (mark) {
    RarityMark.none => null,
    RarityMark.uncommon => GameConfig.badgeMedals[1],
    RarityMark.rare || RarityMark.exceptional => GameConfig.badgeMedals[2],
  };

  /// A species not found yet: the BirdyGo bird silhouette, which never
  /// gives the species away. [scientificName] is there for the J6d icons
  /// (their silhouette).
  static Widget mystery(String scientificName, {required double size}) =>
      SpeciesAvatar(size: size, mystery: true);
}

/// State mark on a notebook photo.
enum NotebookBadge { none, discovered, toConfirm }

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.badge});

  final NotebookBadge badge;

  static const double _size = 22;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final discovered = badge == NotebookBadge.discovered;
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: discovered ? BirdyBrand.checkGreen : c.toCheck.foreground,
          border: Border.all(color: c.surface1, width: BirdyStroke.regular),
        ),
        child: BirdyIcon(
          discovered ? BirdyIcons.tick : BirdyIcons.help,
          size: BirdyGlyph.xxs,
          color: BirdyBrand.white,
        ),
      ),
    );
  }
}
