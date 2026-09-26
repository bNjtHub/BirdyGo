/// Live table (J6c): a new species enters at the top, a species heard again
/// moves back to the top in 250 ms and its « ×N » bumps. The list is never
/// cleared while listening (fork/DESIGN.md, Live).
library;

import 'dart:math' as math;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/species_accents.dart';
import '../design/widgets/animated_count.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/species_avatar.dart';
import '../design/widgets/species_tile.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import 'live_board_model.dart';

/// Scrollable live table.
class LiveBoard extends StatefulWidget {
  const LiveBoard({
    super.key,
    required this.entries,
    this.compact = false,
    this.onTap,
    this.actionBuilder,
    this.imageOf,
    this.padding = const EdgeInsets.fromLTRB(
      BirdySpace.gutterLive,
      BirdySpace.m,
      BirdySpace.gutterLive,
      BirdySpace.m,
    ),
  });

  final List<LiveBoardEntry> entries;

  /// 60 px rows, under the enlarged spectrogram.
  final bool compact;

  final void Function(LiveBoardEntry entry)? onTap;

  /// Trailing action of a row (the replay button).
  final Widget? Function(LiveBoardEntry entry)? actionBuilder;

  /// Species photo, when one is bundled.
  final ImageProvider? Function(String scientificName)? imageOf;

  final EdgeInsetsGeometry padding;

  @override
  State<LiveBoard> createState() => _LiveBoardState();
}

class _LiveBoardState extends State<LiveBoard> with TickerProviderStateMixin {
  /// Species already shown once: rows present when the screen opens do not
  /// play the entrance, only the ones that arrive afterwards.
  late final Set<String> _seen = {
    for (final entry in widget.entries) entry.scientificName,
  };

