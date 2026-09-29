/// Halo of the rare bird card (J6h, AppEcoute mockup « RareHalo »): drawn
/// around a picture of [size], under it. On arrival, once (~2.4 s): the
/// dotted ring draws itself in, turning, the halo pulses twice and three
/// diamonds pop one after the other. The ring then stays, dotted. With
/// reduced motion: only the dotted ring, still. Once the bird is confirmed
/// ([solid]) the ring is full and the halo glows softly, still.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/birdy_sparkles.dart';
import '../design/widgets/dashed_border.dart';

class RareHalo extends StatefulWidget {
  const RareHalo({
    super.key,
    required this.size,
    this.color = BirdyBrand.oriole,
    this.solid = false,
  });

  /// Diameter of the picture the halo surrounds.
  final double size;
  final Color color;

  /// Confirmed: full ring and a steady glow, no arrival.
  final bool solid;

  @override
  State<RareHalo> createState() => _RareHaloState();
}

class _RareHaloState extends State<RareHalo>
    with SingleTickerProviderStateMixin {
  static final Duration _total =
      BirdyMotion.rareGlowDelay +
      BirdyMotion.rareGlowPulse * BirdyMotion.rareGlowPulses;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || BirdyMotion.reduced(context)) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ring state at [ms] since the arrival: turns, scale, opacity. Two
  /// eased legs (the keyframes of the mockup): appear, then keep turning.
  static ({double turns, double scale, double opacity}) ringAt(double ms) {
    final t = (ms / BirdyMotion.rareRing.inMilliseconds).clamp(0.0, 1.0);
    const at = BirdyMotion.rareRingAppearAt;
    if (t < at) {
      final u = BirdyMotion.standard.transform(t / at);
      return (
        turns: BirdyMotion.rareRingFromTurns * (1 - u),
        scale:
            BirdyMotion.rareRingFromScale +
            (1 - BirdyMotion.rareRingFromScale) * u,
        opacity: u,
      );
    }
    final u = BirdyMotion.standard.transform((t - at) / (1 - at));
    return (turns: BirdyMotion.rareRingToTurns * u, scale: 1, opacity: 1);
  }

  /// Glow state at [ms]: opacity and scale of the pulsing disc.
  static ({double opacity, double scale}) glowAt(double ms) {
    final g = ms - BirdyMotion.rareGlowDelay.inMilliseconds;
    final span =
        BirdyMotion.rareGlowPulse.inMilliseconds * BirdyMotion.rareGlowPulses;
    if (g <= 0 || g >= span) return (opacity: 0, scale: 1);
    final p =
        (g % BirdyMotion.rareGlowPulse.inMilliseconds) /
        BirdyMotion.rareGlowPulse.inMilliseconds;
    const ease = Curves.easeOut;
    if (p < 0.5) {
      final u = ease.transform(p / 0.5);
      return (
        opacity: BirdyMotion.rareGlowPeakOpacity * u,
        scale: 1 + (BirdyMotion.rareGlowPeakScale - 1) * u,
      );
    }
    final u = ease.transform((p - 0.5) / 0.5);
    return (
      opacity: BirdyMotion.rareGlowPeakOpacity * (1 - u),
      scale:
          BirdyMotion.rareGlowPeakScale +
          (BirdyMotion.rareGlowEndScale - BirdyMotion.rareGlowPeakScale) * u,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = BirdyMotion.reduced(context);
    final size = widget.size;
    final outer = size + 2 * BirdySizes.rareRingGap;
    Widget disc(double opacity, double scale) => Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: opacity),
        ),
        child: SizedBox.square(dimension: size),
      ),
    );
    Widget ring({double turns = 0, double scale = 1, double opacity = 1}) =>
        Positioned(
          left: -BirdySizes.rareRingGap,
          top: -BirdySizes.rareRingGap,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: turns * 2 * math.pi,
                child:
                    widget.solid
                        ? DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.color,
                              width: BirdySizes.rareRingStroke,
                            ),
                          ),
                          child: SizedBox.square(dimension: outer),
                        )
                        : CustomPaint(
                          size: Size.square(outer),
                          painter: DashedBorderPainter(
                            color: widget.color,
                            radius: outer,
                            strokeWidth: BirdySizes.rareRingStroke,
                            dash: BirdySizes.rareRingDash,
                            gap: BirdySizes.rareRingDashGap,
                          ),
                        ),
              ),
            ),
          ),
        );

    final Widget layers;
    if (widget.solid) {
      layers = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: disc(BirdyMotion.tintMaxOpacity, BirdyMotion.ringScale),
          ),
          ring(),
        ],
      );
    } else if (reduced) {
      layers = Stack(clipBehavior: Clip.none, children: [ring()]);
    } else {
      layers = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final ms = _controller.value * _total.inMilliseconds;
          final glow = glowAt(ms);
          final r = ringAt(ms);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: disc(glow.opacity, glow.scale)),
              ring(turns: r.turns, scale: r.scale, opacity: r.opacity),
            ],
          );
        },
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: layers),
            if (!widget.solid)
              BirdySparkles(
                offsets: BirdySparkles.aroundRareBird,
                color: widget.color,
                delay: BirdyMotion.rareDiamondDelay,
                stagger: BirdyMotion.rareDiamondStagger,
                pop: BirdyMotion.rareDiamondPop,
                icon: AppIcons.diamond,
              ),
          ],
        ),
      ),
    );
  }
}
