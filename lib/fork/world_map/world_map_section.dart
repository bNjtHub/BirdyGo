/// Wires `WorldMapBlock` to the geo-model (J7): a skeleton of the final shape
/// while the four seasons are computed, then a cross-fade; nothing at all when
/// the geo-model is not available.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/widgets/birdy_cross_fade.dart';
import '../species_sheet/species_sheet.dart';
import 'world_map_block.dart';
import 'world_map_providers.dart';

class WorldMapSection extends ConsumerWidget {
  const WorldMapSection({
    super.key,
    required this.scientificName,
    required this.currentMonth,
    this.nesting,
  });

  final String scientificName;
  final int currentMonth;
  final NestingPeriod? nesting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(speciesSeasonPresenceProvider(scientificName));
    final outline = ref.watch(landOutlineProvider);
    final user = ref.watch(worldMapUserPositionProvider).asData?.value;
    final Widget child;
    if (presence.hasError || outline.hasError) {
      child = const SizedBox.shrink(key: ValueKey('world-map-hidden'));
    } else if (presence.isLoading || outline.isLoading) {
      child = KeyedSubtree(
        key: const ValueKey('world-map-skeleton'),
        child: WorldMapBlock.skeleton(context),
      );
    } else if (presence.value == null || outline.value == null) {
      child = const SizedBox.shrink(key: ValueKey('world-map-hidden'));
    } else {
      child = WorldMapBlock(
        key: const ValueKey('world-map-real'),
        outline: outline.value!,
        presence: presence.value!,
        currentMonth: currentMonth,
        user: user,
        nesting: nesting,
      );
    }
    return BirdyCrossFade(child: child);
  }
}
