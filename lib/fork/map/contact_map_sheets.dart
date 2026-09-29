/// Bottom sheets of the contact map: species in an area, filters and base
/// map choice (fork/PLAN.md J5, fork/maquette/Carte.dc.html). Profil style
/// since J6g-f: species tint blocks, ringed photo avatars, Fraunces names,
/// counts as big numbers, tactile 60 dp rows.
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
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_sheet.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/pressable.dart';
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
  return showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AreaSheet(species: species, filterSummary: filterSummary),
  );
}

/// One species of a map sheet, Profil style: a block on the species tint, a
/// photo avatar with an accent ring, the name in Fraunces, the latin name and
/// the count as a big number. The whole left part is one target of at least
/// 60 dp (opens the species page); [trailing] (replay) is its own target.
class MapSpeciesRow extends StatelessWidget {
  const MapSpeciesRow({
    super.key,
    required this.scientificName,
    required this.name,
    required this.count,
    required this.onTap,
    this.trailing,
  });

  final String scientificName;
  final String name;
  final int count;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(scientificName);
    return Material(
      color: tint.cardBackground(Theme.of(context).brightness),
      borderRadius: BorderRadius.circular(BirdyRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              excludeSemantics: true,
              label: '$name, ${l10n.forkMapContacts(count)}',
              child: Pressable(
                child: InkWell(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: BirdySizes.rowCompact,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BirdySpace.m,
                        vertical: BirdySpace.s,
                      ),
                      child: Row(
                        children: [
                          _RingedAvatar(
                            scientificName: scientificName,
                            tint: tint,
                          ),
                          const SizedBox(width: BirdySpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: BirdyText.species.copyWith(
                                    color: c.text1,
                                  ),
                                ),
                                Text(
                                  scientificName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: BirdyText.latinCompact.copyWith(
                                    color: c.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: BirdySpace.s),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: BirdyText.numberM.copyWith(
                                  color: c.text1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                l10n.forkMapContactsUnit(count),
                                style: BirdyText.caption.copyWith(
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: BirdySpace.s),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

/// Photo avatar inside a ring of the species accent.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.scientificName, required this.tint});

  final String scientificName;
  final SpeciesTint tint;

  static const double _photo = 40;

  @override
  Widget build(BuildContext context) {
    const ring = BirdyMapStyle.avatarRing;
    return Container(
      key: const ValueKey('map-avatar-ring'),
      padding: const EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tint.accent, width: ring),
      ),
      child: SpeciesAvatar(scientificName: scientificName, size: _photo),
    );
  }
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
    final c = BirdyColors.of(context);
    final contacts = species.fold<int>(0, (sum, s) => sum + s.contacts);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.page,
          0,
          BirdySpace.page,
          BirdySpace.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.forkMapAreaTitle(species.length, contacts),
                style: BirdyText.heading.copyWith(color: c.text1),
              ),
            ),
            const SizedBox(height: BirdySpace.xs),
            Text(
              filterSummary,
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
            const SizedBox(height: BirdySpace.m),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: species.length,
                separatorBuilder:
                    (_, _) => const SizedBox(height: BirdySpace.s),
                itemBuilder: (context, i) {
                  final s = species[i];
                  final name = localizedSpeciesName(
                    ref,
                    s.scientificName,
                    s.commonName,
                  );
                  final clip = s.bestClip;
                  return MapSpeciesRow(
                    scientificName: s.scientificName,
                    name: name,
                    count: s.contacts,
                    onTap:
                        () => SpeciesInfoOverlay.show(
                          context,
                          ref,
                          scientificName: s.scientificName,
                          commonName: name,
                        ),
                    trailing:
                        clip == null
                            ? null
                            : ClipPlayButton(
                              state: ClipPlayState.idle,
                              semanticLabel: '${l10n.forkReplay} : $name',
                              onPressed: () => _play(context, clip, name),
                            ),
                  );
                },
              ),
            ),
            const SizedBox(height: BirdySpace.m),
            Row(
              children: [
                Icon(AppIcons.lockOutline, size: 16, color: c.text2),
                const SizedBox(width: BirdySpace.s),
                Expanded(
                  child: Text(
                    l10n.forkMapPrivacyNote,
                    style: BirdyText.caption.copyWith(color: c.text2),
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
  return showBirdySheet<SpeciesChoice>(
    context: context,
    isScrollControlled: true,
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
    final c = BirdyColors.of(context);
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
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                0,
                BirdySpace.page,
                BirdySpace.s,
              ),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(AppIcons.search),
                  hintText: l10n.forkMapSearchSpecies,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(BirdyRadii.pill),
                    ),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  BirdySpace.page,
                  BirdySpace.xs,
                  BirdySpace.page,
                  BirdySpace.l + birdySheetBottomInset(context),
                ),
                children: [
                  if (query.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BirdySpace.s),
                      child: Semantics(
                        button: true,
                        excludeSemantics: true,
                        label: l10n.forkMapAllSpecies,
                        child: Pressable(
                          child: Material(
                            color: c.tonal,
                            borderRadius: BorderRadius.circular(
                              BirdyRadii.card,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap:
                                  () => Navigator.pop(
                                    context,
                                    const SpeciesChoice.all(),
                                  ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: BirdySizes.rowCompact,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: BirdySpace.l,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.bird,
                                        color: c.accentText,
                                        fill: 1,
                                      ),
                                      const SizedBox(width: BirdySpace.m),
                                      Expanded(
                                        child: Text(
                                          l10n.forkMapAllSpecies,
                                          style: BirdyText.species.copyWith(
                                            color: c.accentText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (final e in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BirdySpace.s),
                      child: MapSpeciesRow(
                        scientificName: e.tally.scientificName,
                        name: e.name,
                        count: e.tally.contacts,
                        onTap:
                            () => Navigator.pop(
                              context,
                              SpeciesChoice(e.tally.scientificName, e.name),
                            ),
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
/// when dismissed. Rows are 60 dp tactile blocks; the chosen one is tonal
/// with a check.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T selected,
  required String Function(T option) label,
}) {
  return showBirdySheet<T>(
    context: context,
    builder: (context) {
      final c = BirdyColors.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.page,
          0,
          BirdySpace.page,
          BirdySpace.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: BirdyText.heading.copyWith(color: c.text1),
              ),
            ),
            const SizedBox(height: BirdySpace.m),
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(bottom: BirdySpace.s),
                child: _ChoiceRow(
                  label: label(o),
                  selected: o == selected,
                  onTap: () => Navigator.pop(context, o),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      child: Pressable(
        child: Material(
          color: selected ? c.tonal : c.surface2,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: BirdySizes.rowCompact,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BirdySpace.l),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: BirdyText.species.copyWith(
                          color: selected ? c.accentText : c.text1,
                        ),
                      ),
                    ),
                    if (selected) Icon(AppIcons.check, color: c.accentText),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label of a base map.
String baseLayerLabel(AppLocalizations l10n, MapBaseLayer layer) =>
    switch (layer) {
      MapBaseLayer.osm => l10n.forkMapLayerOsm,
      MapBaseLayer.ignPlan => l10n.forkMapLayerIgnPlan,
      MapBaseLayer.ignPhoto => l10n.forkMapLayerIgnPhoto,
    };
