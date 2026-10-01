/// Wires `WorldMapBlock` to its data (J7): the bundled GBIF range when the
/// species is in it, else the geo-model estimate. A skeleton of the final
/// shape while it loads, then a cross-fade; nothing at all when neither is
/// available.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/widgets/birdy_cross_fade.dart';
import '../species_sheet/species_sheet.dart';
import '../../shared/services/link_launcher.dart';
import '../licenses/content_licenses_screen.dart';
import 'world_map_block.dart';
import 'world_map_config.dart';
import 'world_map_providers.dart';

class WorldMapSection extends ConsumerWidget {
  const WorldMapSection({
    super.key,
    required this.scientificName,
    this.nesting,
  });

  final String scientificName;
  final NestingPeriod? nesting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(worldMapDataProvider(scientificName));
    final regions = ref.watch(worldRegionsProvider);
    final user = ref.watch(worldMapUserPositionProvider).asData?.value;
    final Widget child;
    if (presence.hasError || regions.hasError) {
      child = const SizedBox.shrink(key: ValueKey('world-map-hidden'));
    } else if (presence.isLoading || regions.isLoading) {
      child = KeyedSubtree(
        key: const ValueKey('world-map-skeleton'),
        child: WorldMapBlock.skeleton(context),
      );
    } else if (presence.value == null || regions.value == null) {
      child = const SizedBox.shrink(key: ValueKey('world-map-hidden'));
    } else {
      child = WorldMapBlock(
        key: const ValueKey('world-map-real'),
        regions: regions.value!,
        classes: presence.value!.classes,
        source: presence.value!.source,
        generation: presence.value!.generation,
        onGbifTap: () => openExternalUrl(context, WorldMapConfig.gbifSiteUrl),
        onLicenseTap: () => _openLicenses(context),
        user: user,
        nesting: nesting,
      );
    }
    return BirdyCrossFade(child: child);
  }

  /// The licenses page holds the GBIF attribution and the citation.
  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ContentLicensesScreen()),
    );
  }
}
