/// Shared confetti of BirdyGo (J6e quiz, J6f moments, fork/DESIGN.md
/// « Animations »): a [BirdyConfetti.burst] from a point (a quiz card, a
/// bird, an emblem) or a [BirdyConfetti.rain] from the top. One emission,
/// never looping, and nothing at all with reduced motion.
///
/// Place it with no size where the particles start: they are painted from
/// its top-left corner and are not clipped by it, only by a clipping
/// ancestor.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/widgets.dart';

import '../birdy_motion.dart';
import '../birdy_tokens.dart';

class BirdyConfetti extends StatefulWidget {
  /// A burst from this point, in [colors] (the bird's own colors plus
  /// [BirdyConfettiColors.burst], usually). [settings] set its count, force,
  /// gravity and life; the default is the quiz's burst.
  const BirdyConfetti.burst({
    super.key,
    this.controller,
    this.colors = BirdyConfettiColors.burst,
    this.delay = Duration.zero,
    this.settings = BirdyConfettiBurst.standard,
  }) : rain = false;

  /// Rain from this point, falling slowly. A full rain puts one at each of
  /// [BirdyConfettiMotion.rainSpots].
  const BirdyConfetti.rain({
    super.key,
    this.controller,
    this.colors = BirdyConfettiColors.rain,
    this.delay = Duration.zero,
  }) : settings = BirdyConfettiBurst.standard,
       rain = true;

  /// Played by the caller when given, and the particles fade from the
  /// first build. When null, the widget plays its own once, [delay] after
  /// its first build.
  final ConfettiController? controller;
  final List<Color> colors;
  final Duration delay;

  /// Physics of a burst (ignored by a rain).
  final BirdyConfettiBurst settings;
  final bool rain;

  @override
  State<BirdyConfetti> createState() => _BirdyConfettiState();
}

class _BirdyConfettiState extends State<BirdyConfetti>
    with SingleTickerProviderStateMixin {
  static final math.Random _random = math.Random();

  ConfettiController? _own;
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: widget.rain ? BirdyConfettiMotion.rainLife : widget.settings.life,
  );
  Timer? _timer;
  bool _reduced = false;
  bool _started = false;

  ConfettiController get _controller => widget.controller ?? _own!;

  /// Faded out: the particles leave the tree, and their ticker with them.
  bool get _done => _life.isCompleted;

  @override
  void initState() {
    super.initState();
    _life.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
    if (widget.controller == null) {
      _own = ConfettiController(duration: BirdyConfettiMotion.emission);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = BirdyMotion.reduced(context);
    if (_reduced || _started) return;
    _started = true;
    if (_own == null) {
      _life.forward();
    } else if (widget.delay == Duration.zero) {
      // The particles listen to the controller once built.
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    } else {
      _timer = Timer(widget.delay, _play);
    }
  }

  void _play() {
    if (!mounted || _reduced) return;
    _life.forward();
    _own?.play();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _life.dispose();
    _own?.dispose();
    super.dispose();
  }

  /// Mostly rectangles, some dots (quiz-fx.js).
  static Path _shape(Size size) {
    if (_random.nextDouble() < BirdyConfettiMotion.dotShare) {
      final r = size.height / 1.6;
      return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    }
    return Path()..addRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width,
        height: size.height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced || _done) return const SizedBox.shrink();
    final life = _life.duration!;
    final fadeFrom =
        1 - BirdyConfettiMotion.fade.inMicroseconds / life.inMicroseconds;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _life,
          builder: (context, child) {
            final t = _life.value;
            final opacity =
                t <= fadeFrom ? 1.0 : (1 - (t - fadeFrom) / (1 - fadeFrom));
            return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
          },
          child: _particles(),
        ),
      ),
    );
  }

  Widget _particles() {
    final rain = widget.rain;
    return ConfettiWidget(
      confettiController: _controller,
      blastDirectionality: BlastDirectionality.explosive,
      emissionFrequency: 0,
      numberOfParticles:
          rain
              ? BirdyConfettiMotion.rainParticles ~/
                  BirdyConfettiMotion.rainSpots.length
              : widget.settings.particles,
      minBlastForce:
          rain ? BirdyConfettiMotion.rainMinForce : widget.settings.minForce,
      maxBlastForce:
          rain ? BirdyConfettiMotion.rainMaxForce : widget.settings.maxForce,
      gravity: rain ? BirdyConfettiMotion.rainGravity : widget.settings.gravity,
      particleDrag: BirdyConfettiMotion.drag,
      minimumSize: BirdyConfettiMotion.minSize,
      maximumSize: BirdyConfettiMotion.maxSize,
      colors: widget.colors,
      shouldLoop: false,
      pauseEmissionOnLowFrameRate: false,
      createParticlePath: _shape,
    );
  }
}
