/// Motion of « Qui chante ? » (J6e, Quiz v2 mockup, quiz-fx.js): the quiz
/// is an authorized exception to DESIGN.md's restraint rules (slight
/// bounce, loops, confetti, effects over 500 ms). Every effect here stops
/// with reduced motion ([BirdyMotion.reduced]): the widgets show their
/// final, still state. The confetti are the shared `BirdyConfetti`
/// (lib/fork/design/widgets/birdy_confetti.dart).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';

/// Timings and easings of the mockup's CSS keyframes.
abstract final class QuizMotion {
  /// cubic-bezier(0.23, 1, 0.32, 1).
  static const Curve ease = BirdyMotion.standard;

  /// CSS ease-in-out and ease-out.
  static const Curve inOut = Curves.easeInOut;
  static const Curve out = Curves.easeOut;

  static const Duration fade = Duration(milliseconds: 220);
  static const Duration revealFade = Duration(milliseconds: 200);
  static const Duration float = Duration(milliseconds: 3000);
  static const Duration floatIntro = Duration(milliseconds: 3200);
  static const Duration floatStep = Duration(milliseconds: 400);
  static const Duration bar = Duration(milliseconds: 900);
  static const Duration barIntro = Duration(milliseconds: 1400);
  static const Duration barIntroStep = Duration(milliseconds: 120);
  static const Duration pulse = Duration(milliseconds: 1600);
  static const Duration spin = Duration(seconds: 24);
  static const Duration trail = Duration(milliseconds: 450);
  static const Duration stoneRight = Duration(milliseconds: 450);
  static const Duration stoneWrong = Duration(milliseconds: 300);
  static const Duration pill = Duration(milliseconds: 350);
  static const Duration birdPop = Duration(milliseconds: 500);
  static const Duration rise = Duration(milliseconds: 300);
  static const Duration cheerDelay = Duration(milliseconds: 150);
  static const Duration sentenceDelay = Duration(milliseconds: 220);
  static const Duration cardPop = Duration(milliseconds: 450);
  static const Duration wobble = Duration(milliseconds: 420);
  static const Duration flyUp = Duration(milliseconds: 1400);
  static const Duration flyUpDelay = Duration(milliseconds: 150);
  static const Duration nextRise = Duration(milliseconds: 250);
  static const Duration nextDelay = Duration(milliseconds: 200);

  /// A wrong answer: the right song restarts after the soft note (0.35 s).
  static const Duration replayAfterSoft = Duration(milliseconds: 500);
  static const Duration fill = Duration(milliseconds: 900);
  static const Duration fillDelay = Duration(milliseconds: 450);
  static const Duration star = Duration(milliseconds: 450);
  static const Duration starDelay = Duration(milliseconds: 250);
  static const Duration starStep = Duration(milliseconds: 160);
  static const Duration recap = Duration(milliseconds: 400);
  static const Duration recapDelay = Duration(milliseconds: 200);
  static const Duration recapStep = Duration(milliseconds: 50);
  static const Duration cardStep = Duration(milliseconds: 80);
  static const Duration medal = Duration(milliseconds: 500);
  static const Duration medalDelay = Duration(milliseconds: 700);
  static const Duration newTier = Duration(milliseconds: 400);
  static const Duration newTierDelay = Duration(milliseconds: 900);
  static const Duration knob = Duration(milliseconds: 180);
  static const Duration wiggle = Duration(milliseconds: 3000);
  static const Duration ring = Duration(milliseconds: 1400);
  static const Duration ringStep = Duration(milliseconds: 700);
  static const Duration bounce = Duration(milliseconds: 2400);

  /// cubic-bezier(0.37, 0, 0.63, 1): qz-bounce's own easing.
  static const Curve bounceEase = Cubic(0.37, 0, 0.63, 1);
}

/// A radial gradient whose radius is [radius] logical pixels regardless of
/// the box's size, centered at [center] (the well's radial highlight, the
/// result score card's Loriot glow).
class QuizFixedRadius extends GradientTransform {
  const QuizFixedRadius(this.radius, {this.center = Alignment.topCenter});

  final double radius;
  final Alignment center;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // RadialGradient(radius: 1) spans the shortest side; scale it to
    // [radius] around [center].
    final scale = radius / bounds.shortestSide;
    final c = center.withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}

