/// Game visuals (J6e, SPEC.md 5.7 and 2.7): status emblem and ring, badge
/// medal, tier dots, série chip.
library;

import 'dart:math' as math;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/svg_path.dart';
import '../design/widgets/birdy_block.dart' show BirdyProgressBar;
import 'game_config.dart';

final Map<String, Path> _paths = {};
Path _path(String d) => _paths.putIfAbsent(d, () => parseSvgPath(d));

final Map<GlyphLayer, Path> _layerPaths = {};
Path _layerPath(GlyphLayer layer) => _layerPaths.putIfAbsent(layer, () {
  final dot = layer.circle;
  final path =
      dot == null
          ? _path(layer.d)
          : (Path()..addOval(
            Rect.fromCircle(center: Offset(dot.$1, dot.$2), radius: dot.$3),
          ));
  final cut = layer.cut;
  return cut == null
      ? path
      : Path.combine(PathOperation.difference, path, _path(cut));
});

/// Paints a 24-grid [Glyph] in [rect]. With [tones] each layer takes its
/// tone (and its true-life color when [GlyphTones.real]); without, the whole
/// glyph is one flat [color], a silhouette.
void paintGlyph(
  Canvas canvas,
  Rect rect,
  Glyph glyph,
  Color color, {
  GlyphTones? tones,
}) {
  final real = tones?.real ?? false;
  canvas
    ..save()
    ..translate(rect.left, rect.top)
    ..scale(rect.width / 24);
  for (final layer in glyph.layers) {
    if (layer.realOnly && !real) continue;
    final base =
        tones == null
            ? color
            : (real ? layer.real : null) ?? tones.of(layer.tone);
    final opacity = real ? (layer.realOpacity ?? layer.opacity) : layer.opacity;
    final paint =
        Paint()
          ..color = base.withValues(alpha: base.a * opacity)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas
      ..save()
      ..translate(layer.dx, layer.dy)
      ..scale(layer.scale);
    if (layer.rotate != 0) {
      canvas
        ..translate(12, 12)
        ..rotate(layer.rotate * math.pi / 180)
        ..translate(-12, -12);
    }
    final path = _layerPath(layer);
    if (layer.line) {
      canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.width,
      );
    } else {
      canvas.drawPath(path, paint..style = PaintingStyle.fill);
      if (layer.outline > 0) {
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = layer.outline,
        );
      }
    }
    canvas.restore();
  }
  canvas.restore();
}

/// Geometry of the game disc on a 100 box (J6k, « Mélange 2 »): a gauge of
/// round segments around a coloured disc with a deep rim and a faint
/// vertical gradient, the glyph on top.
abstract final class _Disc {
  static const double gaugeRadius = 45.5;
  static const double gaugeStroke = 4.6;
  static const double gaugeGap = 0.2;
  static const double rimRadius = 38;
  static const double faceRadius = 36.8;
  static const double faceCenterY = 49;
  static const double glyphBox = 44.4;
  static const double faceTopAlpha = 0.84;
  static const double faceSolidStop = 0.6;

  /// Width of the « current » ring and its gap to the disc, in px.
  static const double ringStroke = 3;
  static const double ringInset = 7;
}

/// Disc colors of a locked (not reached) status or badge level.
({Color disc, Color deep, Color glyph, Color ink}) _locked(bool dark) =>
    dark
        ? (
          disc: BirdyBrand.lockedDiscDark,
          deep: BirdyBrand.lockedDeepDark,
          glyph: BirdyBrand.lockedGlyphDark,
          ink: BirdyBrand.lockedInkDark,
        )
        : (
          disc: BirdyBrand.lockedDisc,
          deep: BirdyBrand.lockedDeep,
          glyph: BirdyBrand.lockedGlyph,
          ink: BirdyBrand.lockedInk,
        );

/// The one disc of the game: status emblems and badge medals share it.
/// [segments] gauge segments around, the first [lit] in [gaugeOn]; a
/// [glyph] (with [tones], or flat in [glyphColor]) or a [child] in the
/// middle; [ring] draws the « current » ring outside.
class GameDisc extends StatelessWidget {
  const GameDisc({
    super.key,
    required this.size,
    required this.color,
    required this.deep,
    required this.segments,
    required this.lit,
    required this.gaugeOn,
    this.glyph,
    this.glyphColor = BirdyBrand.white,
    this.tones,
    this.ring,
    this.partial,
    this.child,
  });

