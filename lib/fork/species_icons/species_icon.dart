/// Small generated species visual with safe loading and fallback behavior.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../shared/utils/app_icons.dart';
import '../design/species_tint.dart';
import 'species_icon_index.dart';
import 'species_icon_providers.dart';

class SpeciesIcon extends ConsumerWidget {
  const SpeciesIcon({
    super.key,
    required this.scientificName,
    required this.size,
    this.muted = false,
  });

  final String scientificName;
  final double size;
  final bool muted;

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = SpeciesTint.neutral;
    late final AsyncValue<SpeciesIconIndex> index;
    late final AssetBundle bundle;
    try {
      index = ref.watch(speciesIconIndexProvider);
      bundle = ref.watch(speciesIconAssetBundleProvider);
    } on StateError {
      return SizedBox.square(dimension: size, child: _fallback(tint));
    }
    Widget visual = index.when(
      data:
          (value) => SvgPicture.asset(
            value.resolve(scientificName).asset,
            bundle: bundle,
            width: size,
            height: size,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _fallback(tint),
          ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _fallback(tint),
    );
    if (muted) {
      visual = Opacity(
        opacity: 0.45,
        child: ColorFiltered(colorFilter: _greyscale, child: visual),
      );
    }
    return SizedBox.square(dimension: size, child: visual);
  }

  Widget _fallback(SpeciesTint tint) =>
      Icon(AppIcons.bird, size: size * 0.72, color: tint.deep, fill: 1);
}