/// qz-bounce: a small forever bob and tilt, for the mystery disc.
class QuizBounce extends StatelessWidget {
  const QuizBounce({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => QuizLoop(
    isolate: true,
    period: QuizMotion.bounce,
    delay: delay,
    child: child,
    builder: (context, t, child) {
      final dy = quizKeyframes(
        t,
        const [0, 0.5, 1],
        const [0, -8, 0],
        QuizMotion.bounceEase,
      );
      final deg = quizKeyframes(
        t,
        const [0, 0.5, 1],
        const [-3, 3, -3],
        QuizMotion.bounceEase,
      );
      return Transform.translate(
        offset: Offset(0, dy),
        child: Transform.rotate(angle: deg * math.pi / 180, child: child),
      );
    },
  );
}

/// Value at [t] (0 to 1) of keyframes [values] at [stops], [curve] applied
/// to each interval, like CSS animation-timing-function.
double quizKeyframes(
  double t,
  List<double> stops,
  List<double> values,
  Curve curve,
) {
  if (t <= stops.first) return values.first;
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i]) {
      final local = (t - stops[i - 1]) / (stops[i] - stops[i - 1]);
      return values[i - 1] +
          (values[i] - values[i - 1]) * curve.transform(local.clamp(0, 1));
    }
  }
  return values.last;
}

/// A looping animation of [period], shifted by [delay] (CSS
/// animation-delay). Paused while [running] is false; still at [stillValue]
/// with reduced motion or before it first runs.
class QuizLoop extends StatefulWidget {
  const QuizLoop({
    super.key,
    required this.period,
    required this.builder,
    this.delay = Duration.zero,
    this.running = true,
    this.stillValue = 0,
    this.isolate = false,
    this.child,
  });

  final Duration period;
  final Duration delay;
  final bool running;

  /// Repaints in its own layer: for a lone, continuously animating widget,
  /// so the rest of the screen is not repainted every frame.
  final bool isolate;
  final double stillValue;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<QuizLoop> createState() => _QuizLoopState();
}

class _QuizLoopState extends State<QuizLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = BirdyMotion.reduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(QuizLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!_reduced && widget.running) {
      if (!_controller.isAnimating) _controller.repeat();
      _started = true;
    } else {
      _controller.stop();
    }
  }

  double get _phase {
    final shift = widget.delay.inMicroseconds / widget.period.inMicroseconds;
    return ((_controller.value - shift) % 1 + 1) % 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced || !_started) {
      return widget.builder(context, widget.stillValue, widget.child);
    }
    final animated = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => widget.builder(context, _phase, child),
      child: widget.child,
    );
    return widget.isolate ? RepaintBoundary(child: animated) : animated;
  }
}

/// A one-shot animation of [duration] after [delay], from its first build
/// (CSS animation-fill-mode: both). [builder] gets 0 to 1, linear; with
/// reduced motion it gets 1 straight away.
class QuizOnce extends StatefulWidget {
  const QuizOnce({
    super.key,
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
    this.child,
  });

  final Duration duration;
  final Duration delay;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<QuizOnce> createState() => _QuizOnceState();
}

class _QuizOnceState extends State<QuizOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = BirdyMotion.reduced(context);
    if (_reduced) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  double get _t {
    if (widget.duration == Duration.zero) return _controller.value < 1 ? 0 : 1;
    final total = widget.delay + widget.duration;
    final elapsed = _controller.value * total.inMicroseconds;
    return ((elapsed - widget.delay.inMicroseconds) /
            widget.duration.inMicroseconds)
        .clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return widget.builder(context, 1, widget.child);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => widget.builder(context, _t, child),
      child: widget.child,
    );
  }
}