  final double size;
  final Color color;
  final Color deep;
  final int segments;
  final int lit;
  final Color gaugeOn;
  final Glyph? glyph;
  final Color glyphColor;
  final GlyphTones? tones;
  final Color? ring;

  /// 0 to 1: share of the segment after the lit ones drawn in [gaugeOn].
  final double? partial;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _DiscPainter(this),
      child: child == null ? null : Center(child: child),
    ),
  );
}

class _DiscPainter extends CustomPainter {
  const _DiscPainter(this.disc);

  final GameDisc disc;

  @override
  void paint(Canvas canvas, Size size) {
    var radius = size.width / 2;
    final center = size.center(Offset.zero);
    final ring = disc.ring;
    if (ring != null) {
      canvas.drawCircle(
        center,
        radius - _Disc.ringStroke / 2,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = _Disc.ringStroke,
      );
      radius -= _Disc.ringInset;
    }
    canvas
      ..save()
      ..translate(center.dx - radius, center.dy - radius)
      ..scale(radius * 2 / 100);

    final gaugeRect = Rect.fromCircle(
      center: const Offset(50, 50),
      radius: _Disc.gaugeRadius,
    );
    final sweep = 2 * math.pi / disc.segments;
    final segment =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _Disc.gaugeStroke
          ..strokeCap = StrokeCap.round;
    for (var k = 0; k < disc.segments; k++) {
      segment.color =
          k < disc.lit
              ? disc.gaugeOn
              : BirdyBrand.gaugeOff.withValues(alpha: BirdyAlpha.gaugeOff);
      canvas.drawArc(
        gaugeRect,
        -math.pi / 2 + k * sweep + _Disc.gaugeGap / 2,
        sweep - _Disc.gaugeGap,
        false,
        segment,
      );
    }
    final partial = disc.partial;
    if (partial != null && partial > 0 && disc.lit < disc.segments) {
      canvas.drawArc(
        gaugeRect,
        -math.pi / 2 + disc.lit * sweep + _Disc.gaugeGap / 2,
        (sweep - _Disc.gaugeGap) * partial.clamp(0.0, 1.0),
        false,
        segment..color = disc.gaugeOn,
      );
    }

    canvas.drawCircle(
      const Offset(50, 50),
      _Disc.rimRadius,
      Paint()..color = disc.deep,
    );
    final face = Rect.fromCircle(
      center: const Offset(50, _Disc.faceCenterY),
      radius: _Disc.faceRadius,
    );
    canvas.drawCircle(
      face.center,
      _Disc.faceRadius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            disc.color.withValues(alpha: _Disc.faceTopAlpha),
            disc.color,
            disc.color,
          ],
          stops: const [0, _Disc.faceSolidStop, 1],
        ).createShader(face),
    );

    final glyph = disc.glyph;
    if (glyph != null) {
      paintGlyph(
        canvas,
        Rect.fromCenter(
          center: const Offset(50, 50),
          width: _Disc.glyphBox,
          height: _Disc.glyphBox,
        ),
        glyph,
        disc.glyphColor,
        tones: disc.tones,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiscPainter old) =>
      old.disc.color != disc.color ||
      old.disc.deep != disc.deep ||
      old.disc.segments != disc.segments ||
      old.disc.lit != disc.lit ||
      old.disc.gaugeOn != disc.gaugeOn ||
      old.disc.glyph != disc.glyph ||
      old.disc.glyphColor != disc.glyphColor ||
      old.disc.tones != disc.tones ||
      old.disc.ring != disc.ring ||
      old.disc.partial != disc.partial;
}

/// Status disc with its glyph and its gauge of one segment per status, lit
/// up to the status' rank. [reached] false: the grey look of a status to
/// come, gauge unlit.
class StatusEmblem extends StatelessWidget {
  const StatusEmblem({
    super.key,
    required this.status,
    this.size = 36,
    this.reached = true,
    this.current = false,
    this.gaugeReveal = 1,
    this.progress,
    this.semanticLabel,
  });

  final StatusDef status;
  final double size;
  final bool reached;

  /// 3 px ink ring with a 4 px gap (the ladder's current status).
  final bool current;

  /// 0 to 1: share of the lit segments shown, to make them appear one by
  /// one (the « Nouveau statut » screen).
  final double gaugeReveal;

  /// 0 to 1, optional: progress towards the next status, drawn as a partial
  /// arc in the segment after the lit ones (home and profile level cards).
  final double? progress;

