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
import 'world_map_fullscreen.dart';
import 'world_map_data.dart';
import 'world_map_providers.dart';
import 'world_regions.dart';

class WorldMapSection extends ConsumerStatefulWidget {
  const WorldMapSection({
    super.key,
    required this.scientificName,
    this.speciesName,
    this.nesting,
  });

  final String scientificName;

  /// Name shown in the title of the full-screen map (the scientific name when
  /// unknown).
  final String? speciesName;
  final NestingPeriod? nesting;

  @override
  ConsumerState<WorldMapSection> createState() => _WorldMapSectionState();
}

class _WorldMapSectionState extends ConsumerState<WorldMapSection> {
  /// The page's route transition is over (or there is none): only then is the
  /// real map built, so its paths are not computed while the page slides in.
  bool _settled = true;
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _animation)) return;
    _animation?.removeStatusListener(_onStatus);
    _animation = animation;
    if (animation == null || animation.isCompleted) {
      _settled = true;
    } else {
      _settled = false;
      animation.addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_settled && mounted) {
      setState(() => _settled = true);
    }
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scientificName = widget.scientificName;
    final nesting = widget.nesting;
    final presence = ref.watch(worldMapDataProvider(scientificName));
    final regions = ref.watch(worldRegionsProvider);
    final user = ref.watch(worldMapUserPositionProvider).asData?.value;
    final Widget child;
    if (presence.hasError || regions.hasError) {
      child = const SizedBox.shrink(key: ValueKey('world-map-hidden'));
    } else if (presence.isLoading ||
        regions.isLoading ||
        (!_settled && presence.value != null && regions.value != null)) {
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
        onExpand:
            () => _openFullscreen(
              context,
              regions.value!,
              presence.value!,
              user,
              nesting,
            ),
      );
    }
    return BirdyCrossFade(child: child);
  }

  /// The full-screen, zoomable map, on the app's standard route.
  void _openFullscreen(
    BuildContext context,
    WorldRegions regions,
    WorldMapData data,
    GridCell? user,
    NestingPeriod? nesting,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => WorldMapFullscreen(
              speciesName: widget.speciesName ?? widget.scientificName,
              regions: regions,
              classes: data.classes,
              source: data.source,
              generation: data.generation,
              user: user,
              nesting: nesting,
              onGbifTap:
                  () => openExternalUrl(context, WorldMapConfig.gbifSiteUrl),
              onLicenseTap: () => _openLicenses(context),
            ),
      ),
    );
  }

  /// The licenses page holds the GBIF attribution and the citation.
  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ContentLicensesScreen()),
    );
  }
}
