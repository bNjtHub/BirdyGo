/// Sound library: every species with recorded clips, then all clips of a
/// species sorted by score or date, with favorites (fork/PLAN.md J2).
///
/// Clips are never deleted here; favorites only mark the best recordings.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/history/widgets/clip_player_sheet.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';

/// Localized common name, falling back to the name stored with the clip.
String _speciesName(WidgetRef ref, String scientificName, String fallback) {
  final locale = ref.watch(effectiveSpeciesLocaleProvider);
  return ref
          .watch(taxonomyServiceProvider)
          .value
          ?.lookup(scientificName)
          ?.commonNameForLocale(locale) ??
      fallback;
}

/// List of species that have recordings.
class SoundLibraryScreen extends ConsumerWidget {
  const SoundLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.watch(observationIndexServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forkSoundLibrary)),
      body: FutureBuilder(
        // Re-queried whenever the index notifies (session saved, rebuilt).
        future: service.ensureReady().then((index) => index.speciesWithClips()),
        builder: (context, snapshot) {
          final species = snapshot.data;
          if (species == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (species.isEmpty) {
            return _EmptyMessage(text: l10n.forkSoundLibraryEmpty);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: species.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = species[i];
              return ListTile(
                minTileHeight: 56,
                leading: const Icon(AppIcons.graphicEqRounded),
                title: Text(_speciesName(ref, s.scientificName, s.commonName)),
                subtitle: Text(
                  s.favorites > 0
                      ? l10n.forkSoundLibraryCountsWithFavorites(
                        s.clips,
                        s.favorites,
                      )
                      : l10n.forkSoundLibraryCounts(s.clips),
                ),
                trailing: const Icon(AppIcons.chevronRight),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => SpeciesClipsScreen(
                              scientificName: s.scientificName,
                              fallbackName: s.commonName,
                            ),
                      ),
                    ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Every clip of one species.
class SpeciesClipsScreen extends ConsumerStatefulWidget {
  const SpeciesClipsScreen({
    super.key,
    required this.scientificName,
    required this.fallbackName,
  });

  final String scientificName;
  final String fallbackName;

  @override
  ConsumerState<SpeciesClipsScreen> createState() => _SpeciesClipsScreenState();
}

class _SpeciesClipsScreenState extends ConsumerState<SpeciesClipsScreen> {
  bool _byDate = false;
  bool _favoritesOnly = false;
  late Future<(List<IndexedDetection>, Set<String>)> _clips = _load();

  Future<(List<IndexedDetection>, Set<String>)> _load() async {
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    final clips = await index.clipsForSpecies(
      widget.scientificName,
      byDate: _byDate,
      favoritesOnly: _favoritesOnly,
    );
    return (clips, await index.favoriteKeys());
  }

  void _reload() => setState(() => _clips = _load());

  Future<void> _toggleFavorite(IndexedDetection clip, bool favorite) async {
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    await index.setFavorite(clip.key, favorite: favorite);
    _reload();
  }

  void _play(IndexedDetection clip, String name) {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = _speciesName(ref, widget.scientificName, widget.fallbackName);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();
    final scoreFormat = NumberFormat('0.00', locale);

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.forkSoundLibraryByScore),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.forkSoundLibraryByDate),
                    ),
                  ],
                  selected: {_byDate},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    _byDate = value.first;
                    _reload();
                  },
                ),
                FilterChip(
                  label: Text(l10n.forkSoundLibraryFavoritesOnly),
                  selected: _favoritesOnly,
                  onSelected: (value) {
                    _favoritesOnly = value;
                    _reload();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder(
              future: _clips,
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final (clips, favorites) = data;
                if (clips.isEmpty) {
                  return _EmptyMessage(
                    text:
                        _favoritesOnly
                            ? l10n.forkSoundLibraryNoFavorites
                            : l10n.forkSoundLibraryEmpty,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: clips.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final clip = clips[i];
                    final isFavorite = favorites.contains(clip.key);
                    final place = _place(clip, west: l10n.forkWestLetter);
                    return ListTile(
                      minTileHeight: 64,
                      leading: IconButton.filledTonal(
                        tooltip: l10n.forkReplay,
                        icon: const Icon(AppIcons.playArrow),
                        onPressed: () => _play(clip, name),
                      ),
                      title: Text(
                        dateFormat.format(clip.start.toLocal()),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      subtitle: Text(
                        [
                          l10n.forkSoundLibraryScore(
                            scoreFormat.format(clip.confidence),
                          ),
                          if (place != null) place,
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip:
                            isFavorite
                                ? l10n.forkSoundLibraryUnfavorite
                                : l10n.forkSoundLibraryFavorite,
                        icon: Icon(
                          AppIcons.star,
                          fill: isFavorite ? 1 : 0,
                          color:
                              isFavorite
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _toggleFavorite(clip, !isFavorite),
                      ),
                      onTap: () => _play(clip, name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Short coordinates ("47.21° N, 1.55° W"), or null without a position.
  static String? _place(IndexedDetection clip, {required String west}) {
    final lat = clip.latitude;
    final lon = clip.longitude;
    if (lat == null || lon == null) return null;
    String part(double v, String pos, String neg) =>
        '${v.abs().toStringAsFixed(2)}° ${v >= 0 ? pos : neg}';
    return '${part(lat, 'N', 'S')}, ${part(lon, 'E', west)}';
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
