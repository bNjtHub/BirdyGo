/// Visuals of the notebook cards (J6e). The one place the species icons of
/// J6d will plug in: until then, the bundled photo for a species, and a
/// generic silhouette for a mystery card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../design/species_accents.dart';
import '../design/widgets/species_avatar.dart';

abstract final class NotebookVisuals {
  /// A species heard: photo on the species tint, grey when [muted].
  static Widget species(
    WidgetRef ref,
    String scientificName, {
    required double size,
    bool muted = false,
  }) {
    final path = ref
        .watch(taxonomyServiceProvider)
        .value
        ?.assetImagePath(scientificName);
    return SpeciesAvatar(
      image: path == null ? null : AssetImage(path),
      tint: SpeciesAccents.tintOf(scientificName),
      size: size,
      muted: muted,
    );
  }

  /// A species not found yet: a silhouette that never gives the species
  /// away. [scientificName] is there for the J6d icons (their silhouette).
  static Widget mystery(String scientificName, {required double size}) =>
      SpeciesAvatar(size: size, muted: true);
}
