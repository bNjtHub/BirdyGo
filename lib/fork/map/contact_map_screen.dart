/// Map of every contact of every session (fork/PLAN.md J5, layout from
/// fork/maquette/Carte.dc.html).
///
/// Small zooms show a hexagon grid whose opacity follows the number of
/// contacts; large zooms show one round bird marker per species and spot,
/// clustered. Tapping a hexagon or a marker opens the species of the area.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/survey/widgets/survey_map_widget.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index_service.dart';
import '../ranking/ranking_logic.dart';
import 'base_layers.dart';
import 'contact_map_data.dart';
import 'contact_map_sheets.dart';
import 'hex_grid.dart';
import 'map_config.dart';

/// Martin-pêcheur (fork/DESIGN.md): hexagons and the user's position.
const Color _kingfisher = Color(0xFF19A7B3);

/// Encre de nuit and Brume (fork/DESIGN.md): marker count badges.
const Color _ink = Color(0xFF13233A);
const Color _mist = Color(0xFFEEF1EC);

/// Where the map opens when there is nothing to show: France.
const LatLng _defaultCenter = LatLng(46.6, 2.4);
const double _defaultZoom = 5;

/// Full-screen contact map.
class ContactMapScreen extends ConsumerStatefulWidget {
  const ContactMapScreen({super.key});

  @override
  ConsumerState<ContactMapScreen> createState() => _ContactMapScreenState();
}

class _ContactMapScreenState extends ConsumerState<ContactMapScreen> {
  final MapController _mapController = MapController();

  RankingPeriod _period = RankingPeriod.last30Days;
  bool _confirmedOnly = false;
  SpeciesChoice _species = const SpeciesChoice.all();
  late MapBaseLayer _layer;
  TileLayer? _tileLayer;

  ContactMapData? _data;
  int _loadGeneration = 0;
  double _zoom = _defaultZoom;
  bool _mapReady = false;
  LatLng? _userPosition;
  HexKey? _selectedSpot;

  // Layer caches, rebuilt only when the data, the zoom step or the
  // selection change (never per frame).
  (ContactMapData, int)? _polygonsKey;
  List<Polygon> _polygons = const [];
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

