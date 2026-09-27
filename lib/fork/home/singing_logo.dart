/// The home logo (J6c): the singing bird of the startup screen, reused
/// through [BirdyGoSingingPainter].
///
/// The bird sings one phrase when the home appears, then stays still, and
/// sings one phrase again every [SingingLogo.singEvery] while the home is
/// visible. Never an endless loop: the ticker only runs during a phrase, and
/// nothing is scheduled while the home is hidden (another tab, a screen
/// above it, the app in the background). Reduced motion: the settled mark,
/// never animated. A tap on the mark or the name makes it sing once.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../splash/birdygo_splash_painter.dart';

class SingingLogo extends StatefulWidget {
  const SingingLogo({
    super.key,
    this.wordmark,
    this.width = markWidth,
    this.interval = singEvery,
  });

  /// Name shown after the mark, part of the tap area.
  final Widget? wordmark;

  /// Width of the bird (Main.dc.html: 40 × 32).
  final double width;

  /// Time between two phrases while the home stays visible.
  final Duration interval;

  static const double markWidth = 40;

  /// One phrase every 2 minutes: alive, never busy.
  static const Duration singEvery = Duration(minutes: 2);

  /// The static mark's box in the board's coordinates (the brand SVG view
  /// box 30 72 460 372); the board ([BirdyGoSingingPainter.viewBox]) starts
  /// at -80, 10 and leaves room for the notes on the left and on top.
  static const Rect _mark = Rect.fromLTWH(30, 72, 460, 372);
  static const Offset _boardOrigin = Offset(-80, 10);

  @override
  State<SingingLogo> createState() => _SingingLogoState();
}

class _SingingLogoState extends State<SingingLogo>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Clock of the settled mark: the first phrase and its notes are over.
  static const double _settled =
      BirdyGoSingingPainter.firstPhrase + BirdyGoSingingPainter.phraseLength;

  /// Start of a later phrase: the loop's second one, so the entrance (fade,
  /// lift, wing bars) is not replayed.
  static const double _again =
      BirdyGoSingingPainter.firstPhrase + BirdyGoSingingPainter.phrasePeriod;

  late final AnimationController _controller =
      AnimationController(vsync: this)
        ..addListener(_tick)
        ..addStatusListener(_status);
  final ValueNotifier<double> _clock = ValueNotifier(0);
  double _from = 0;
  double _to = 0;
  Timer? _next;

  bool _arrived = false;
  bool _visible = false;
  bool _reduced = false;
  bool _resumed = true;

  bool get _canSing => _visible && _resumed && !_reduced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = BirdyMotion.reduced(context);
    // Visibility.of follows the bottom navigation (IndexedStack); a screen
    // pushed above the home makes its route not current.
    _visible =
        Visibility.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _update();
  }

  void _update() {
    if (!_canSing) {
      _next?.cancel();
      _next = null;
      // Hidden mid-phrase, or reduced motion: show the settled mark.
      if (_controller.isAnimating) _controller.stop();
      if (_reduced || _arrived) _settle();
      return;
    }
    if (!_arrived) {
      _arrived = true;
      _play(0, _settled);
    } else if (!_controller.isAnimating && _next == null) {
      _schedule();
    }
  }

  void _settle() {
    _arrived = true;
    _clock.value = _settled;
  }

  void _schedule() {
    _next?.cancel();
    _next = Timer(widget.interval, () {
      _next = null;
      if (_canSing) _sing();
    });
  }

  void _sing() => _play(_again, _again + BirdyGoSingingPainter.phraseLength);

  void _play(double from, double to) {
    _next?.cancel();
    _next = null;
    _from = from;
    _to = to;
    _controller.duration = Duration(milliseconds: (to - from).round());
    _controller.forward(from: 0);
  }

  void _tick() => _clock.value = _from + (_to - _from) * _controller.value;

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed && _canSing) _schedule();
  }

  void _onTap() {
    if (_canSing && !_controller.isAnimating) _sing();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _next?.cancel();
    _controller.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.width / SingingLogo._mark.width;
    final board = BirdyGoSingingPainter.viewBox * scale;
    final shift =
        (SingingLogo._mark.topLeft - SingingLogo._boardOrigin) * scale;
    final mark = SizedBox(
      width: widget.width,
      height: SingingLogo._mark.height * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -shift.dx,
            top: -shift.dy,
            width: board.width,
            height: board.height,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: BirdyGoSingingPainter(clock: _clock, still: _reduced),
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // A small pleasure, not a control: nothing to announce.
      excludeFromSemantics: true,
      onTap: _onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BirdySizes.target),
        child: Row(
          children: [
            ExcludeSemantics(child: mark),
            if (widget.wordmark case final wordmark?) ...[
              const SizedBox(width: BirdySpace.s),
              Flexible(child: wordmark),
            ],
          ],
        ),
      ),
    );
  }
}
