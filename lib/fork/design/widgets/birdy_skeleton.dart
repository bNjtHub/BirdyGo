/// Loading skeletons (fix/j6h-retouches): placeholders that reserve exactly
/// the size the real content will take, so a screen's layout never shifts
/// once data arrives. Every shape is rounded (a text line is a pill, a block
/// takes the radius of the card it stands for) and filled with a faint
/// gradient rather than a flat rectangle. Each is wrapped in a
/// [BirdyShimmer]: a soft band sweeps over all of a screen's skeletons in
/// sync (one shared ticker), only while they are shown; a plain static fill
/// with reduced motion. No call-site change is needed.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import 'birdy_shimmer.dart';

abstract final class BirdySkeleton {
  /// A muted rounded bar the height and alphabetic baseline of [style]'s text,
  /// so it drops into a `CrossAxisAlignment.baseline` [Row] exactly like the
  /// real text would (it *is* a [Text], just with invisible glyphs, and one
  /// pill is painted over each of its lines).
  ///
  /// [placeholder] should be the real string the final text will show (its
  /// characters never show, but its length decides how many lines this
  /// wraps to, so pass the localized sentence, not a generic filler, or a
  /// caption that wraps in the real state would come out shorter here and
  /// the block would still resize once the real text replaces it).
  /// [maxLines] null lets it wrap like the real text; `1` (the default) is
  /// for a line that never wraps (a number, a static label).
  static Widget text(
    TextStyle style, {
    Key? key,
    String placeholder = '00000000000000000000',
    int? maxLines = 1,
  }) => _SkeletonText(
    key: key,
    style: style,
    placeholder: placeholder,
    maxLines: maxLines,
  );

  /// A muted rounded box of exactly [width] × [height] (a card, a visual).
  /// Pass the radius of the shape it stands for: [BirdyRadii.card] or
  /// [BirdyRadii.hero] for a block, [BirdyRadii.pill] for a bar or a disc.
  static Widget box({
    Key? key,
    required double width,
    required double height,
    double radius = BirdyRadii.thumb,
  }) => _SkeletonBox(key: key, width: width, height: height, radius: radius);

  /// A round placeholder (an avatar, a ring) of [size].
  static Widget circle({Key? key, required double size}) =>
      box(key: key, width: size, height: size, radius: BirdyRadii.pill);

  /// A pill-shaped bar (a progress bar, a chip) [width] × [height].
  static Widget bar({
    Key? key,
    double width = double.infinity,
    required double height,
  }) => box(key: key, width: width, height: height, radius: BirdyRadii.pill);

  /// Start and end colors of a skeleton's fill: [BirdyColors.skeleton]
  /// drifting a little toward the sheen, so a shape is never a flat slab.
  @visibleForTesting
  static (Color, Color) fill(BirdyColors c) => (
    c.skeleton,
    Color.alphaBlend(
      c.skeletonSheen.withValues(alpha: c.skeletonSheen.a * _fillDrift),
      c.skeleton,
    ),
  );

  /// Share of the sheen's opacity the fill's far end takes.
  static const double _fillDrift = 0.35;
}

class _SkeletonText extends StatefulWidget {
  const _SkeletonText({
    super.key,
    required this.style,
    required this.placeholder,
    required this.maxLines,
  });

  final TextStyle style;
  final String placeholder;
  final int? maxLines;

  @override
  State<_SkeletonText> createState() => _SkeletonTextState();
}

class _SkeletonTextState extends State<_SkeletonText> {
  final _LineCache _cache = _LineCache();

  @override
  Widget build(BuildContext context) {
    final (from, to) = BirdySkeleton.fill(BirdyColors.of(context));
    final pills = _LinePills(
      cache: _cache,
      text: widget.placeholder,
      style: widget.style,
      maxLines: widget.maxLines,
      scaler: MediaQuery.textScalerOf(context),
      from: from,
      to: to,
    );
    return ExcludeSemantics(
      child: BirdyShimmer(
        // The invisible text gives the size and the baseline; the pills are
        // painted over it, one per line.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Text(
              widget.placeholder,
              maxLines: widget.maxLines,
              softWrap: widget.maxLines != 1,
              overflow:
                  widget.maxLines == 1
                      ? TextOverflow.clip
                      : TextOverflow.visible,
              style: widget.style.copyWith(color: Colors.transparent),
            ),
            Positioned.fill(child: CustomPaint(painter: pills)),
          ],
        ),
      ),
    );
  }
}

/// Line rectangles of a placeholder text, measured once per input and width
/// (the shimmer repaints every frame, layout must not).
class _LineCache {
  Object? _key;
  List<Rect> rects = const [];

  /// Vertical breathing room between a pill and its line box.
  static const double _inset = 1.5;

  void measure(Object key, double width, TextPainter Function() painter) {
    if (_key == key) return;
    final p = painter()..layout(maxWidth: width);
    rects = [
      for (final m in p.computeLineMetrics())
        Rect.fromLTWH(
          m.left,
          m.baseline - m.ascent,
          math.min(m.width, width - m.left),
          m.ascent + m.descent,
        ).deflate(_inset),
    ];
    p.dispose();
    _key = key;
  }
}

/// Paints a rounded pill under each line of an invisible text.
class _LinePills extends CustomPainter {
  _LinePills({
    required this.cache,
    required this.text,
    required this.style,
    required this.maxLines,
    required this.scaler,
    required this.from,
    required this.to,
  });

  final _LineCache cache;
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextScaler scaler;
  final Color from;
  final Color to;

  @override
  void paint(Canvas canvas, Size size) {
    cache.measure(
      (text, style, maxLines, scaler, size.width),
      size.width,
      () => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: maxLines,
      ),
    );
    for (final r in cache.rects) {
      if (r.isEmpty) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2)),
        Paint()
          ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [from, to]),
      );
    }
  }

  @override
  bool shouldRepaint(_LinePills old) =>
      old.from != from ||
      old.to != to ||
      old.text != text ||
      old.style != style ||
      old.maxLines != maxLines ||
      old.scaler != scaler;
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (from, to) = BirdySkeleton.fill(BirdyColors.of(context));
    return ExcludeSemantics(
      child: BirdyShimmer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [from, to],
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
