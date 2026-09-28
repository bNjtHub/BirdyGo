/// Map of every contact of every session (fork/PLAN.md J5, layout from
/// fork/maquette/Carte.dc.html).
///
/// Small zooms bin contacts on a hexagon grid and draw each bin as the
/// BirdyGo bird, whose opacity follows the number of contacts (J6f); large
/// zooms show one round bird marker per species and spot, clustered.
/// Tapping a place or a marker opens the species of the area.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart' as birdy;
import '../design/widgets/birdy_cross_fade.dart';
import '../ranking/ranking_logic.dart';
import 'base_layers.dart';
import 'contact_map_data.dart';
import 'contact_map_sheets.dart';
import 'hex_grid.dart';
import 'map_config.dart';
import 'place_bird_layer.dart';

/// Martin-pêcheur (fork/DESIGN.md): places, markers and the user's
/// position.
const Color _kingfisher = BirdyBrand.kingfisher;

/// Encre de nuit and Brume (fork/DESIGN.md): marker count badges.
const Color _ink = BirdyBrand.ink;
const Color _mist = BirdyBrand.mist;

/// Where the map opens when there is nothing to show: France.
const LatLng _defaultCenter = LatLng(46.6, 2.4);
const double _defaultZoom = 5;

/// Full-screen contact map.
class ContactMapScreen extends ConsumerStatefulWidget {
  const ContactMapScreen({
    super.key,
    this.initialSpecies,
    this.showBack = true,
  });

  /// Opens filtered on this species, over every period (species page).
  final SpeciesChoice? initialSpecies;

  /// False in the bottom navigation (J6e): the map is a tab, not a page.
  final bool showBack;

  @override
  ConsumerState<ContactMapScreen> createState() => _ContactMapScreenState();
}

class _ContactMapScreenState extends ConsumerState<ContactMapScreen> {
  final MapController _mapController = MapController();

  late RankingPeriod _period =
      widget.initialSpecies == null
          ? RankingPeriod.last30Days
          : RankingPeriod.all;
  bool _confirmedOnly = false;
  late SpeciesChoice _species =
      widget.initialSpecies ?? const SpeciesChoice.all();
  late MapBaseLayer _layer;
  TileLayer? _tileLayer;

