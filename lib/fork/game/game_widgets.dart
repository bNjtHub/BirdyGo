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

/// Paints a 24-grid [Glyph] in [rect].
void paintGlyph(Canvas canvas, Rect rect, Glyph glyph, Color color) {
  final scale = rect.width / 24;
  canvas
    ..save()
    ..translate(rect.left, rect.top)
    ..scale(scale);
  final stroke =
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
  for (final d in glyph.paths) {
    canvas.drawPath(_path(d), stroke);
  }
  for (final (x, y, r) in glyph.circles) {
    canvas.drawCircle(Offset(x, y), r, stroke);
  }
  final fill = Paint()..color = color;
  for (final d in glyph.filled) {
    canvas.drawPath(_path(d), fill);
  }
  canvas.restore();
}

/// Status disc with its glyph. [reached] false: the muted look of a status
/// to come.
class StatusEmblem extends StatelessWidget {
  const StatusEmblem({
    super.key,
    required this.status,
    this.size = 36,
    this.reached = true,
    this.current = false,
    this.innerRing = false,
  });

  final StatusDef status;
  final double size;
  final bool reached;

  /// 3 px ink ring with a 4 px gap (the ladder's current status).
  final bool current;

  /// Thin white ring near the edge, at half opacity (J6f, reached levels on
  /// the ladder and the level ring): the mockup's premium-medal touch.
  final bool innerRing;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _EmblemPainter(
        status: status,
        fill:
            reached
                ? status.color
                : (c.isDark
                    ? BirdyBrand.mist.withValues(alpha: 0.10)
                    : BirdyBrand.mistTrack),
        ink:
            reached
                ? BirdyBrand.ink
                : (c.isDark ? BirdyBrand.mist : BirdyBrand.ink).withValues(
                  alpha: 0.4,
                ),
        ring: current ? c.text1 : null,
        innerRing: reached && innerRing,
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter({
    required this.status,
    required this.fill,
    required this.ink,
    this.ring,
    this.innerRing = false,
  });

  final StatusDef status;
  final Color fill;
  final Color ink;
  final Color? ring;
  final bool innerRing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    var radius = size.width / 2;
    if (ring != null) {
      canvas.drawCircle(
        center,
        radius - 1.5,
        Paint()
          ..color = ring!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      radius -= 7;
    }
    canvas.drawCircle(center, radius, Paint()..color = fill);
    if (innerRing) {
      canvas.drawCircle(
        center,
        radius * 0.86,
        Paint()
          ..color = BirdyBrand.white.withValues(
            alpha: BirdyAlpha.emblemInnerRing,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.05,
      );
    }
    final glyph = radius * 2 * 14 / 24;
    paintGlyph(
      canvas,
      Rect.fromCenter(center: center, width: glyph, height: glyph),
      status.glyph,
      ink,
    );
  }

  @override
  bool shouldRepaint(_EmblemPainter old) =>
      old.status != status ||
      old.fill != fill ||
      old.ink != ink ||
      old.ring != ring ||
      old.innerRing != innerRing;
}

/// Progress ring around the current status (SPEC.md 5.7): track, arc of
/// [progress] in the status color, disc and glyph. Before the first status,
/// the first one in its muted look.
class StatusRing extends StatelessWidget {
  const StatusRing({
    super.key,
    required this.status,
    required this.progress,
    required this.semanticLabel,
    this.size = 96,
  });

  final StatusDef? status;
  final double progress;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final shown = status ?? GameConfig.statuses.first;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: progress,
                track: c.progressTrack,
                color: shown.color,
              ),
            ),
            StatusEmblem(
              status: shown,
              size: size * 58 / 84,
              reached: status != null,
              innerRing: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 6 / 84;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width * 37 / 84,
    );
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}

/// Badge medal: bronze, silver or gold once earned (a metal gradient, a rim
/// and an engraved inner ring), a flat disc in the theme neutrals while
/// locked. Carries an icon or a [glyph].
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
    final metal = tier == 0 ? null : GameConfig.badgeMedals[tier - 1];
    final ink = metal?.ink ?? c.text2;
    final rim = math.max(1.5, size / 26);
    final glyphSize = size / 2;
    final face =
        child != null
            ? child!(ink)
            : glyph != null
            ? CustomPaint(
              size: Size.square(glyphSize),
              painter: _GlyphPainter(glyph!, ink),
            )
            : Icon(icon, size: glyphSize, color: ink);

    if (metal == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.lineOpaque,
          shape: BoxShape.circle,
          border: Border.all(color: c.border, width: rim),
        ),
        alignment: Alignment.center,
        child: face,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: metal.rim, width: rim),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [metal.highlight, metal.base, metal.shadow],
          stops: const [0, .55, 1],
        ),
      ),
      padding: EdgeInsets.all(size * .1),
      // Engraved ring: light on the lower right, shade on the upper left,
      // as if struck into the metal.
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [metal.base, metal.highlight.withValues(alpha: .9)],
          ),
          border: Border.all(
            color: metal.shadow.withValues(alpha: .55),
            width: BirdyStroke.hairline,
          ),
        ),
        alignment: Alignment.center,
        child: face,
      ),
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