  /// Spoken label of the emblem (the progress), when it carries one.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final locked = _locked(c.isDark);
    final disc = GameDisc(
      size: size,
      color: reached ? status.color : locked.disc,
      deep: reached ? status.deep : locked.deep,
      segments: GameConfig.statuses.length,
      lit: reached ? (status.rank * gaugeReveal).ceil() : 0,
      gaugeOn: status.gauge,
      glyph: status.glyph,
      tones:
          reached
              ? GlyphTones(
                main: status.glyphMain,
                accent: status.glyphAccent,
                deep: status.glyphInk,
                real: true,
              )
              : GlyphTones(
                main: locked.glyph,
                accent: locked.glyph,
                deep: locked.ink,
              ),
      ring: current ? c.text1 : null,
      partial: progress,
    );
    return semanticLabel == null
        ? disc
        : Semantics(label: semanticLabel, image: true, child: disc);
  }
}

/// Badge medal: the same disc as a status emblem, flat in bronze, silver or
/// gold once earned with a gauge of three segments (1, 2, 3 plumes), grey
/// while locked. Carries an icon or a [glyph].
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required this.tier,
    this.icon,
    this.glyph,
    this.child,
    this.size = 52,
  });

  /// 0 (locked) to 3.
  final int tier;
  final IconData? icon;
  final Glyph? glyph;

  /// Replaces the icon/glyph face (the palmarès podium's rank number,
  /// J6f-f), built with the medal's own ink color.
  final Widget Function(Color ink)? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final locked = _locked(c.isDark);
    final metal = tier == 0 ? null : GameConfig.badgeMedals[tier - 1];
    final ink = metal?.ink ?? c.text2;
    final glyphSize = size / 2;
    final face =
        child != null
            ? child!(ink)
            : glyph != null
            ? CustomPaint(
              size: Size.square(glyphSize),
              painter: _GlyphPainter(glyph!, ink),
            )
            : Icon(icon, size: glyphSize, color: ink, fill: metal == null ? 0 : 1);
    return GameDisc(
      size: size,
      color: metal?.base ?? locked.disc,
      deep: metal?.deep ?? locked.deep,
      segments: GameConfig.badgeMedals.length,
      lit: tier,
      gaugeOn: metal?.deep ?? locked.deep,
      child: face,
    );
  }
}

/// A [Glyph] painted at [size] (the plumes counter pill, J6f).
class GlyphIcon extends StatelessWidget {
  const GlyphIcon({super.key, required this.glyph, required this.color, this.size = 24});

  final Glyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(glyph, color),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintGlyph(canvas, Offset.zero & size, glyph, color);

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// Three 6 px dots, [filled] of them in ink.
class TierDots extends StatelessWidget {
  const TierDots({super.key, required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: BirdySpace.snug,
            height: BirdySpace.snug,
            margin: const EdgeInsets.symmetric(horizontal: BirdySpace.xxs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? c.text1 : c.borderStrong,
            ),
          ),
      ],
    );
  }
}

/// A bar of [count] equal segments, [filled] of them colored, the rest on
/// [track] (J6f: the level ladder's info box, the weekly challenge). Falls
/// back to one continuous [BirdyProgressBar] past
/// [BirdySizes.segmentBarMax] segments (too many slivers to read).
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({
    super.key,
    required this.count,
    required this.filled,
    required this.color,
    required this.track,
    this.height = BirdySizes.segmentHeight, // FORK: J6h thinner bar (6)
  });

  final int count;
  final int filled;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    if (count > BirdySizes.segmentBarMax) {
      return BirdyProgressBar(
        value: count == 0 ? 0 : filled / count,
        color: color,
        track: track,
      );
    }
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: BirdySpace.xxs),
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: i < filled ? color : track,
                borderRadius: BorderRadius.circular(BirdyRadii.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Série chip of the home top bar (SPEC.md 5.7): calendar and « 9 jours ».
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.days, required this.onTap});

  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Semantics(
      button: true,
      label: l10n.forkStreakChipLabel(days),
      child: ExcludeSemantics(
        child: Material(
          color: c.surface1,
          shape: StadiumBorder(side: BorderSide(color: c.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BirdySizes.target),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 14, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.calendarToday, size: BirdyGlyph.xl, color: c.accentText),
                    const SizedBox(width: BirdySpace.s),
                    Text(
                      l10n.forkStreakChip(days),
                      style: BirdyText.label.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
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