  /// Tiles that failed since the layer was built; past
  /// [kMapTileErrorsBeforeNotice] the map says its background does not load.
  int _tileErrors = 0;
  bool _tilesFailing = false;

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    // The first error names the cause in the log (network, HTTP status…).
    if (_tileErrors++ == 0) {
      debugPrint('[ContactMap] ${_layer.name} tile failed: $error');
    }
    if (_tilesFailing || _tileErrors < kMapTileErrorsBeforeNotice) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tilesFailing) setState(() => _tilesFailing = true);
    });
  }

  void _retryTiles() => setState(() {
    _tileErrors = 0;
    _tilesFailing = false;
    _tileLayer = null;
  });

  ContactMapData? _data;
  int _loadGeneration = 0;
  double _zoom = _defaultZoom;
  bool _mapReady = false;
  LatLng? _userPosition;
  HexKey? _selectedSpot;

  // Layer caches, rebuilt only when the data, the zoom step or the
  // selection change (never per frame).
  (ContactMapData, int)? _placesKey;
  List<PlaceBird> _places = const [];
  (ContactMapData, HexKey?)? _markersKey;
  List<Marker> _markers = const [];

  /// True when no session has any detection yet (not just filtered out).
  bool _indexEmpty = false;

  @override
  void initState() {
    super.initState();
    _layer = MapBaseLayer.fromName(
      ref.read(sharedPreferencesProvider).getString(kMapBaseLayerPref),
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refit = false}) async {
    final generation = ++_loadGeneration;
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    final range = periodRange(_period, DateTime.now());
    final points = await index.mapPoints(
      from: range.from,
      to: range.to,
      confirmedOnly: _confirmedOnly,
      scientificName: _species.scientificName,
    );
    final indexEmpty = points.isEmpty && (await index.counts()).detections == 0;
    if (!mounted || generation != _loadGeneration) return;
    final data = ContactMapData(points);
    setState(() {
      _data = data;
      _indexEmpty = indexEmpty;
      _selectedSpot = null;
    });
    if (refit && _mapReady) _fit(data);
  }

  CameraFit? _cameraFit(ContactMapData data) {
    final positions = data.positions;
    if (positions.length < 2) return null;
    return CameraFit.coordinates(
      coordinates: positions,
      padding: const EdgeInsets.fromLTRB(48, 120, 48, 48),
      maxZoom: kMapSinglePointZoom,
    );
  }

  void _fit(ContactMapData data) {
    final fit = _cameraFit(data);
    if (fit != null) {
      _mapController.fitCamera(fit);
    } else if (!data.isEmpty) {
      _mapController.move(data.positions.first, kMapSinglePointZoom);
    }
  }

  /// Fades [child] in in place: a loaded value replacing its skeleton.
  /// [child]'s own key tells the switcher when to cross-fade.
  static Widget _crossFade(Widget child) => BirdyCrossFade(child: child);

  String _periodLabel(AppLocalizations l10n, RankingPeriod p) => switch (p) {
    RankingPeriod.last30Days => l10n.forkPeriod30Days,
    RankingPeriod.season => l10n.forkPeriodSeason,
    RankingPeriod.year => l10n.forkPeriodYear,
    RankingPeriod.all => l10n.forkPeriodAll,
  };

  String _filterSummary(AppLocalizations l10n) => [
    _periodLabel(l10n, _period),
    if (_confirmedOnly) l10n.forkMapConfirmedOnly,
  ].join(' · ');

  // ── Filters ──────────────────────────────────────────────────────────

  Future<void> _pickSpecies() async {
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    final range = periodRange(_period, DateTime.now());
    final tallies = await index.speciesRanking(
      from: range.from,
      to: range.to,
      confirmedOnly: _confirmedOnly,
    );
    if (!mounted) return;
    final choice = await showSpeciesPicker(context, tallies: tallies);
    if (choice == null || !mounted) return;
    setState(() => _species = choice);
    await _load(refit: true);
  }

  Future<void> _pickPeriod(AppLocalizations l10n) async {
    final period = await showChoiceSheet<RankingPeriod>(
      context,
      title: l10n.forkMapPeriod,
      options: RankingPeriod.values,
      selected: _period,
      label: (p) => _periodLabel(l10n, p),
    );
    if (period == null || period == _period || !mounted) return;
    setState(() => _period = period);
    await _load();
  }

  Future<void> _pickBaseLayer(AppLocalizations l10n) async {
    final layer = await showChoiceSheet<MapBaseLayer>(
      context,
      title: l10n.forkMapBaseLayer,
      options: MapBaseLayer.values,
      selected: _layer,
      label: (l) => baseLayerLabel(l10n, l),
    );
    if (layer == null || layer == _layer || !mounted) return;
    setState(() {
      _layer = layer;
      _tileLayer = null;
      _tileErrors = 0;
      _tilesFailing = false;
    });
    await ref
        .read(sharedPreferencesProvider)
        .setString(kMapBaseLayerPref, layer.name);
  }

  Future<void> _requestTileConsent(AppLocalizations l10n) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.mapTileConsentTitle),
            content: Text(l10n.mapTileConsentBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.mapTileConsentCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.mapTileConsentAllow),
              ),
            ],
          ),
    );
    if (agreed == true) {
      await ref.read(privacyAllowMapProvider.notifier).set(true);
    }
  }

  Future<void> _locate(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final location = await ref
        .read(locationServiceProvider)
        .getCurrentLocation(maxAge: const Duration(minutes: 2));
    if (!mounted) return;
    if (location == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.forkMapLocateFailed)));
      return;
    }
    final position = LatLng(location.latitude, location.longitude);
    setState(() => _userPosition = position);
    _mapController.move(
      position,
      _zoom < kMapSinglePointZoom ? kMapSinglePointZoom : _zoom,
    );
  }

  // ── Areas ────────────────────────────────────────────────────────────

  void _openArea(List<int> indices) {
    final data = _data;
    if (data == null || indices.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    unawaited(
      showAreaSheet(
        context,
        species: data.speciesIn(indices),
        filterSummary: _filterSummary(l10n),
      ).whenComplete(() {
        if (mounted) setState(() => _selectedSpot = null);
      }),
    );
  }

  void _onMapTap(LatLng point) {
    final data = _data;
    if (data == null || _zoom >= kMapMarkersFromZoom) return;
    final bins = data.hexBins(_zoom.floor());
    final cell = bins.cells[bins.grid.keyOf(point)];
    if (cell != null) _openArea(cell);
  }

  void _onSpotTap(ContactSpot spot) {
    final data = _data;
    if (data == null) return;
    setState(() => _selectedSpot = spot.spot);
    _openArea(data.indicesAtSpot(spot.spot));
  }

  // ── Layers ───────────────────────────────────────────────────────────

  List<PlaceBird> _placeBirds(ContactMapData data) {
    final step = _zoom.floor();
    if (_placesKey == (data, step)) return _places;
    final bins = data.hexBins(step);
    _placesKey = (data, step);
    return _places = [
      for (final entry in bins.cells.entries)
        (
          point: bins.grid.center(entry.key),
          opacity: hexOpacity(entry.value.length, bins.maxCount),
        ),
    ];
  }

  /// Distinct species in a cluster (markers are keyed by spot and species).
  static int _clusterSpecies(List<Marker> markers) {
    final species = <Object?>{};
    for (final m in markers) {
      final key = m.key;
      species.add(key is ValueKey<(HexKey, String)> ? key.value.$2 : key);
    }
    return species.length;
  }

  List<Marker> _spotMarkers(ContactMapData data, AppLocalizations l10n) {
    if (_markersKey == (data, _selectedSpot)) return _markers;
    _markersKey = (data, _selectedSpot);
    return _markers = [
      for (final spot in data.spots)
        Marker(
          key: ValueKey((spot.spot, spot.scientificName)),
          point: spot.position,
          width: 56,
          height: 56,
          child: _ContactMarker(
            spot: spot,
            selected: spot.spot == _selectedSpot,
            onTap: () => _onSpotTap(spot),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasConsent = ref.watch(privacyAllowMapProvider);
    // Reload when the index changes (a session was saved or deleted).
    ref.listen(observationIndexServiceProvider, (_, _) => _load());
    final data = _data;
    final showHexes = _zoom < kMapMarkersFromZoom;
    final c = BirdyColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FORK: all four tabs share the same header row (J6f-b phone
            // feedback); the map used to float a white card of its own.
            Padding(
              key: const ValueKey('map-header'),
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.page,
                BirdySpace.page,
                0,
              ),
              child: BirdyTabHeader(
                title: l10n.forkMapTitle,
                captionWidget: _crossFade(
                  data == null
                      ? BirdySkeleton.text(
                        BirdyText.caption,
                        key: const ValueKey('map-caption-skeleton'),
                        placeholder: '00000000000000000000000000',
                      )
                      : Text(
                        l10n.forkMapCaption(
                          _periodLabel(l10n, _period),
                          data.spots.map((s) => s.spot).toSet().length,
                        ),
                        key: const ValueKey('map-caption-real'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BirdyText.caption.copyWith(color: c.text2),
                      ),
                ),
                actions: [
                  if (widget.showBack)
                    BirdyIconButton(
                      icon: AppIcons.arrowBackRounded,
                      semanticLabel:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  BirdyIconButton(
                    icon: AppIcons.layers,
                    semanticLabel: l10n.forkMapBaseLayer,
                    onPressed: () => _pickBaseLayer(l10n),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BirdySpace.block),
            Expanded(
              child: Stack(
                children: [
                  if (data != null)
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter:
                              data.isEmpty
                                  ? _defaultCenter
                                  : data.positions.first,
                          initialZoom:
                              data.isEmpty ? _defaultZoom : kMapSinglePointZoom,
                          initialCameraFit: _cameraFit(data),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerLow,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onMapReady: () {
                            _mapReady = true;
                            setState(() => _zoom = _mapController.camera.zoom);
                          },
                          onPositionChanged: (camera, _) {
                            final wasHexes = _zoom < kMapMarkersFromZoom;
                            final isHexes = camera.zoom < kMapMarkersFromZoom;
                            final stepChanged =
                                _zoom.floor() != camera.zoom.floor();
                            _zoom = camera.zoom;
                            if (wasHexes != isHexes ||
                                (isHexes && stepChanged)) {
                              setState(() {});
                            }
                          },
                          onTap: (_, point) => _onMapTap(point),
                        ),
                        children: [
                          if (hasConsent)
                            _tileLayer ??= buildBaseTileLayer(
                              _layer,
                              onTileError: _onTileError,
                            ),
                          if (showHexes)
                            PlaceBirdLayer(places: _placeBirds(data))
                          else
                            MarkerClusterLayerWidget(
                              options: MarkerClusterLayerOptions(
                                maxClusterRadius: 60,
                                disableClusteringAtZoom: kMapSpotZoom,
                                size: const Size(60, 60),
                                padding: const EdgeInsets.all(50),
                                markers: _spotMarkers(data, l10n),
                                builder:
                                    (context, markers) => _ClusterBubble(
                                      species: _clusterSpecies(markers),
                                    ),
                              ),
                            ),
                          if (_userPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _userPosition!,
                                  width: 32,
                                  height: 32,
                                  child: const _UserDot(),
                                ),
                              ],
                            ),
                          if (hasConsent)
                            RichAttributionWidget(
                              alignment: AttributionAlignment.bottomLeft,
                              attributions: [
                                for (final a in baseLayerAttributions(_layer))
                                  TextSourceAttribution(a),
                              ],
                            ),
                        ],
                      ),
                    )
                  else
                    const Center(child: CircularProgressIndicator()),
                  // Filter chips, notices, empty state and the locate button float
                  // over the map itself, below the shared tab header.
                  Positioned.fill(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            BirdySpace.page,
                            BirdySpace.block,
                            BirdySpace.page,
                            0,
                          ),
                          child: _FilterBar(
                            speciesLabel:
                                _species.commonName ?? l10n.forkMapAllSpecies,
                            speciesSelected: _species.scientificName != null,
                            periodLabel: _periodLabel(l10n, _period),
                            confirmedOnly: _confirmedOnly,
                            onSpecies: _pickSpecies,
                            onPeriod: () => _pickPeriod(l10n),
                            onConfirmed: (v) {
                              setState(() => _confirmedOnly = v);
                              unawaited(_load());
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child:
                              hasConsent
                                  ? _tilesFailing
                                      ? _Notice(
                                        text: l10n.forkMapTilesFailed,
                                        action: l10n.retry,
                                        onAction: _retryTiles,
                                      )
                                      : const SizedBox.shrink()
                                  : _Notice(
                                    text: l10n.forkMapTilesOff,
                                    action: l10n.mapTileConsentAllow,
                                    onAction: () => _requestTileConsent(l10n),
                                  ),
                        ),
                        const Spacer(),
                        if (data != null && data.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  BirdyRadii.card,
                                ),
                                boxShadow: c.floatShadow,
                              ),
                              child:
                                  _indexEmpty
                                      ? BirdyEmptyState.inline(
                                        icon: AppIcons.hearing,
                                        title: l10n.forkMapEmptyTitle,
                                        body: l10n.forkMapEmpty,
                                      )
                                      : BirdyEmptyState.inline(
                                        kind: BirdyEmptyKind.filtered,
                                        icon: AppIcons.searchOff,
                                        title: l10n.forkMapEmptyFilteredTitle,
                                        body: l10n.forkMapEmptyFiltered,
                                      ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                            child: _MapButton(
                              icon: AppIcons.myLocation,
                              tooltip: l10n.forkMapLocateMe,
                              onPressed: () => _locate(l10n),
                            ),
                          ),
                        ),
                      ],
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

/// Filter chips over the map: species, period, confirmed only. White,
/// floating, the chosen one turns tonal (J6f).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.speciesLabel,
    required this.speciesSelected,
    required this.periodLabel,
    required this.confirmedOnly,
    required this.onSpecies,
    required this.onPeriod,
    required this.onConfirmed,
  });

  final String speciesLabel;
  final bool speciesSelected;
  final String periodLabel;
  final bool confirmedOnly;
  final VoidCallback onSpecies;
  final VoidCallback onPeriod;
  final ValueChanged<bool> onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          BirdyFilterChip(
            label: speciesLabel,
            selected: speciesSelected,
            selectedColors: BirdyChipColors.tonal(c),
            floating: true,
            leading: const Icon(AppIcons.expandMore),
            onSelected: onSpecies,
          ),
          const SizedBox(width: BirdySpace.s),
          BirdyFilterChip(
            label: periodLabel,
            selected: true,
            selectedColors: BirdyChipColors.tonal(c),
            floating: true,
            leading: const Icon(AppIcons.expandMore),
            onSelected: onPeriod,
          ),
          const SizedBox(width: BirdySpace.s),
          BirdyFilterChip(
            label: l10n.forkMapConfirmedOnly,
            selected: confirmedOnly,
            selectedColors: BirdyChipColors.tonal(c),
            floating: true,
            leading: confirmedOnly ? const Icon(AppIcons.check) : null,
            onSelected: () => onConfirmed(!confirmedOnly),
          ),
        ],
      ),
    );
  }
}

