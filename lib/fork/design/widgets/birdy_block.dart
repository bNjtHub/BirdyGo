/// Blocks of the J6f layout (« App finale » boards): a block stands out by
/// the tint of its fill, never by a grey border. Also its progress bar and
/// ring.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// Fill of a [BirdyBlock].
enum BirdyBlockTone {
  /// White ([BirdyColors.surface1]).
  plain,

  /// Martin-pêcheur tonal ([BirdyColors.tonal]).
  tonal,

  /// Lichen of the Sûr level ([LevelColors.background] of `sure`).
  sure,

  /// Loriot container ([BirdyColors.orioleContainer]).
  oriole,

  /// White with the dashed outline of « À vérifier » (`toCheck`).
  toCheck,
}

/// Fill color of [tone] on the current theme.
Color birdyBlockColor(BirdyColors c, BirdyBlockTone tone) => switch (tone) {
  BirdyBlockTone.plain || BirdyBlockTone.toCheck => c.surface1,
  BirdyBlockTone.tonal => c.tonal,
  BirdyBlockTone.sure => c.sure.background,
  BirdyBlockTone.oriole => c.orioleContainer,
};

/// Track of a bar or ring on a tinted block: white on light, a faint Brume
/// on dark (white would glare on the translucent dark tints).
Color birdyTrackOnTint(BirdyColors c) =>
    c.isDark
        ? BirdyBrand.mist.withValues(alpha: BirdyAlpha.trackOnTintDark)
        : c.surface1.withValues(alpha: BirdyAlpha.trackOnTint);

/// Fill of a dashed slot on a tinted block: white on light, the page
/// background on dark (a hole in the block).
Color birdySlotFill(BirdyColors c) => (c.isDark ? c.background : c.surface1)
    .withValues(alpha: BirdyAlpha.slotFill);

/// A rounded block of the J6f layout. With [onTap] the whole block is one
/// target, pressed like every BirdyGo card.
class BirdyBlock extends StatelessWidget {
  const BirdyBlock({
    super.key,
    required this.child,
    this.tone = BirdyBlockTone.plain,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.all(BirdySpace.l),
    this.radius = BirdyRadii.card,
    this.semanticLabel,
  });

  final Widget child;
  final BirdyBlockTone tone;

  /// Overrides the tone's fill (a species tint).
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Replaces the children's semantics with one label (a whole-block link).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    Widget content = Padding(padding: padding, child: child);
    if (tone == BirdyBlockTone.toCheck) {
      content = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: c.toCheck.foreground,
          radius: radius,
        ),
        child: content,
      );
    }
    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        button: onTap != null,
        excludeSemantics: true,
        child: content,
      );
    }
    final block = Material(
      color: color ?? birdyBlockColor(c, tone),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    return onTap == null ? block : Pressable(child: block);
  }
}

/// Rounded progress bar of a block.
class BirdyProgressBar extends StatelessWidget {
  const BirdyProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.height = BirdySizes.progressBar,
  });

  /// 0 to 1.
  final double value;
  final Color color;
  final Color track;

  /// [BirdySizes.countdownBar] for a countdown (J6h).
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BirdyRadii.pill),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          color: color,
          backgroundColor: track,
          minHeight: height,
        ),
      ),
    );
  }
}

/// Progress ring with [child] in its middle (« 5/8 »).
class BirdyProgressRing extends StatelessWidget {
  const BirdyProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.size = BirdySizes.ring,
    this.stroke = BirdySizes.ringStroke,
    this.child,
  });

  /// 0 to 1.
  final double value;
  final Color color;
  final Color track;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          color: color,
          track: track,
          stroke: stroke,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
