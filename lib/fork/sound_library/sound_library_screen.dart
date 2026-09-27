/// Sound library: every species with recorded clips, then all clips of a
/// species sorted by score or date, with favorites (fork/PLAN.md J2).
///
/// Clips are never deleted here; favorites only mark the best recordings.
/// Look of J6c: BirdyGo top bar, photos, chips and the clip play button.
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
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/species_avatar.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';

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

/// Photo of [scientificName] from the bundle, or null.
ImageProvider? _imageOf(WidgetRef ref, String scientificName) {
  final path = ref
      .watch(taxonomyServiceProvider)
      .value
      ?.assetImagePath(scientificName);
  return path == null ? null : AssetImage(path);
}

/// BirdyGo top bar: back button and title (SPEC.md 5.x sub-pages).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return SizedBox(
      height: BirdySizes.topBar,
      child: Row(
        children: [
          BirdyIconButton(
            icon: AppIcons.arrowBackRounded,
            semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page frame shared by both screens: background, safe area, 600 dp
/// column, gutters and the top bar.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_TopBar(title: title), Expanded(child: child)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// List of species that have recordings.
class SoundLibraryScreen extends ConsumerWidget {
  const SoundLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final service = ref.watch(observationIndexServiceProvider);
    return _Page(
      title: l10n.forkSoundLibrary,
      child: FutureBuilder(
        // Re-queried whenever the index notifies (session saved, rebuilt).
        future: service.ensureReady().then((index) => index.speciesWithClips()),
        builder: (context, snapshot) {
          final species = snapshot.data;
          if (species == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (species.isEmpty) {
            return BirdyEmptyState(
              icon: AppIcons.libraryMusic,
              title: l10n.forkSoundLibraryEmptyTitle,
              body: l10n.forkSoundLibraryEmpty,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: BirdySpace.s,
              bottom: BirdySpace.xxl,
            ),
            itemCount: species.length,
            itemBuilder: (context, i) {
              final s = species[i];
              final name = _speciesName(ref, s.scientificName, s.commonName);
              return InkWell(
                borderRadius: BorderRadius.circular(BirdyRadii.thumb),
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: BirdySizes.rowCompact,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: BirdySpace.xs,
                    ),
                    child: Row(
                      children: [
                        SpeciesAvatar(
                          image: _imageOf(ref, s.scientificName),
                          tint: SpeciesAccents.tintOf(s.scientificName),
                          size: 44,
                        ),
                        const SizedBox(width: BirdySpace.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: BirdyText.species.copyWith(
                                  color: c.text1,
                                ),
                              ),
                              Text(
                                s.favorites > 0
                                    ? l10n.forkSoundLibraryCountsWithFavorites(
                                      s.clips,
                                      s.favorites,
                                    )
                                    : l10n.forkSoundLibraryCounts(s.clips),
                                style: BirdyText.caption.copyWith(
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(AppIcons.chevronRight, color: c.text2),
                      ],
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

  void _reload() => setState(() {
    _clips = _load();
  });

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
    final c = BirdyColors.of(context);
    final name = _speciesName(ref, widget.scientificName, widget.fallbackName);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();
    final scoreFormat = NumberFormat('0.00', locale);

    return _Page(
      title: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BirdySpace.s),
            child: Wrap(
              spacing: BirdySpace.s,
              runSpacing: BirdySpace.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final byDate in [false, true])
                  ChoiceChip(
                    label: Text(
                      byDate
                          ? l10n.forkSoundLibraryByDate
                          : l10n.forkSoundLibraryByScore,
                    ),
                    selected: _byDate == byDate,
                    onSelected: (_) {
                      _byDate = byDate;
                      _reload();
                    },
                  ),
                FilterChip(
                  avatar: Icon(
                    AppIcons.star,
                    fill: 1,
                    size: 18,
                    color: c.orioleText,
                  ),
                  label: Text(l10n.forkSoundLibraryFavoritesOnly),
                  selected: _favoritesOnly,
                  showCheckmark: false,
                  onSelected: (value) {
                    _favoritesOnly = value;
                    _reload();
                  },
                ),
              ],
            ),
          ),
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
                  return _favoritesOnly
                      ? BirdyEmptyState(
                        kind: BirdyEmptyKind.filtered,
                        icon: AppIcons.star,
                        title: l10n.forkSoundLibraryNoFavoritesTitle,
                        body: l10n.forkSoundLibraryNoFavorites,
                        action: l10n.forkSoundLibraryAllClips,
                        onAction: () => setState(() => _favoritesOnly = false),
                      )
                      : BirdyEmptyState(
                        icon: AppIcons.libraryMusic,
                        title: l10n.forkSoundLibraryEmptyTitle,
                        body: l10n.forkSoundLibraryEmpty,
                      );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: BirdySpace.xxl),
                  itemCount: clips.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
                  itemBuilder: (context, i) {
                    final clip = clips[i];
                    final isFavorite = favorites.contains(clip.key);
                    final place = _place(clip, west: l10n.forkWestLetter);
                    return InkWell(
                      onTap: () => _play(clip, name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: BirdySpace.s,
                        ),
                        child: Row(
                          children: [
                            ClipPlayButton(
                              state: ClipPlayState.idle,
                              semanticLabel: '${l10n.forkReplay} : $name',
                              onPressed: () => _play(clip, name),
                            ),
                            const SizedBox(width: BirdySpace.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateFormat.format(clip.start.toLocal()),
                                    style: BirdyText.bodyCompact.copyWith(
                                      color: c.text1,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    [
                                      l10n.forkSoundLibraryScore(
                                        scoreFormat.format(clip.confidence),
                                      ),
                                      if (place != null) place,
                                    ].join(' · '),
                                    style: BirdyText.caption.copyWith(
                                      color: c.text2,
                                    ),
                                  ),
                                  const SizedBox(height: BirdySpace.xs),
                                  _ClipLevel(clip: clip),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  isFavorite
                                      ? l10n.forkSoundLibraryUnfavorite
                                      : l10n.forkSoundLibraryFavorite,
                              icon: Icon(
                                AppIcons.star,
                                fill: isFavorite ? 1 : 0,
                                color: isFavorite ? c.orioleText : c.text2,
                              ),
                              onPressed:
                                  () => _toggleFavorite(clip, !isFavorite),
                            ),
                          ],
                        ),
                      ),
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

/// Reliability badge of a clip, at its own place and week (J3).
class _ClipLevel extends ConsumerWidget {
  const _ClipLevel({required this.clip});

  final IndexedDetection clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<GeoPresence?>(
      future: ref
          .read(geoPresenceServiceProvider)
          .presenceAt(
            clip.scientificName,
            latitude: clip.latitude,
            longitude: clip.longitude,
            time: clip.start,
          ),
      builder:
          (context, snapshot) => ReliabilityBadge(
            level: reliabilityFor(
              score: clip.confidence,
              review: clip.reviewStatus,
              presence: snapshot.data,
            ),
            unexpected: snapshot.data?.unexpected ?? false,
            score: clip.confidence,
          ),
    );
  }
}
