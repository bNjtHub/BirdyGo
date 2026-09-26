/// Bottom sheets of the contact map: species in an area, filters and base
/// map choice (fork/PLAN.md J5, fork/maquette/Carte.dc.html).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../features/history/widgets/clip_player_sheet.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import 'base_layers.dart';
import 'contact_map_data.dart';

/// Common name of [scientificName] in the species language, falling back
/// to the name stored with the detection.
String localizedSpeciesName(
  WidgetRef ref,
  String scientificName,
  String fallback,
) {
  final taxonomy = ref.watch(taxonomyServiceProvider).value;
  final locale = ref.watch(effectiveSpeciesLocaleProvider);
  return taxonomy?.lookup(scientificName)?.commonNameForLocale(locale) ??
      fallback;
}

/// Round species photo, as in the survey map markers.
class SpeciesAvatar extends ConsumerWidget {
  const SpeciesAvatar({
    super.key,
    required this.scientificName,
    this.size = 44,
  });

  final String scientificName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path =
        ref
            .watch(taxonomyServiceProvider)
            .value
            ?.assetImagePath(scientificName) ??
        'assets/images/dummy_species.png';
    final theme = Theme.of(context);
    return ClipOval(
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder:
            (_, _, _) => Container(
              width: size,
              height: size,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(AppIcons.brokenImage, size: size * 0.45),
            ),
      ),
    );
  }
}

/// Shows the species heard in an area (a hexagon or a spot).
Future<void> showAreaSheet(
  BuildContext context, {
  required List<SpeciesInArea> species,
  required String filterSummary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AreaSheet(species: species, filterSummary: filterSummary),
  );
}

class _AreaSheet extends ConsumerWidget {
  const _AreaSheet({required this.species, required this.filterSummary});

  final List<SpeciesInArea> species;
  final String filterSummary;

  void _play(BuildContext context, IndexedDetection clip, String name) {
    showClipPlayerSheet(
      context,
      detection: DetectionRecord(
        scientificName: clip.scientificName,
        commonName: name,
        confidence: clip.confidence,
        timestamp: clip.start,
        endTimestamp: clip.end,
        audioClipPath: clip.clipPath,
        latitude: clip.latitude,
        longitude: clip.longitude,
        reviewStatus: clip.reviewStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final contacts = species.fold<int>(0, (sum, s) => sum + s.contacts);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.forkMapAreaTitle(species.length, contacts),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              filterSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: species.length,
                itemBuilder: (context, i) {
                  final s = species[i];
                  final name = localizedSpeciesName(
                    ref,
                    s.scientificName,
                    s.commonName,
                  );
                  final clip = s.bestClip;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 56,
                    leading: SpeciesAvatar(scientificName: s.scientificName),
                    title: Text(name),
                    subtitle: Text(
                      l10n.forkMapContacts(s.contacts),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    trailing:
                        clip == null
                            ? null
                            : IconButton.filledTonal(
                              tooltip: '${l10n.forkReplay} : $name',
                              icon: const Icon(AppIcons.playArrowRounded),
                              onPressed: () => _play(context, clip, name),
                            ),
                    onTap:
                        () => SpeciesInfoOverlay.show(
                          context,
                          ref,
                          scientificName: s.scientificName,
                          commonName: name,
                        ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  AppIcons.lockOutline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.forkMapPrivacyNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Result of the species picker: a species, or every species.
class SpeciesChoice {
  const SpeciesChoice(this.scientificName, this.commonName);

  /// Every species.
  const SpeciesChoice.all() : scientificName = null, commonName = null;

  final String? scientificName;
  final String? commonName;
}

/// Lets the user search and pick a species among [tallies]. Returns null
/// when dismissed.
Future<SpeciesChoice?> showSpeciesPicker(
  BuildContext context, {
  required List<SpeciesTally> tallies,
}) {
  return showModalBottomSheet<SpeciesChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SpeciesPicker(tallies: tallies),
  );
}

class _SpeciesPicker extends ConsumerStatefulWidget {
  const _SpeciesPicker({required this.tallies});

  final List<SpeciesTally> tallies;

  @override
  ConsumerState<_SpeciesPicker> createState() => _SpeciesPickerState();
}

class _SpeciesPickerState extends ConsumerState<_SpeciesPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _query.trim().toLowerCase();
    final entries = [
      for (final t in widget.tallies)
        (
          tally: t,
          name: localizedSpeciesName(ref, t.scientificName, t.commonName),
        ),
    ];
    final shown = [
      for (final e in entries)
        if (query.isEmpty ||
            e.name.toLowerCase().contains(query) ||
            e.tally.scientificName.toLowerCase().contains(query))
          e,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(AppIcons.search),
                  hintText: l10n.forkMapSearchSpecies,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (query.isEmpty)
                    ListTile(
                      minTileHeight: 56,
                      title: Text(l10n.forkMapAllSpecies),
                      onTap:
                          () =>
                              Navigator.pop(context, const SpeciesChoice.all()),
                    ),
                  for (final e in shown)
                    ListTile(
                      minTileHeight: 56,
                      leading: SpeciesAvatar(
                        scientificName: e.tally.scientificName,
                        size: 40,
                      ),
                      title: Text(e.name),
                      trailing: Text(
                        '${e.tally.contacts}',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      onTap:
                          () => Navigator.pop(
                            context,
                            SpeciesChoice(e.tally.scientificName, e.name),
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user pick one of [options], labelled by [label]. Returns null
/// when dismissed.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T selected,
  required String Function(T option) label,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder:
        (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              RadioGroup<T>(
                groupValue: selected,
                onChanged: (v) => Navigator.pop(context, v),
                child: Column(
                  children: [
                    for (final o in options)
                      RadioListTile<T>(value: o, title: Text(label(o))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
  );
}

/// Label of a base map.
String baseLayerLabel(AppLocalizations l10n, MapBaseLayer layer) =>
    switch (layer) {
      MapBaseLayer.osm => l10n.forkMapLayerOsm,
      MapBaseLayer.ignPlan => l10n.forkMapLayerIgnPlan,
      MapBaseLayer.ignPhoto => l10n.forkMapLayerIgnPhoto,
    };
