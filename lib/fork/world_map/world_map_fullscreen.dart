/// Full-screen, zoomable version of the species page world map (J7). The
/// inline map stays as it is; this page opens from its expand button.
///
/// While a gesture runs, the last raster of the static layer is drawn scaled
/// to the current window (slightly blurry); when the gesture ends, the layer
/// is rendered again for the visible window at screen resolution, in a
/// scheduled task, and swapped in. Borders keep a constant width in pixels
/// because the paths are rebuilt for the window, not scaled.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../species_page/species_page_text.dart';
import '../species_sheet/species_sheet.dart';
import 'range_class.dart';
import 'range_frame.dart';
import 'range_legend.dart';
import 'world_map_block.dart';
import 'world_map_config.dart';
import 'world_map_data.dart';
import 'world_map_painter.dart';
import 'world_map_text.dart';
import 'world_map_viewport.dart';
import 'world_regions.dart';

/// Renders the static layer of one window; replaceable in tests.
typedef StaticLayerRenderer =
    Future<ui.Image> Function(
      WorldMapScene scene,
      WorldMapColors colors,
      Size size,
      double pixelRatio,
    );

class WorldMapFullscreen extends StatefulWidget {
  const WorldMapFullscreen({
    super.key,
    required this.speciesName,
    required this.regions,
    required this.classes,
    this.user,
    this.nesting,
    this.source = WorldMapSource.geomodel,
    this.generation,
    this.onGbifTap,
    this.onLicenseTap,
    @visibleForTesting this.renderer = renderStaticLayer,
  });

  final String speciesName;
  final WorldRegions regions;
  final Map<String, RangeClass> classes;
  final GridCell? user;
  final NestingPeriod? nesting;
  final WorldMapSource source;
  final int? generation;
  final VoidCallback? onGbifTap;
  final VoidCallback? onLicenseTap;
  final StaticLayerRenderer renderer;

  @override
  State<WorldMapFullscreen> createState() => _WorldMapFullscreenState();
}

class _WorldMapFullscreenState extends State<WorldMapFullscreen> {
  late final MapFrame _home = frameOf(widget.regions, widget.classes);
  late final RangeLegend _legend = buildRangeLegend(
    widget.regions,
    widget.classes,
  );
  final _sceneCache = WorldMapSceneCache();

  /// Repaint trigger for the canvas: gestures change [_view] many times a
  /// second and only the painter needs to know.
  final _tick = ValueNotifier<int>(0);
  MapViewport? _view;

  /// The raster in use and the window it was rendered for.
  ui.Image? _image;
  MapFrame? _imageFrame;
  bool _rasterFailed = false;

  /// What the render in flight is for.
  ({MapFrame frame, Size size, double ratio, WorldMapColors colors})? _pending;
  ({Size size, double ratio, WorldMapColors colors})? _rasterKey;

  /// Gesture start: the map point under the focal point, and the view.
  MapViewport? _gestureStart;
  GridCell? _gestureGeo;

  /// A tap just happened: a second one soon after is a double tap.
  Offset? _lastTap;
  Timer? _tapTimer;

  String? _selected;

  @override
  void dispose() {
    _tapTimer?.cancel();
    _image?.dispose();
    _tick.dispose();
    super.dispose();
  }

  MapViewport _viewFor(Size size) {
    var v = _view;
    if (v == null || v.size != size) {
      v = _view = v == null ? MapViewport.home(_home, size) : v.resized(size);
      _gestureStart = null;
    }
    return v;
  }

  /// Renders the static layer for the current window, in a task after the
  /// frame, and swaps it in when it is still the window on screen.
  void _render(Size size, double ratio, WorldMapColors colors) {
    final frame = _view!.frame;
    final key = (frame: frame, size: size, ratio: ratio, colors: colors);
    if (_pending == key) return;
    _pending = key;
    // Animation priority, not idle: an idle task is starved while any
    // animation runs.
    SchedulerBinding.instance.scheduleTask<void>(() async {
      if (!mounted || _pending != key) return;
      final scene = _sceneCache.get(
        widget.regions,
        widget.classes,
        frame,
        size,
      );
      try {
        final image = await widget.renderer(scene, colors, size, ratio);
        // Dropped when the window moved on, or the page is gone.
        if (!mounted || _pending != key) {
          image.dispose();
          return;
        }
        final old = _image;
        setState(() {
          _image = image;
          _imageFrame = frame;
          _rasterKey = (size: size, ratio: ratio, colors: colors);
          _pending = null;
        });
        old?.dispose();
      } on Object {
        if (!mounted || _pending != key) return;
        setState(() => _rasterFailed = true);
      }
    }, Priority.animation);
  }

