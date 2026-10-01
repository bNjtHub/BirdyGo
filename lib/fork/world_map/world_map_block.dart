/// « Dans le monde » block of the species page (J7): the range of the species
/// on a map by administrative regions, as in a field guide, in four colors
/// (nesting, wintering, all year, passage). Widgets only: the screen wires the
/// data (see `WorldMapSection`).
library;

import 'dart:ui' as ui;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../species_page/section_title.dart';
import '../species_page/species_page_text.dart';
import '../species_sheet/species_sheet.dart';
import 'range_class.dart';
import 'range_frame.dart';
import 'range_legend.dart';
import 'world_map_config.dart';
import 'world_map_data.dart';
import 'world_map_painter.dart';
import 'world_map_text.dart';
import 'world_regions.dart';

class WorldMapBlock extends StatefulWidget {
  const WorldMapBlock({
    super.key,
    required this.regions,
    required this.classes,
    this.user,
    this.nesting,
    this.source = WorldMapSource.geomodel,
    this.generation,
    this.onGbifTap,
    this.onLicenseTap,
  });

  final WorldRegions regions;

  /// Class of each region the species uses, by region id.
  final Map<String, RangeClass> classes;

  /// GBIF observations or the geo-model estimate: sets the mention under the
  /// map.
  final WorldMapSource source;

  /// Generation date (yyyymmdd) of the GBIF data, for the credit.
  final int? generation;

  /// Open GBIF's site, and the licenses page that cites it.
  final VoidCallback? onGbifTap;
  final VoidCallback? onLicenseTap;

  /// Where the user is, when known.
  final GridCell? user;

  /// From the AI sheet, when there is one.
  final NestingPeriod? nesting;

  /// Same shape as the loaded block: title, map, key, summary.
  static Widget skeleton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BirdyBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: AppIcons.public, text: l10n.forkWorldTitle),
          const SizedBox(height: BirdySpace.m),
          AspectRatio(
            aspectRatio: WorldMapConfig.aspect,
            child: BirdySkeleton.box(
              width: double.infinity,
              height: double.infinity,
              radius: BirdyRadii.chip,
            ),
          ),
          const SizedBox(height: BirdySpace.m),
          BirdySkeleton.text(
            BirdyText.bodyCompact,
            placeholder: l10n.forkWorldLegendClass(
              l10n.forkWorldClassBreeding,
              l10n.forkWorldRegionNorthernEurope,
            ),
            maxLines: null,
          ),
        ],
      ),
    );
  }

  @override
  State<WorldMapBlock> createState() => _WorldMapBlockState();
}

class _WorldMapBlockState extends State<WorldMapBlock> {
  /// Computed once per data: the frame and the summary.
  late MapFrame _frame = frameOf(widget.regions, widget.classes);
  late RangeLegend _legend = buildRangeLegend(widget.regions, widget.classes);

  /// Id of the tapped region.
  String? _selected;

  /// Paths of the map, kept across rebuilds (tap, theme).
  final _sceneCache = WorldMapSceneCache();

  /// What the cached raster / the build in flight was made for.
  ({Size size, double ratio, WorldMapColors colors})? _pending;
  ({Size size, double ratio, WorldMapColors colors}) _rasterKey =
      (size: Size.zero, ratio: 0, colors: WorldMapColors.of(BirdyColors.light));
  ui.Image? _image;
  bool _hasImage = false;

  /// Rasterizing failed (no engine support): draw vectors instead.
  bool _rasterFailed = false;

