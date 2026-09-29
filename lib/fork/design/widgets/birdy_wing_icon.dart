/// The logo's wing as an icon (J6h): the four bars of
/// [BirdyGoLogoPainter.bars] in the bird theme's colors, round caps, a soft shadow,
/// no outline. Used on « Écouter », « Commencer à écouter » and the quiz's
/// question mark.
///
/// With [BirdyWingIcon.animated], every few seconds the bars do a short
/// smooth wave (`BirdyMotion.wingWave`) and come back exactly to rest. One
/// controller runs only during the wave (a cancellable timer covers the rest
/// gap, so nothing ticks in between), the painter repaints alone, and it is
/// all off with reduced motion or under a muted [TickerMode].
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../home/birdygo_logo.dart';
import '../birdy_motion.dart';
import '../birdy_theme_choice.dart';
import '../birdy_tokens.dart';

class BirdyWingIcon extends StatefulWidget {
  const BirdyWingIcon({super.key, this.size = 28, this.animated = false});

  /// Side of the square box the wing fills.
  final double size;

  /// Whether the bars wave from time to time.
  final bool animated;

  /// Length factor of bar [index] at wave progress [t] (0 → 1): 1 at rest,
  /// swelling by `BirdyMotion.wingWaveAmplitude` mid-way, bars staggered.
  @visibleForTesting
  static double barScale(int index, double t) {
    const stagger = BirdyMotion.wingWaveStagger;
    final span = 1 - stagger * (BirdyGoLogoPainter.bars.length - 1);
    final local = ((t - stagger * index) / span).clamp(0.0, 1.0);
    return 1 +
        BirdyMotion.wingWaveAmplitude *
            math.sin(math.pi * BirdyMotion.wingWaveCurve.transform(local));
  }

  @override
  State<BirdyWingIcon> createState() => _BirdyWingIconState();
}

class _BirdyWingIconState extends State<BirdyWingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: BirdyMotion.wingWave,
  );
  final math.Random _random = math.Random();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _wave.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _wave.value = 0;
        _schedule();
      }
    });
  }

  void _schedule() {
    _timer?.cancel();
    final jitter = BirdyMotion.wingWaveJitter.inMilliseconds;
    final gap =
        BirdyMotion.wingWaveInterval +
        Duration(milliseconds: _random.nextInt(2 * jitter + 1) - jitter);
    _timer = Timer(gap, () {
      _timer = null;
      if (mounted) _wave.forward(from: 0);
    });
  }

  void _sync() {
    final on =
        widget.animated &&
        TickerMode.valuesOf(context).enabled &&
        !BirdyMotion.reduced(context);
    if (on) {
      if (_timer == null && !_wave.isAnimating) _schedule();
    } else {
      _timer?.cancel();
      _timer = null;
      _wave.stop();
      _wave.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BirdyWingIcon old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _WingPainter(_wave, BirdyBrandColors.of(context)),
      ),
    ),
  );
}

class _WingPainter extends CustomPainter {
  _WingPainter(this.wave, this.brand) : super(repaint: wave);

  /// Bars 2 and 4 follow the bird theme (J6i).
  final BirdyBrandColors brand;

  /// Wave progress; 0 (rest) draws the bars exactly as the logo does.
  final Animation<double> wave;

  /// Stroke of a bar, in the logo's 512 box (same as the logo painter).
  static const double _stroke = 30;

  /// Blur sigma of the wing's soft shadow (CSS blur 2 px is sigma 1), and
  /// its vertical offset, both in logical pixels.
  static const double _shadowSigma = 1;
  static const double _shadowDy = 0.1;

  /// Bounds of the bars including their round caps, in the logo's box.
  static final Rect _bounds = () {
    Rect? rect;
    for (final (from, to, _) in BirdyGoLogoPainter.bars) {
      final bar = Rect.fromPoints(from, to);
      rect = rect == null ? bar : rect.expandToInclude(bar);
    }
    return rect!.inflate(_stroke / 2);
  }();

  /// The bar's top end once the wave stretched it from its bottom point.
  Offset _grown(Offset from, Offset to, int index) {
    final k = wave.value == 0 ? 1.0 : BirdyWingIcon.barScale(index, wave.value);
    return Offset.lerp(from, to, k)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _bounds.longestSide;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-_bounds.center.dx, -_bounds.center.dy);
    final shadow =
        Paint()
          ..color = BirdyBrand.wingShadow
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            _shadowSigma / scale,
          );
    final dy = _shadowDy / scale;
    var i = 0;
    for (final (from, to, _) in BirdyGoLogoPainter.bars) {
      canvas.drawLine(
        from.translate(0, dy),
        _grown(from, to, i++).translate(0, dy),
        shadow,
      );
    }
    i = 0;
    for (final (from, to, color) in BirdyGoLogoPainter.barsFor(brand)) {
      canvas.drawLine(
        from,
        _grown(from, to, i++),
        Paint()
          ..color = color
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WingPainter old) =>
      old.wave != wave || old.brand != brand;
}