  void _moveTo(MapViewport v) {
    _view = v;
    _tick.value++;
  }

  void _scaleStart(ScaleStartDetails d) {
    final v = _view;
    if (v == null) return;
    _gestureStart = v;
    _gestureGeo = MapProjection(v.frame, v.size).unproject(d.localFocalPoint);
    // A render for the old window is useless now.
    _pending = null;
  }

  void _scaleUpdate(ScaleUpdateDetails d) {
    final start = _gestureStart;
    final geo = _gestureGeo;
    if (start == null || geo == null) return;
    _moveTo(start.anchored(geo, d.localFocalPoint, start.zoom * d.scale));
  }

  /// The next build renders the map again at screen resolution (`_render`).
  void _scaleEnd(ScaleEndDetails d) {
    _gestureStart = null;
    _gestureGeo = null;
    setState(() {});
  }

  void _zoomBy(double factor, Offset screen) {
    final v = _view;
    if (v == null) return;
    final geo = MapProjection(v.frame, v.size).unproject(screen);
    _moveTo(v.anchored(geo, screen, v.zoom * factor));
    setState(() {});
  }

  /// Double tap: zoom in around the point, back to the framing at the maximum.
  /// Instant, never animated, so reduced motion needs no special case.
  void _doubleTap(Offset screen) {
    final v = _view;
    if (v == null) return;
    if (v.atMaxZoom) {
      _moveTo(v.reset);
      setState(() {});
    } else {
      _zoomBy(WorldMapConfig.doubleTapZoom, screen);
    }
  }

