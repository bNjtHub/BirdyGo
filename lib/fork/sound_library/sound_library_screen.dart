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
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_list_row.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/entrance.dart';
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

/// Placeholder shaped like the final list: hero, chips and one block of
/// rows (species or clip rows).
class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton({this.withHero = false});

  /// Species list only: hero and chips above the block.
  final bool withHero;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('soundLibrarySkeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: BirdySpace.xxl),
      children: [
        if (withHero) ...[
          BirdySkeleton.box(
            width: double.infinity,
            height: BirdySizes.soundHeroDisc + 2 * BirdySpace.xl,
            radius: BirdyRadii.hero,
          ),
          const SizedBox(height: BirdySpace.m),
          BirdySkeleton.box(
            width: double.infinity,
            height: BirdySizes.target,
            radius: BirdyRadii.pill,
          ),
          const SizedBox(height: BirdySpace.m),
          BirdySkeleton.box(
            width: double.infinity,
            height: BirdySizes.row * 5,
            radius: BirdyRadii.card,
          ),
        ] else
          for (var i = 0; i < 6; i++) ...[
            BirdySkeleton.box(
              width: double.infinity,
              height: BirdySizes.row,
              radius: BirdyRadii.card,
            ),
            const SizedBox(height: BirdySpace.s),
          ],
      ],
    );
  }
}

/// Page frame shared by both screens: background, safe area, 600 dp
/// column, gutters and the overlay header.
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
              padding: const EdgeInsets.symmetric(horizontal: BirdySpace.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: BirdySpace.s),
                    child: BirdyOverlayHeader(title: title),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// List of species that have recordings.
class SoundLibraryScreen extends ConsumerStatefulWidget {
  const SoundLibraryScreen({super.key});

  @override
  ConsumerState<SoundLibraryScreen> createState() => _SoundLibraryScreenState();
}

typedef _SpeciesRow =
    ({String scientificName, String commonName, int clips, int favorites});

