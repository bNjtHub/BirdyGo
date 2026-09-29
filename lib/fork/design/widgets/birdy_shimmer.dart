/// Shimmer of the loading skeletons: a soft diagonal light band sweeping
/// left to right over every skeleton shape of the screen, in sync.
///
/// One shared [BirdyShimmerClock] ticker drives all of them (not one
/// controller per rectangle). It starts with the first visible shimmering
/// skeleton and stops with the last one (removed, or hidden by a
/// [TickerMode]). Each shape only repaints (a [ShaderMask] over its child,
/// which is not rebuilt), and the band is placed in screen coordinates so it
/// travels continuously across neighbouring shapes. Reduced motion: no
/// ticker, the child stays a static fill.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../birdy_motion.dart';
import '../birdy_tokens.dart';

/// Shared clock of every shimmer on screen, reference counted.
class BirdyShimmerClock {
  BirdyShimmerClock._();

  static final BirdyShimmerClock instance = BirdyShimmerClock._();

  /// Sweep progress in [0, 1] while the band crosses, or null while resting.
  ValueNotifier<double?> get progress => _progress;
  final _ProgressNotifier _progress = _ProgressNotifier();

  Ticker? _ticker;
  int _users = 0;

  /// Whether the ticker is currently running.
  bool get isRunning => _ticker != null;

  /// Number of shimmering skeletons subscribed.
  int get users => _users;

  /// Full cycle: sweep, then pause.
  static Duration get period =>
      BirdyMotion.shimmerSweep + BirdyMotion.shimmerPause;

  /// Eased sweep progress at [elapsed], null during the pause.
  static double? progressAt(Duration elapsed) {
    final inCycle = elapsed.inMicroseconds % period.inMicroseconds;
    if (inCycle >= BirdyMotion.shimmerSweep.inMicroseconds) return null;
    final t = inCycle / BirdyMotion.shimmerSweep.inMicroseconds;
    return BirdyMotion.shimmerCurve.transform(t);
  }

  void acquire() {
    _users++;
    if (_ticker != null) return;
    _ticker = Ticker((elapsed) => _progress.value = progressAt(elapsed))
      ..start();
  }

  void release() {
    _users--;
    if (_users > 0) return;
    _users = 0;
    _ticker?.dispose();
    _ticker = null;
    _progress.reset();
  }
}

/// Sweep progress that can be cleared without notifying: the last skeleton
/// releases the clock while the tree is being torn down or built, where a
/// listener's setState would throw.
class _ProgressNotifier extends ValueNotifier<double?> {
  _ProgressNotifier() : super(null);

  bool _quiet = false;

  void reset() {
    _quiet = true;
    value = null;
    _quiet = false;
  }

  @override
  void notifyListeners() {
    if (!_quiet) super.notifyListeners();
  }
}

/// Paints the shimmer band over [child]'s painted pixels. Static (just
/// [child]) with reduced motion or when hidden by a [TickerMode].
class BirdyShimmer extends StatefulWidget {
  const BirdyShimmer({super.key, required this.child});

  final Widget child;

  /// Band start x (screen coordinates) for a sweep [progress] over a screen
  /// [screenWidth] wide: from fully off the left edge to fully off the right.
  @visibleForTesting
  static double bandStart(double progress, double screenWidth) {
    final band = screenWidth * BirdyMotion.shimmerBandWidth;
    return -band + progress * (screenWidth + band);
  }

  @override
  State<BirdyShimmer> createState() => _BirdyShimmerState();
}

class _BirdyShimmerState extends State<BirdyShimmer> {
  bool _subscribed = false;

  void _sync(bool active) {
    if (active == _subscribed) return;
    _subscribed = active;
    if (active) {
      BirdyShimmerClock.instance.acquire();
    } else {
      BirdyShimmerClock.instance.release();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(
      TickerMode.valuesOf(context).enabled && !BirdyMotion.reduced(context),
    );
  }

  @override
  void dispose() {
    _sync(false);
    super.dispose();
  }

  Shader? _shader(Rect bounds, double progress, Color sheen, double screenW) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final left = box.localToGlobal(Offset.zero).dx;
    final band = screenW * BirdyMotion.shimmerBandWidth;
    final angle = BirdyMotion.shimmerTiltDegrees * math.pi / 180;
    // Gradient vector along the tilted direction, its x extent being `band`.
    final dx = band;
    final dy = band * math.tan(angle);
    final from = Offset(BirdyShimmer.bandStart(progress, screenW) - left, 0);
    return ui.Gradient.linear(
      from,
      from + Offset(dx, dy),
      [sheen.withValues(alpha: 0), sheen, sheen.withValues(alpha: 0)],
      const [0, 0.5, 1],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_subscribed) return widget.child;
    final sheen = BirdyColors.of(context).skeletonSheen;
    final screenW = MediaQuery.sizeOf(context).width;
    return RepaintBoundary(
      child: ValueListenableBuilder<double?>(
        valueListenable: BirdyShimmerClock.instance.progress,
        child: widget.child,
        builder: (context, progress, child) {
          if (progress == null) return child!;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback:
                (bounds) =>
                    _shader(bounds, progress, sheen, screenW) ??
                    ui.Gradient.linear(Offset.zero, const Offset(1, 0), const [
                      Color(0x00000000),
                      Color(0x00000000),
                    ]),
            child: child,
          );
        },
      ),
    );
  }
}