  void _tapUp(Offset position) {
    final previous = _lastTap;
    if (previous != null && (previous - position).distance <= kDoubleTapSlop) {
      _tapTimer?.cancel();
      _lastTap = null;
      _doubleTap(position);
      return;
    }
    _lastTap = position;
    _tapTimer?.cancel();
    _tapTimer = Timer(kDoubleTapTimeout, () => _lastTap = null);
    final v = _view;
    if (v == null) return;
    final at = MapProjection(v.frame, v.size).unproject(position);
    final region = widget.regions.regionAt(at.longitude, at.latitude);
    final id =
        region != null && widget.classes.containsKey(region.id)
            ? region.id
            : null;
    setState(() => _selected = id == _selected ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final colors = WorldMapColors.of(c);
    final legend = legendText(l10n, language, _legend);
    final nesting = widget.nesting;
    final selected = _selected == null ? null : widget.regions.byId(_selected!);
    final selectedClass = selected == null ? null : widget.classes[selected.id];
    final caption = BirdyText.bodyCompact.copyWith(color: c.text1);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const ValueKey('world-map-close'),
          icon: const Icon(AppIcons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.speciesName,
          style: BirdyText.bodyCompact.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRect(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final size = box.biggest;
                      final ratio = MediaQuery.devicePixelRatioOf(context);
                      final view = _viewFor(size);
                      String zoomText(double z) => l10n.forkWorldZoomValue(
                        '×${z.clamp(WorldMapConfig.minScale, WorldMapConfig.maxScale).toStringAsFixed(1)}',
                      );
                      final key = (size: size, ratio: ratio, colors: colors);
                      if (_gestureStart == null &&
                          !_rasterFailed &&
                          (_imageFrame != view.frame || _rasterKey != key)) {
                        _render(size, ratio, colors);
                      }
                      if (_image == null && !_rasterFailed) {
                        return BirdySkeleton.box(
                          width: double.infinity,
                          height: double.infinity,
                          radius: 0,
                        );
                      }
                      return Semantics(
                        container: true,
                        label: l10n.forkWorldMapLabel(legend),
                        hint: l10n.forkWorldMapHint,
                        value: zoomText(view.zoom),
                        increasedValue: zoomText(
                          view.zoom * WorldMapConfig.doubleTapZoom,
                        ),
                        decreasedValue: zoomText(
                          view.zoom / WorldMapConfig.doubleTapZoom,
                        ),
                        excludeSemantics: true,
                        onIncrease:
                            () => _zoomBy(
                              WorldMapConfig.doubleTapZoom,
                              size.center(Offset.zero),
                            ),
                        onDecrease:
                            () => _zoomBy(
                              1 / WorldMapConfig.doubleTapZoom,
                              size.center(Offset.zero),
                            ),
                        child: GestureDetector(
                          key: const ValueKey('world-map-fullscreen-canvas'),
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _scaleStart,
                          onScaleUpdate: _scaleUpdate,
                          onScaleEnd: _scaleEnd,
                          onTapUp: (d) => _tapUp(d.localPosition),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: size,
                              painter: _FullscreenPainter(
                                repaint: _tick,
                                viewOf: () => _view ?? view,
                                regions: widget.regions,
                                classes: widget.classes,
                                colors: colors,
                                user: widget.user,
                                selected: _selected,
                                image: _image,
                                imageFrame: _imageFrame,
                                cache: _sceneCache,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (selected != null && selectedClass != null)
                  Positioned(
                    left: BirdySpace.l,
                    right: BirdySpace.l,
                    bottom: BirdySpace.s,
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: Semantics(
                        liveRegion: true,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.surface1.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(
                              BirdyRadii.chip,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: BirdySpace.m,
                              vertical: BirdySpace.s,
                            ),
                            child: Text(
                              l10n.forkWorldRegionStatus(
                                selected.name,
                                className(l10n, selectedClass),
                              ),
                              key: const ValueKey('world-map-selected'),
                              style: caption,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BirdySpace.l),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // (the tapped region is named over the map: no layout shift)
                    WorldMapKey(colors: colors, showYou: widget.user != null),
                    const SizedBox(height: BirdySpace.s),
                    Text(legend, style: caption),
                    if (nesting != null) ...[
                      const SizedBox(height: BirdySpace.xs),
                      Text(
                        nestingLegend(l10n, language, nesting),
                        style: caption,
                      ),
                    ],
                    const SizedBox(height: BirdySpace.s),
                    WorldMapSourceNote(
                      source: widget.source,
                      generation: widget.generation,
                      onGbifTap: widget.onGbifTap,
                      onLicenseTap: widget.onLicenseTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the cached raster scaled to the current window, then the overlay.
/// Without a raster (rendering failed) the layer is drawn as vectors.
class _FullscreenPainter extends CustomPainter {
  _FullscreenPainter({
    required Listenable repaint,
    required this.viewOf,
    required this.regions,
    required this.classes,
    required this.colors,
    required this.cache,
    this.user,
    this.selected,
    this.image,
    this.imageFrame,
  }) : super(repaint: repaint);

  final MapViewport Function() viewOf;
  final WorldRegions regions;
  final Map<String, RangeClass> classes;
  final WorldMapColors colors;
  final GridCell? user;
  final String? selected;
  final ui.Image? image;
  final MapFrame? imageFrame;
  final WorldMapSceneCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final frame = viewOf().frame;
    final projection = MapProjection(frame, size);
    final img = image;
    final imgFrame = imageFrame;
    if (img != null && imgFrame != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = colors.ocean);
      // Where the raster's window falls in the current one.
      final dest = Rect.fromPoints(
        projection.project(imgFrame.lat1, imgFrame.lon0),
        projection.project(imgFrame.lat0, imgFrame.lon1),
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dest,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      paintStaticLayer(
        canvas,
        size,
        cache.get(regions, classes, frame, size),
        colors,
      );
    }
    paintMapOverlay(
      canvas,
      projection,
      regions: regions,
      colors: colors,
      selected: selected,
      user: user,
    );
  }

  @override
  bool shouldRepaint(_FullscreenPainter old) =>
      old.regions != regions ||
      old.classes != classes ||
      old.colors != colors ||
      old.image != image ||
      old.imageFrame != imageFrame ||
      old.user != user ||
      old.selected != selected;
}