class _SoundLibraryScreenState extends ConsumerState<SoundLibraryScreen> {
  bool _favoritesOnly = false;
  late final Future<List<_SpeciesRow>> _species = ref
      .read(observationIndexServiceProvider)
      .ensureReady()
      .then((index) => index.speciesWithClips());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Page(
      title: l10n.forkSoundLibrary,
      child: FutureBuilder(
        future: _species,
        builder: (context, snapshot) {
          final species = snapshot.data;
          return BirdyCrossFade(
            child:
                species == null
                    ? const _RowsSkeleton(withHero: true)
                    : species.isEmpty
                    ? BirdyEmptyState(
                      key: const ValueKey('soundLibraryEmpty'),
                      icon: AppIcons.libraryMusic,
                      title: l10n.forkSoundLibraryEmptyTitle,
                      body: l10n.forkSoundLibraryEmpty,
                    )
                    : _content(context, species),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, List<_SpeciesRow> species) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final shown = [
      for (final s in species)
        if (!_favoritesOnly || s.favorites > 0) s,
    ];
    return ListView(
      key: const ValueKey('soundLibraryContent'),
      padding: const EdgeInsets.only(bottom: BirdySpace.xxl),
      children: [
        BirdyEntrance.staggered(
          index: 0,
          child: _Hero(
            recordings: species.fold(0, (n, s) => n + s.clips),
            species: species.length,
            favorites: species.fold(0, (n, s) => n + s.favorites),
          ),
        ),
        const SizedBox(height: BirdySpace.m),
        Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BirdyFilterChip(
              label: l10n.forkSoundLibraryAll,
              selected: !_favoritesOnly,
              selectedColors: BirdyChipColors.ink(c),
              onSelected: () => setState(() => _favoritesOnly = false),
            ),
            BirdyFilterChip(
              leading: Icon(AppIcons.star, fill: 1, color: c.orioleText),
              label: l10n.forkSoundLibraryFavoritesOnly,
              selected: _favoritesOnly,
              selectedColors: BirdyChipColors.ink(c),
              onSelected: () => setState(() => _favoritesOnly = true),
            ),
          ],
        ),
        const SizedBox(height: BirdySpace.m),
        if (shown.isEmpty)
          BirdyEmptyState.inline(
            kind: BirdyEmptyKind.filtered,
            icon: AppIcons.star,
            title: l10n.forkSoundLibraryNoFavoritesTitle,
            body: l10n.forkSoundLibraryNoFavorites,
            action: l10n.forkSoundLibraryAllClips,
            onAction: () => setState(() => _favoritesOnly = false),
          )
        else
          BirdyEntrance.staggered(
            index: 1,
            child: BirdyListBlock(
              key: const ValueKey('soundLibrarySpeciesBlock'),
              children: [
                for (final s in shown)
                  BirdyListRow(
                    avatar: SpeciesAvatar(
                      image: _imageOf(ref, s.scientificName),
                      tint: SpeciesAccents.tintOf(s.scientificName),
                      size: BirdySizes.target,
                    ),
                    title: _speciesName(ref, s.scientificName, s.commonName),
                    titleStyle: BirdyText.species,
                    subtitle:
                        s.favorites > 0
                            ? l10n.forkSoundLibraryCountsWithFavorites(
                              s.clips,
                              s.favorites,
                            )
                            : l10n.forkSoundLibraryCounts(s.clips),
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
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tonal hero: white disc, big recording count baseline-aligned with its
/// label, then species and favorites counts.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.recordings,
    required this.species,
    required this.favorites,
  });

  final int recordings;
  final int species;
  final int favorites;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final label = l10n.forkSoundLibraryHeroLabel(recordings);
    final caption = [
      l10n.forkSoundLibrarySpeciesCount(species),
      l10n.forkSoundLibraryFavoritesCount(favorites),
    ].join(' · ');
    return BirdyBlock(
      key: const ValueKey('soundLibraryHero'),
      tone: BirdyBlockTone.tonal,
      radius: BirdyRadii.hero,
      padding: const EdgeInsets.all(BirdySpace.xl),
      child: Semantics(
        label: '$recordings $label, $caption',
        excludeSemantics: true,
        child: Row(
          children: [
            Container(
              width: BirdySizes.soundHeroDisc,
              height: BirdySizes.soundHeroDisc,
              decoration: BoxDecoration(
                color: c.surface1,
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.graphicEq, size: 36, color: c.accentText),
            ),
            const SizedBox(width: BirdySpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$recordings',
                        style: BirdyText.numberXL.copyWith(color: c.text1),
                      ),
                      const SizedBox(width: BirdySpace.s),
                      Flexible(
                        child: Text(
                          label,
                          style: BirdyText.label.copyWith(color: c.text1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    caption,
                    style: BirdyText.caption.copyWith(color: c.text1),
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
                  BirdyFilterChip(
                    label:
                        byDate
                            ? l10n.forkSoundLibraryByDate
                            : l10n.forkSoundLibraryByScore,
                    selected: _byDate == byDate,
                    onSelected: () {
                      _byDate = byDate;
                      _reload();
                    },
                  ),
                BirdyFilterChip(
                  leading: Icon(AppIcons.star, fill: 1, color: c.orioleText),
                  label: l10n.forkSoundLibraryFavoritesOnly,
                  selected: _favoritesOnly,
                  selectedColors: BirdyChipColors.oriole(c),
                  onSelected: () {
                    _favoritesOnly = !_favoritesOnly;
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
                  return const _RowsSkeleton();
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
                  separatorBuilder:
                      (_, _) => const SizedBox(height: BirdySpace.s),
                  itemBuilder: (context, i) {
                    final clip = clips[i];
                    final isFavorite = favorites.contains(clip.key);
                    final place = _place(clip, west: l10n.forkWestLetter);
                    return BirdyBlock(
                      onTap: () => _play(clip, name),
                      padding: const EdgeInsets.symmetric(
                        horizontal: BirdySpace.m,
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
                          // Material Symbols read `fill` from the icon theme:
                          // a filled star means favorite.
                          IconTheme.merge(
                            data: IconThemeData(fill: isFavorite ? 1 : 0),
                            child: BirdyIconButton(
                              semanticLabel:
                                  isFavorite
                                      ? l10n.forkSoundLibraryUnfavorite
                                      : l10n.forkSoundLibraryFavorite,
                              icon: AppIcons.star,
                              onPressed:
                                  () => _toggleFavorite(clip, !isFavorite),
                            ),
                          ),
                        ],
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