  List<Polygon> _hexPolygons(ContactMapData data) {
    final step = _zoom.floor();
    if (_polygonsKey == (data, step)) return _polygons;
    final bins = data.hexBins(step);
    _polygonsKey = (data, step);
    return _polygons = [
      for (final entry in bins.cells.entries)
        Polygon(
          points: bins.grid.corners(entry.key),
          color: _kingfisher.withValues(
            alpha: hexOpacity(entry.value.length, bins.maxCount),
          ),
          borderColor: _kingfisher,
          borderStrokeWidth: 1,
        ),
    ];
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

    return Scaffold(
      body: Stack(
        children: [
          if (data != null)
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      data.isEmpty ? _defaultCenter : data.positions.first,
                  initialZoom:
                      data.isEmpty ? _defaultZoom : kMapSinglePointZoom,
                  initialCameraFit: _cameraFit(data),
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    setState(() => _zoom = _mapController.camera.zoom);
                  },
                  onPositionChanged: (camera, _) {
                    final wasHexes = _zoom < kMapMarkersFromZoom;
                    final isHexes = camera.zoom < kMapMarkersFromZoom;
                    final stepChanged = _zoom.floor() != camera.zoom.floor();
                    _zoom = camera.zoom;
                    if (wasHexes != isHexes || (isHexes && stepChanged)) {
                      setState(() {});
                    }
                  },
                  onTap: (_, point) => _onMapTap(point),
                ),
                children: [
                  if (hasConsent) _tileLayer ??= buildBaseTileLayer(_layer),
                  if (showHexes)
                    PolygonLayer(
                      polygons: _hexPolygons(data),
                      simplificationTolerance: 0,
                    )
                  else
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 60,
                        disableClusteringAtZoom: kMapSpotZoom,
                        size: const Size(60, 60),
                        padding: const EdgeInsets.all(50),
                        markers: _spotMarkers(data, l10n),
                        builder:
                            (context, markers) =>
                                SurveyMapClusterBubble(count: markers.length),
                      ),
                    ),
                  if (_userPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _userPosition!,
                          width: 20,
                          height: 20,
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
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FilterBar(
                  speciesLabel: _species.commonName ?? l10n.forkMapAllSpecies,
                  speciesSelected: _species.scientificName != null,
                  periodLabel: _periodLabel(l10n, _period),
                  confirmedOnly: _confirmedOnly,
                  onBack: () => Navigator.of(context).maybePop(),
                  onSpecies: _pickSpecies,
                  onPeriod: () => _pickPeriod(l10n),
                  onConfirmed: (v) {
                    setState(() => _confirmedOnly = v);
                    unawaited(_load());
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child:
                            hasConsent
                                ? const SizedBox.shrink()
                                : _Notice(
                                  text: l10n.forkMapTilesOff,
                                  action: l10n.mapTileConsentAllow,
                                  onAction: () => _requestTileConsent(l10n),
                                ),
                      ),
                      const SizedBox(width: 8),
                      _MapButton(
                        icon: AppIcons.layers,
                        tooltip: l10n.forkMapBaseLayer,
                        onPressed: () => _pickBaseLayer(l10n),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (data != null && data.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _Notice(
                      text:
                          _indexEmpty
                              ? l10n.forkMapEmpty
                              : l10n.forkMapEmptyFiltered,
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
    );
  }
}

/// Filter chips over the map: species, period, confirmed only.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.speciesLabel,
    required this.speciesSelected,
    required this.periodLabel,
    required this.confirmedOnly,
    required this.onBack,
    required this.onSpecies,
    required this.onPeriod,
    required this.onConfirmed,
  });

  final String speciesLabel;
  final bool speciesSelected;
  final String periodLabel;
  final bool confirmedOnly;
  final VoidCallback onBack;
  final VoidCallback onSpecies;
  final VoidCallback onPeriod;
  final ValueChanged<bool> onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _MapButton(
            icon: AppIcons.arrowBackRounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          _MapChip(
            label: speciesLabel,
            selected: speciesSelected,
            trailing: AppIcons.expandMore,
            onPressed: onSpecies,
          ),
          const SizedBox(width: 8),
          _MapChip(
            label: periodLabel,
            selected: true,
            trailing: AppIcons.expandMore,
            onPressed: onPeriod,
          ),
          const SizedBox(width: 8),
          _MapChip(
            label: l10n.forkMapConfirmedOnly,
            selected: confirmedOnly,
            onPressed: () => onConfirmed(!confirmedOnly),
          ),
        ],
      ),
    );
  }
}

/// A 48 dp pill over the map; selected pills take the action color.
class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface;
    final foreground =
        selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        elevation: 2,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    Icon(trailing, size: 20, color: foreground),
                  ],
                ],
              ),
            ),
          ),
        ),
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
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: theme.colorScheme.onSurface),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: onPressed,
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
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ),
    );
  }
}

/// A species at a spot: the survey map's round photo marker, with the
/// number of contacts in a badge (maquette Carte).
class _ContactMarker extends StatelessWidget {
  const _ContactMarker({
    required this.spot,
    required this.selected,
    required this.onTap,
  });

  final ContactSpot spot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${spot.commonName} : ${l10n.forkMapContacts(spot.count)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SpeciesMarker(
                scientificName: spot.scientificName,
                confidence: spot.maxConfidence,
                hasAudio: spot.hasClip,
                isConfirmed: spot.confirmed,
                isHighlighted: selected,
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
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _mist, width: 1.5),
                  ),
                  child: Text(
                    '${spot.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _mist,
                      fontWeight: FontWeight.w700,
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

/// The user's position: a Martin-pêcheur dot with a white border.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kingfisher,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x2E13233A), blurRadius: 8)],
      ),
    );
  }
}
