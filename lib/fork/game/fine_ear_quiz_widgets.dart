/// Pieces of the « Qui chante ? » screen (J6e, Quiz v2): the bird as shown,
/// its drawn icon or photo, the dark listening well, the Oreille fine bar
/// and balanced text. The intro, the trail, the stage, the answer cards and
/// the result live in their own files, exported here.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/models/taxonomy_species.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/birdygo_silhouette.dart';
import '../design/species_accents.dart';
import '../design/species_tint.dart';
import '../design/widgets/species_avatar.dart';
import 'game_config.dart';
import 'game_progress.dart';
import 'quiz_fx.dart';

export 'quiz_choices.dart';
export 'quiz_intro.dart';
export 'quiz_result.dart';
export 'quiz_stage.dart';
export 'quiz_trail.dart';

/// The bird of the question, as shown on screen.
class QuizBird {
  const QuizBird({
    required this.scientificName,
    required this.latin,
    required this.name,
    this.image,
    this.species,
  });

  final String scientificName;

  /// Scientific name to show (taxonomy-canonical).
  final String latin;

  /// Common name in the species language.
  final String name;

  /// Bundled photo (the quiz shows photos only, no drawn icons).
  final ImageProvider? image;

  /// Taxonomy entry, for the photo credit.
  final TaxonomySpecies? species;

  SpeciesTint get tint => SpeciesAccents.tintOf(scientificName);
}

/// Oreille fine for [correct] right answers.
BadgeProgress fineEarBadge(int correct) =>
    BadgeProgress(kind: BadgeKind.fineEar, value: correct);

/// Share of the way from the badge's current tier to its next one.
double toNextTier(BadgeProgress badge) {
  final next = badge.nextTarget;
  if (next == null) return 1;
  final from = badge.tier == 0 ? 0 : badge.tiers[badge.tier - 1];
  return ((badge.value - from) / (next - from)).clamp(0, 1).toDouble();
}

/// A bird in a round halo of its tint: its photo at [iconSize]. [muted]
/// turns it grey (a missed bird).
class QuizBirdArt extends StatelessWidget {
  const QuizBirdArt({
    super.key,
    required this.bird,
    required this.size,
    required this.iconSize,
    this.muted = false,
    this.background,
  });

  final QuizBird bird;
  final double size;
  final double iconSize;
  final bool muted;

  /// Halo color; the bird's halo by default.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final tint = bird.tint;
    final art = SpeciesAvatar(
      image: bird.image,
      tint: tint,
      size: iconSize,
      muted: muted,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? tint.halo,
      ),
      child: ExcludeSemantics(child: art),
    );
  }
}

/// The dark listening well (both themes): the spectrogram gradient with a
/// faint line every 24 px, radius 28, and an optional faint radial
/// highlight (the hero and the stage each have their own size and center).
class QuizWell extends StatelessWidget {
  const QuizWell({
    super.key,
    required this.child,
    this.highlightRadius,
    this.highlightCenter = const Alignment(0, -0.04),
  });

  final Widget child;

  /// Radius of the [BirdyBrand.wellHighlight] radial glow; no glow when
  /// null.
  final double? highlightRadius;
  final Alignment highlightCenter;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(BirdyRadii.hero),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BirdyBrand.wellTop, BirdyBrand.wellBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (highlightRadius case final radius?)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: highlightCenter,
                  radius: 1,
                  colors: const [BirdyBrand.wellHighlight, Color(0x00173A55)],
                  transform: QuizFixedRadius(radius, center: highlightCenter),
                ),
              ),
            ),
          CustomPaint(painter: const _WellLines(), child: child),
        ],
      ),
    ),
  );
}

class _WellLines extends CustomPainter {
  const _WellLines();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = BirdyBrand.mist.withValues(alpha: 0.05);
    for (var y = 23.0; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_WellLines oldDelegate) => false;
}

/// The dashed mystery disc on the well: the BirdyGo silhouette in white at
/// 35 %, the oriole question mark, inside a 2 dp dashed oriole ring at
/// 60 % (DESIGN.md decision: the mystery bird reads as BirdyGo's own bird,
/// not a generic species icon).
class QuizMysteryDisc extends StatelessWidget {
  const QuizMysteryDisc({
    super.key,
    required this.size,
    required this.silhouette,
  });

  final double size;
  final double silhouette;