/// Round 48 dp icon button floating over the map.
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Pressable(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: c.floatShadow,
        ),
        child: Material(
          color: c.surface1,
          shape: CircleBorder(side: BorderSide(color: c.line)),
          child: IconButton(
            tooltip: tooltip,
            icon: Icon(icon, color: c.text1),
            constraints: const BoxConstraints.tightFor(
              width: BirdySizes.target,
              height: BirdySizes.target,
            ),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

/// Short message card over the map, with an optional action.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
        boxShadow: c.floatShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: BirdyText.bodyCompact.copyWith(color: c.text1),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ),
    );
  }
}

/// A species at a spot (SPEC.md 9.14): white disc with a Martin-pêcheur
/// ring (Loriot when its spot is selected), the photo inside, and the
/// number of contacts in a badge.
class _ContactMarker extends ConsumerWidget {
  const _ContactMarker({
    required this.spot,
    required this.selected,
    required this.onTap,
  });

  final ContactSpot spot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final path = ref
        .watch(taxonomyServiceProvider)
        .value
        ?.assetImagePath(spot.scientificName);
    return Semantics(
      button: true,
      selected: selected,
      label: '${spot.commonName} : ${l10n.forkMapContacts(spot.count)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: selected ? BirdyBrand.oriole : _kingfisher,
                      spreadRadius: 3,
                    ),
                    const BoxShadow(
                      color: Color(0x2E13233A),
                      offset: Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: birdy.SpeciesAvatar(
                  image: path == null ? null : AssetImage(path),
                  size: 34,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(BirdyRadii.pill),
                  ),
                  child: Text(
                    '${spot.count}',
                    style: BirdyText.labelCompact.copyWith(
                      color: _mist,
                      fontSize: 13,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Several markers close together: a Martin-pêcheur disc with the number
/// of species (SPEC.md 9.14, « Le jardin »).
class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.species});

  final int species;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unit = l10n.forkMapClusterSpecies(species);
    return Semantics(
      button: true,
      label: '$species $unit',
      excludeSemantics: true,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _kingfisher,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E13233A),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$species',
                  style: BirdyText.numberM.copyWith(color: _ink, height: 1),
                ),
                Text(
                  unit,
                  style: BirdyText.caption.copyWith(
                    color: _ink,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's position: a Martin-pêcheur dot with a white border and a
/// soft, still halo (no endless animation on the map).
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kingfisher.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: _kingfisher,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x2E13233A), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