  @override
  void didUpdateWidget(LiveBoard old) {
    super.didUpdateWidget(old);
    final arrived = widget.entries.any(
      (entry) => !_seen.contains(entry.scientificName),
    );
    if (arrived) BirdyHaptics.light();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = BirdyMotion.reduced(context);
    final rows = <Widget>[];
    for (final entry in widget.entries) {
      final isNew = _seen.add(entry.scientificName);
      rows.add(
        KeyedSubtree(
          key: ValueKey(entry.scientificName),
          child: BirdyEntrance(
            // Read once, when the row first appears.
            duration: isNew ? BirdyMotion.newSpecies : Duration.zero,
            offset: const Offset(0, -BirdyMotion.maxOffset),
            child: LiveBoardRow(
              entry: entry,
              compact: widget.compact,
              image: widget.imageOf?.call(entry.scientificName),
              action: widget.actionBuilder?.call(entry),
              onTap: widget.onTap == null ? null : () => widget.onTap!(entry),
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: widget.padding,
      child: LiveBoardLayout(
        vsync: this,
        gap: widget.compact ? 6 : BirdySpace.s,
        animate: !reduced,
        children: rows,
      ),
    );
  }
}

/// One species of the live table (SPEC.md 5.5).
class LiveBoardRow extends StatelessWidget {
  const LiveBoardRow({
    super.key,
    required this.entry,
    this.compact = false,
    this.image,
    this.action,
    this.onTap,
  });

  final LiveBoardEntry entry;
  final bool compact;
  final ImageProvider? image;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tint = speciesTintFor(entry.scientificName);
    return SpeciesTile(
      name: entry.commonName,
      compact: compact,
      avatar: SpeciesAvatar(
        image: image,
        tint: tint,
        size: compact ? 40 : 48,
        muted: entry.level == ReliabilityLevel.toCheck,
      ),
      meta: Wrap(
        spacing: BirdySpace.s,
        runSpacing: BirdySpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ReliabilityBadge(
            level: entry.level,
            unexpected: entry.unexpected,
            compact: compact,
          ),
          if (!compact) Text(l10n.forkLiveTotal(entry.total)),
          if (entry.singing)
            Icon(
              AppIcons.graphicEq,
              size: 16,
              color: tint.accent,
              semanticLabel: l10n.forkLiveSinging,
            ),
        ],
      ),
      count: AnimatedCount(
        value: entry.sessionCount,
        format: (v) => '×$v',
        semanticsLabel: l10n.forkLiveSessionCount(entry.sessionCount),
      ),
      action: action,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout: a column whose rows glide to their new place when the order changes.
// ─────────────────────────────────────────────────────────────────────────────

/// Column of keyed rows. When a row changes place, it is painted at its old
/// place and glides to the new one ([BirdyMotion.reorder], [BirdyMotion.move]);
/// a row rising to the top is painted above the others. Like upstream's
/// [RenderAnimatedSize], the animation lives in the render object, so the
/// first frame after a reorder is already at the old place (no flicker).
class LiveBoardLayout extends MultiChildRenderObjectWidget {
  const LiveBoardLayout({
    super.key,
    required this.vsync,
    required this.gap,
    this.animate = true,
    super.children,
  });

  final TickerProvider vsync;
  final double gap;

  /// False with reduced motion: rows jump to their new place.
  final bool animate;

  @override
  RenderLiveBoard createRenderObject(BuildContext context) =>
      RenderLiveBoard(vsync: vsync, gap: gap, animate: animate);

  @override
  void updateRenderObject(BuildContext context, RenderLiveBoard renderObject) {
    renderObject
      ..vsync = vsync
      ..gap = gap
      ..animate = animate;
  }
}

class _BoardParentData extends ContainerBoxParentData<RenderBox> {
  /// Place of the row at the previous layout.
  double? lastY;

  /// Displacement from its place when the running glide started.
  double fromDelta = 0;
}

class RenderLiveBoard extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BoardParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BoardParentData> {
  RenderLiveBoard({
    required TickerProvider vsync,
    required double gap,
    required bool animate,
  }) : _gap = gap,
       _animate = animate {
    _controller = AnimationController(
      vsync: vsync,
      duration: BirdyMotion.reorder,
      value: 1,
    )..addListener(markNeedsPaint);
    _curve = CurvedAnimation(parent: _controller, curve: BirdyMotion.move);
  }

  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  set vsync(TickerProvider value) => _controller.resync(value);

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  bool get animate => _animate;
  bool _animate;
  set animate(bool value) {
    if (value == _animate) return;
    _animate = value;
    markNeedsLayout();
  }

  /// Whether rows are gliding (for tests).
  bool get isMoving => _controller.isAnimating;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BoardParentData) {
      child.parentData = _BoardParentData();
    }
  }

  double _displacement(_BoardParentData data) =>
      data.fromDelta * (1 - _curve.value);

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final childConstraints = BoxConstraints.tightFor(width: width);
    final pending = <_BoardParentData, double>{};
    var moved = false;
    var y = 0.0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _BoardParentData;
      child.layout(childConstraints, parentUsesSize: true);
      data.offset = Offset(0, y);
      final current = _displacement(data);
      final lastY = data.lastY;
      if (lastY != null && lastY != y) {
        pending[data] = current + lastY - y;
        moved = true;
      } else {
        pending[data] = current;
      }
      data.lastY = y;
      y += child.size.height + _gap;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(width, math.max(0, y - _gap)));

    if (!_animate) {
      _controller.value = 1;
      pending.forEach((data, _) => data.fromDelta = 0);
    } else if (moved) {
      pending.forEach((data, delta) => data.fromDelta = delta);
      _controller.forward(from: 0);
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final childConstraints = BoxConstraints.tightFor(width: width);
    var height = 0.0;
    var count = 0;
    var child = firstChild;
    while (child != null) {
      height += child.getDryLayout(childConstraints).height;
      count++;
      child = childAfter(child);
    }
    if (count > 1) height += _gap * (count - 1);
    return constraints.constrain(Size(width, height));
  }

  double _sumHeights(double Function(RenderBox child) of) {
    var height = 0.0;
    var count = 0;
    var child = firstChild;
    while (child != null) {
      height += of(child);
      count++;
      child = childAfter(child);
    }
    return count > 1 ? height + _gap * (count - 1) : height;
  }

  double _maxWidth(double Function(RenderBox child) of) {
    var width = 0.0;
    var child = firstChild;
    while (child != null) {
      width = math.max(width, of(child));
      child = childAfter(child);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sumHeights((c) => c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sumHeights((c) => c.getMaxIntrinsicHeight(width));

  @override
  double computeMinIntrinsicWidth(double height) =>
      _maxWidth((c) => c.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _maxWidth((c) => c.getMaxIntrinsicWidth(double.infinity));

  /// Paint order: rows in place, then gliding rows, the one coming from the
  /// lowest place last (it is the one rising to the top).
  List<RenderBox> _paintOrder() {
    final still = <RenderBox>[];
    final moving = <(RenderBox, double)>[];
    var child = firstChild;
    while (child != null) {
      final d = _displacement(child.parentData! as _BoardParentData);
      if (d == 0) {
        still.add(child);
      } else {
        moving.add((child, d));
      }
      child = childAfter(child);
    }
    moving.sort((a, b) => a.$2.compareTo(b.$2));
    return [...still, for (final (box, _) in moving) box];
  }

  Offset _paintOffsetOf(RenderBox child) {
    final data = child.parentData! as _BoardParentData;
    return data.offset + Offset(0, _displacement(data));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _paintOrder()) {
      context.paintChild(child, offset + _paintOffsetOf(child));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _paintOrder().reversed) {
      final hit = result.addWithPaintOffset(
        offset: _paintOffsetOf(child),
        position: position,
        hitTest:
            (result, transformed) =>
                child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = _paintOffsetOf(child);
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }
}
