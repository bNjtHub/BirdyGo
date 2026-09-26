/// Providers for the generated J6d species icon catalog.
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'species_icon_index.dart';

/// Overridable so tests can use a tiny in-memory bundle.
final speciesIconAssetBundleProvider = Provider<AssetBundle>(
  (ref) => rootBundle,
);

/// Persistent for the process: the immutable index is read only once.
final speciesIconIndexProvider = FutureProvider<SpeciesIconIndex>((ref) async {
  final bundle = ref.watch(speciesIconAssetBundleProvider);
  final index = SpeciesIconIndex.fromJson(
    await bundle.loadString(speciesIconsIndexAsset),
  );
  // flutter_svg defaults to 100 and keys decoded assets by SVG theme. Leave
  // room for both brightnesses without shrinking a cache another feature set.
  svg.cache.maximumSize = math.max(svg.cache.maximumSize, index.assetCount * 2);
  return index;
});