  /// Builds the paths, then rasterizes the static layer once, in a task after
  /// the current frame, and repaints when ready. Until then the map shows a
  /// skeleton. The painter still draws vectors if there is no image.
  void _prebuild(Size size, double ratio, WorldMapColors colors) {
    final key = (size: size, ratio: ratio, colors: colors);
    if (_pending == key) return;
    _pending = key;
    // Animation priority, not idle: an idle task is starved while any
    // animation runs (the skeleton's shimmer included).
    SchedulerBinding.instance.scheduleTask<void>(() async {
      if (!mounted || _pending != key) return;
      final scene = _sceneCache.get(widget.regions, widget.classes, _frame, size);
      try {
        final image = await renderStaticLayer(scene, colors, size, ratio);
        if (!mounted || _pending != key) {
          image.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = image;
          _hasImage = true;
          _rasterKey = key;
        });
      } on Object {
        if (!mounted || _pending != key) return;
        setState(() => _rasterFailed = true);
      }
    }, Priority.animation);
  }

  void _dropImage() {
    _image?.dispose();
    _image = null;
    _hasImage = false;
    _pending = null;
  }

  @override
  void didUpdateWidget(WorldMapBlock old) {
    super.didUpdateWidget(old);
    if (!identical(old.classes, widget.classes) ||
        !identical(old.regions, widget.regions)) {
      _frame = frameOf(widget.regions, widget.classes);
      _legend = buildRangeLegend(widget.regions, widget.classes);
      _selected = null;
      _dropImage();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _tap(Offset position, Size size) {
    final at = MapProjection(_frame, size).unproject(position);
    final region = widget.regions.regionAt(at.longitude, at.latitude);
    final id = region != null && widget.classes.containsKey(region.id)
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
    return BirdyBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: AppIcons.public, text: l10n.forkWorldTitle),
          const SizedBox(height: BirdySpace.m),
          Semantics(
            container: true,
            label: l10n.forkWorldMapLabel(legend),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BirdyRadii.chip),
              child: AspectRatio(
                aspectRatio: frameAspect(_frame),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = box.biggest;
                    final ratio = MediaQuery.devicePixelRatioOf(context);
                    final fresh =
                        _hasImage &&
                        _rasterKey == (size: size, ratio: ratio, colors: colors);
                    if (!fresh && !_rasterFailed) {
                      _prebuild(size, ratio, colors);
                    }
                    // A stale image (theme change) is not drawn: vectors take
                    // over until the new one is ready.
                    final ready =
                        fresh ||
                        (_sceneCache.has(
                          widget.regions,
                          widget.classes,
                          _frame,
                          size,
                        ) &&
                            (_hasImage || _rasterFailed));
                    return BirdyCrossFade(
                      child: !ready
                          ? KeyedSubtree(
                              key: const ValueKey('world-map-canvas-pending'),
                              child: BirdySkeleton.box(
                                width: double.infinity,
                                height: double.infinity,
                                radius: BirdyRadii.chip,
                              ),
                            )
                          : GestureDetector(
                              key: const ValueKey('world-map-canvas'),
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (d) => _tap(d.localPosition, size),
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: WorldMapPainter(
                                    regions: widget.regions,
                                    classes: widget.classes,
                                    frame: _frame,
                                    colors: colors,
                                    user: widget.user,
                                    selected: _selected,
                                    staticImage: fresh ? _image : null,
                                    cache: _sceneCache,
                                  ),
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (selected != null && selectedClass != null) ...[
            const SizedBox(height: BirdySpace.s),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.forkWorldRegionStatus(
                  selected.name,
                  className(l10n, selectedClass),
                ),
                key: const ValueKey('world-map-selected'),
                style: BirdyText.bodyCompact.copyWith(color: c.text1),
              ),
            ),
          ],
          const SizedBox(height: BirdySpace.s),
          _Key(colors: colors, showYou: widget.user != null),
          const SizedBox(height: BirdySpace.s),
          Text(legend, style: BirdyText.bodyCompact.copyWith(color: c.text1)),
          if (nesting != null) ...[
            const SizedBox(height: BirdySpace.xs),
            Text(
              nestingLegend(l10n, language, nesting),
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
          ],
          const SizedBox(height: BirdySpace.s),
          _SourceNote(
            source: widget.source,
            generation: widget.generation,
            onGbifTap: widget.onGbifTap,
            onLicenseTap: widget.onLicenseTap,
          ),
        ],
      ),
    );
  }
}

/// Key under the map: the four classes and, when known, the user.
class _Key extends StatelessWidget {
  const _Key({required this.colors, required this.showYou});

  final WorldMapColors colors;
  final bool showYou;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: BirdySpace.xs),
        Flexible(
          child: Text(label, style: BirdyText.caption.copyWith(color: c.text2)),
        ),
      ],
    );
    return Wrap(
      spacing: BirdySpace.l,
      runSpacing: BirdySpace.xs,
      children: [
        for (final k in RangeClass.values)
          item(
            Container(
              key: ValueKey('world-map-key-${k.name}'),
              width: WorldMapConfig.keySwatch,
              height: WorldMapConfig.keySwatch,
              decoration: BoxDecoration(
                color: colors.classes[k],
                borderRadius: BorderRadius.circular(BirdyRadii.xs),
              ),
            ),
            className(l10n, k),
          ),
        if (showYou)
          item(
            Container(
              width: WorldMapConfig.userDot,
              height: WorldMapConfig.userDot,
              decoration: BoxDecoration(
                color: colors.user,
                shape: BoxShape.circle,
              ),
            ),
            l10n.forkWorldKeyYou,
          ),
      ],
    );
  }
}

/// Mention under the map: the geo-model estimate, or the GBIF credit with two
/// links: GBIF's site and the licenses page (48 dp targets).
class _SourceNote extends StatelessWidget {
  const _SourceNote({
    required this.source,
    this.generation,
    this.onGbifTap,
    this.onLicenseTap,
  });

  final WorldMapSource source;
  final int? generation;
  final VoidCallback? onGbifTap;
  final VoidCallback? onLicenseTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    if (source == WorldMapSource.geomodel) {
      return Text(l10n.forkWorldEstimate, style: caption);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LinkTarget(
          key: const ValueKey('world-map-source'),
          label: generation == null
              ? l10n.forkLicensesGbifRow
              : l10n.forkWorldSourceGbif('${generation! ~/ 10000}'),
          style: caption,
          onTap: onGbifTap,
        ),
        Text(' · ', style: caption),
        _LinkTarget(
          key: const ValueKey('world-map-license'),
          label: l10n.forkWorldSourceLicense,
          style: caption,
          onTap: onLicenseTap,
        ),
      ],
    );
  }
}

/// A line of text that is a button, at least 48 dp tall.
class _LinkTarget extends StatelessWidget {
  const _LinkTarget({
    super.key,
    required this.label,
    required this.style,
    this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: style);
    if (onTap == null) return text;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BirdyRadii.chip),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: text,
          ),
        ),
      ),
    );
  }
}