  /// The « ? » is [BirdySizes.quizMark] tall on a [_markRef] silhouette (the
  /// intro's disc at full size) and scales with it; tilted like the mockup
  /// (degrees).
  static const double _markRef = 104;
  static const double _markTilt = -8;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      foregroundPainter: QuizDashedCircle(
        color: BirdyBrand.oriole.withValues(alpha: 0.6),
      ),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: BirdyBrand.mist.withValues(alpha: 0.08),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            BirdyGoSilhouetteIcon(
              size: silhouette,
              color: BirdyBrand.mist.withValues(alpha: 0.35),
              muted: true,
            ),
            // Centered on the bird's wing, not on the disc: the mark reads
            // as sitting on the bird's body whatever the disc's margin.
            Transform.translate(
              offset: birdyGoWingCenter * silhouette,
              child: Transform.rotate(
                angle: _markTilt * math.pi / 180,
                child: Text(
                  '?',
                  style: BirdyText.display.copyWith(
                    fontSize: BirdySizes.quizMark * silhouette / _markRef,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: BirdyBrand.oriole,
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

/// A 1.5 px dashed circle, inside the box.
class QuizDashedCircle extends CustomPainter {
  const QuizDashedCircle({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.5;
    final radius = size.shortestSide / 2 - stroke / 2;
    final center = size.center(Offset.zero);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke;
    // CSS dashed borders: dashes about three times the width.
    const dash = 4.5, gap = 3.0;
    final circumference = 2 * 3.141592653589793 * radius;
    final count = (circumference / (dash + gap)).floor();
    final step = 2 * 3.141592653589793 / count;
    final sweep = step * dash / (dash + gap);
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * step, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(QuizDashedCircle oldDelegate) =>
      oldDelegate.color != color;
}

/// The mystery bird's speech bubble: a white pill with a tail, wiggling
/// forever (Quiz v2 mockup, J6f-e).
class QuizSpeechBubble extends StatelessWidget {
  const QuizSpeechBubble({super.key, required this.label, this.tailLeft});

  final String label;

  /// Offset of the little tail from the bubble's left edge; centred when
  /// null (the intro's bubble, over the mystery disc).
  final double? tailLeft;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    // The tail hangs from the bubble's outer bottom edge (half of it shows
    // below), painted under the pill so it never covers the label.
    final tail = Transform.rotate(
      angle: 0.785398,
      child: Container(width: 10, height: 10, color: c.surface1),
    );
    return QuizWiggle(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: tailLeft ?? 0,
            right: tailLeft == null ? 0 : null,
            bottom: -5,
            child: tailLeft == null ? Center(child: tail) : tail,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: BorderRadius.circular(BirdyRadii.pill),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 16),
              ],
            ),
            child: Text(
              label,
              style: BirdyText.species.copyWith(color: c.text1, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lichen progress bar, 8 dp. With [from], it fills from there to [value]
/// once, [QuizMotion.fill] after [QuizMotion.fillDelay] (reduced motion:
/// [value] straight away).
class QuizBadgeBar extends StatelessWidget {
  const QuizBadgeBar({super.key, required this.value, this.from});

  final double value;
  final double? from;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    Widget bar(double v) => Container(
      height: 8,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: c.lineOpaque,
        borderRadius: BorderRadius.circular(BirdyRadii.pill),
      ),
      child: FractionallySizedBox(
        widthFactor: v.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: c.sure.foreground,
            borderRadius: BorderRadius.circular(BirdyRadii.pill),
          ),
        ),
      ),
    );
    final start = from;
    if (start == null) return bar(value);
    return QuizOnce(
      duration: QuizMotion.fill,
      delay: QuizMotion.fillDelay,
      builder:
          (context, t, _) =>
              bar(start + (value - start) * QuizMotion.ease.transform(t)),
    );
  }
}

/// [filled] of [total] segments in a row (Quiz v2 mockup's badge progress
/// dots): a continuous look when they are many, one dot per right answer
/// when there are few.
class QuizProgressSegments extends StatelessWidget {
  const QuizProgressSegments({
    super.key,
    required this.total,
    required this.filled,
  });

  final int total;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return SizedBox(
      height: 12,
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < filled ? c.sure.foreground : c.lineOpaque,
                  borderRadius: BorderRadius.circular(BirdyRadii.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Text wrapped on balanced lines (CSS text-wrap: balance): the narrowest
/// width up to [maxWidth] that keeps the same number of lines.
class QuizBalancedText extends StatelessWidget {
  const QuizBalancedText(
    this.span, {
    super.key,
    this.maxWidth = double.infinity,
    this.textAlign = TextAlign.center,
    this.maxLines,
  });

  final InlineSpan span;
  final double maxWidth;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final limit =
          constraints.maxWidth.isFinite
              ? (maxWidth < constraints.maxWidth
                  ? maxWidth
                  : constraints.maxWidth)
              : maxWidth;
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final style = DefaultTextStyle.of(context).style;
      TextPainter layout(double width) => TextPainter(
        text: TextSpan(style: style, children: [span]),
        textDirection: direction,
        textScaler: scaler,
        textAlign: textAlign,
        maxLines: maxLines,
      )..layout(maxWidth: width);
      var width = limit;
      if (limit.isFinite) {
        final full = layout(limit);
        final lines = full.computeLineMetrics().length;
        // Never narrower than the longest word: no word is cut.
        final longestWord = full.minIntrinsicWidth;
        full.dispose();
        if (lines > 1) {
          var low = limit / lines;
          if (longestWord > low) low = longestWord;
          var high = limit;
          while (high - low > 1) {
            final mid = (low + high) / 2;
            final probe = layout(mid);
            final fits = probe.computeLineMetrics().length <= lines;
            probe.dispose();
            if (fits) {
              high = mid;
            } else {
              low = mid;
            }
          }
          width = high.ceilToDouble();
        }
      }
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Text.rich(
          span,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
      );
    },
  );
}
