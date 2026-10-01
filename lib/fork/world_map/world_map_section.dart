/// Wires `WorldMapBlock` to its data (J7): GBIF observations when the
/// online-map consent is given and GBIF answers, else the geo-model estimate. A skeleton of the final
/// shape while it loads, then a cross-fade; nothing at all when neither is
/// available.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/widgets/birdy_cross_fade.dart';
import '../species_sheet/species_sheet.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../licenses/content_licenses_screen.dart';
import 'world_map_block.dart';
import 'world_map_config.dart';
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
    final presence = ref.watch(worldMapDataProvider(scientificName));
    final outline = ref.watch(landOutlineProvider);
    final consent = ref.watch(privacyAllowMapProvider);
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
        presence: presence.value!.presence,
        source: presence.value!.source,
        onGbifTap: () => openExternalUrl(context, WorldMapConfig.gbifSiteUrl),
        onLicenseTap: () => _openLicenses(context),
        onOnlineHintTap:
            consent ? null : () => _openSettings(context),
        currentMonth: currentMonth,
        user: user,
        nesting: nesting,
      );
    }
    return BirdyCrossFade(child: child);
  }

  /// The online-map consent is in Settings, Privacy.
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  /// The licenses page holds the GBIF attribution and the citation.
  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ContentLicensesScreen()),
    );
  }
}