/// qz-pop: fades in from [from] to 1.08, then settles at 1.
class QuizPop extends StatelessWidget {
  const QuizPop({
    super.key,
    required this.child,
    this.duration = QuizMotion.cardPop,
    this.delay = Duration.zero,
    this.from = 0.6,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double from;

  @override
  Widget build(BuildContext context) => QuizOnce(
    duration: duration,
    delay: delay,
    child: child,
    builder: (context, t, child) {
      const stops = [0.0, 0.6, 1.0];
      final opacity = quizKeyframes(t, stops, const [0, 1, 1], QuizMotion.ease);
      final scale = quizKeyframes(t, stops, [from, 1.08, 1], QuizMotion.ease);
      return Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
}

/// qz-rise: fades in while moving up [distance].
class QuizRise extends StatelessWidget {
  const QuizRise({
    super.key,
    required this.child,
    this.duration = QuizMotion.rise,
    this.delay = Duration.zero,
    this.distance = 12,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double distance;

  @override
  Widget build(BuildContext context) => QuizOnce(
    duration: duration,
    delay: delay,
    child: child,
    builder: (context, t, child) {
      final e = QuizMotion.ease.transform(t);
      return Opacity(
        opacity: e.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, distance * (1 - e)),
          child: child,
        ),
      );
    },
  );
}

/// qz-fade.
class QuizFade extends StatelessWidget {
  const QuizFade({
    super.key,
    required this.child,
    this.duration = QuizMotion.fade,
    this.curve = QuizMotion.ease,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) => QuizOnce(
    duration: duration,
    child: child,
    builder:
        (context, t, child) =>
            Opacity(opacity: curve.transform(t).clamp(0.0, 1.0), child: child),
  );
}

/// qz-wobble: a small horizontal sway, for a wrong pick.
class QuizWobble extends StatelessWidget {
  const QuizWobble({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => QuizOnce(
    duration: QuizMotion.wobble,
    child: child,
    builder:
        (context, t, child) => Transform.translate(
          offset: Offset(
            quizKeyframes(
              t,
              const [0, 0.2, 0.4, 0.6, 0.8, 1],
              const [0, -6, 5, -3, 2, 0],
              QuizMotion.out,
            ),
            0,
          ),
          child: child,
        ),
  );
}

/// qz-up: « +1 Oreille fine » rising and fading away.
class QuizFlyUp extends StatelessWidget {
  const QuizFlyUp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (BirdyMotion.reduced(context)) return child;
    return QuizOnce(
      duration: QuizMotion.flyUp,
      delay: QuizMotion.flyUpDelay,
      child: child,
      builder: (context, t, child) {
        const stops = [0.0, 0.2, 1.0];
        final opacity = quizKeyframes(t, stops, const [
          0,
          1,
          0,
        ], QuizMotion.ease);
        final dy = quizKeyframes(t, stops, const [
          0,
          -12,
          -56,
        ], QuizMotion.ease);
        final scale = quizKeyframes(t, stops, const [
          0.8,
          1,
          1,
        ], QuizMotion.ease);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

/// qz-float: bobs up and down [amplitude], forever.
class QuizFloat extends StatelessWidget {
  const QuizFloat({
    super.key,
    required this.child,
    this.period = QuizMotion.float,
    this.delay = Duration.zero,
    this.amplitude = 6,
  });

  final Widget child;
  final Duration period;
  final Duration delay;
  final double amplitude;

  @override
  Widget build(BuildContext context) => QuizLoop(
    isolate: true,
    period: period,
    delay: delay,
    child: child,
    builder:
        (context, t, child) => Transform.translate(
          offset: Offset(
            0,
            -amplitude *
                quizKeyframes(
                  t,
                  const [0, 0.5, 1],
                  const [0, 1, 0],
                  QuizMotion.inOut,
                ),
          ),
          child: child,
        ),
  );
}

/// qz-wiggle: a small forever tilt, side to side (a speech bubble).
class QuizWiggle extends StatelessWidget {
  const QuizWiggle({super.key, required this.child, this.angle = 3});

  final Widget child;

  /// Degrees each way.
  final double angle;

  @override
  Widget build(BuildContext context) => QuizLoop(
    isolate: true,
    period: QuizMotion.wiggle,
    child: child,
    builder: (context, t, child) {
      final deg = quizKeyframes(
        t,
        const [0, 0.5, 1],
        [-angle, angle, -angle],
        QuizMotion.inOut,
      );
      return Transform.rotate(angle: deg * math.pi / 180, child: child);
    },
  );
}

/// qz-ring: a stroked circle spreading from the child's size to 1.7× while
/// fading out, forever; only while [running] (the clip plays).
class QuizRing extends StatelessWidget {
  const QuizRing({
    super.key,
    required this.color,
    this.delay = Duration.zero,
    this.running = true,
  });

  final Color color;
  final Duration delay;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (!running) return const SizedBox.shrink();
    return IgnorePointer(
      child: QuizLoop(
        isolate: true,
        period: QuizMotion.ring,
        delay: delay,
        builder: (context, t, child) {
          final scale = quizKeyframes(
            t,
            const [0, 1],
            const [1, 1.7],
            Curves.linear,
          );
          final opacity = quizKeyframes(
            t,
            const [0, 1],
            const [.7, 0],
            Curves.linear,
          );
          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: opacity),
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// qz-bar: one equalizer bar, scaleY 0.35 ↔ 1 from its middle.
class QuizBar extends StatelessWidget {
  const QuizBar({
    super.key,
    required this.width,
    required this.height,
    required this.color,
    this.period = QuizMotion.bar,
    this.delay = Duration.zero,
    this.running = true,
  });

  final double width;
  final double height;
  final Color color;
  final Duration period;
  final Duration delay;
  final bool running;

  @override
  Widget build(BuildContext context) => QuizLoop(
    period: period,
    delay: delay,
    running: running,
    // Still: full height, like a paused CSS animation that never ran.
    stillValue: 0.5,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
    builder:
        (context, t, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            1,
            quizKeyframes(
              t,
              const [0, 0.5, 1],
              const [0.35, 1, 0.35],
              QuizMotion.inOut,
            ),
            1,
          ),
          child: child,
        ),
  );
}

/// A row of equalizer bars: [heights] and [colors], shifted by [delays].
class QuizBars extends StatelessWidget {
  const QuizBars({
    super.key,
    required this.heights,
    required this.colors,
    required this.delays,
    this.width = 5,
    this.gap = 4,
    this.period = QuizMotion.bar,
    this.running = true,
    this.dimmed = false,
  });

  final List<double> heights;
  final List<Color> colors;
  final List<Duration> delays;
  final double width;
  final double gap;
  final Duration period;
  final bool running;

  /// At rest: 45 % opacity.
  final bool dimmed;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ExcludeSemantics(
    child: Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: SizedBox(
        height: 28,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < heights.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              QuizBar(
                width: width,
                height: heights[i],
                color: colors[i],
                period: period,
                delay: delays[i],
                running: running,
              ),
            ],
          ],
        ),
      ),
    ),
    ),
  );
}

/// qz-pulse: a Martin-pêcheur ring spreading 9 px and fading, forever.
class QuizPulse extends StatelessWidget {
  const QuizPulse({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (BirdyMotion.reduced(context)) return child;
    return QuizLoop(
      isolate: true,
      period: QuizMotion.pulse,
      child: child,
      builder: (context, t, child) {
        final e = QuizMotion.out.transform(t);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: BirdyColors.of(
                  context,
                ).accent.withValues(alpha: 0.45 * (1 - e)),
                spreadRadius: 9 * e,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// Slowly turning rays behind a found bird (repeating conic gradient:
/// [color] 10°, clear 20°, radially faded out from 20 % to 62 % of the
/// radius), one turn in 24 s.
class QuizRays extends StatelessWidget {
  const QuizRays({super.key, required this.color, this.size = 520});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: QuizLoop(
    isolate: true,
      period: QuizMotion.spin,
      child: CustomPaint(size: Size.square(size), painter: _RaysPainter(color)),
      builder:
          (context, t, child) =>
              Transform.rotate(angle: t * 2 * math.pi, child: child),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter(this.color);

  final Color color;

  static const double _period = 30 * math.pi / 180;
  static const double _ray = 10 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.saveLayer(rect, Paint());
    final paint = Paint()..color = color;
    // CSS conic gradients start at 12 o'clock.
    for (var a = 0.0; a < 2 * math.pi - 1e-6; a += _period) {
      canvas.drawArc(rect, a - math.pi / 2, _ray, true, paint);
    }
    // The mockup's radial mask: opaque to 20 % of the radius, clear by
    // 62 %.
    final mask =
        Paint()
          ..shader = ui.Gradient.radial(center, radius, const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ], const [0, 0.2, 0.62])
          ..blendMode = BlendMode.dstIn;
    canvas.drawRect(rect, mask);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => oldDelegate.color != color;
}
