/// The home logo (J6c): the singing bird of the startup screen, reused
/// through [BirdyGoSingingPainter].
///
/// The bird sings one phrase when the home appears, then stays still, and
/// sings one phrase again every [SingingLogo.singEvery] while the home is
/// visible. Never an endless loop: the ticker only runs during a phrase, and
/// nothing is scheduled while the home is hidden (another tab, a screen
/// above it, the app in the background). Reduced motion: the settled mark,
/// never animated. A tap on the mark or the name makes it sing once.
///
/// A double tap (J6f) sends the bird flying across the screen instead (see
/// [logo_flight.dart]): an explicit, user-triggered exception to the
/// 500 ms rule, documented in DESIGN.md's Logo section. Reduced motion: a
/// double tap just behaves like a tap.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../splash/birdygo_splash_painter.dart';
import 'logo_flight.dart';

class SingingLogo extends StatefulWidget {
  const SingingLogo({
    super.key,
    this.wordmark,
    this.width = markWidth,
    this.interval = singEvery,
    this.onTap,
  });

  /// Called on every tap, even when the mark stays still (reduced motion):
  /// the home plays the BirdyGo tweet.
  final VoidCallback? onTap;

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  /// The mark's own box, to find its screen position when a flight starts.
  final GlobalKey _markKey = GlobalKey();
  late final AnimationController _flightController = AnimationController(
    vsync: this,
    duration: BirdyMotion.logoFlight,
  );
  OverlayEntry? _flightEntry;

  /// While flying, the static mark is hidden (one bird on screen).
  bool _flying = false;

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
    // Visibility.of follows the bottom navigation (the shell's pages); a screen
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
    widget.onTap?.call();
    if (_canSing && !_controller.isAnimating) _sing();
  }

  /// A second double tap while flying is ignored; reduced motion falls
  /// back to a plain tap (sing + chirp, no flight).
  void _onDoubleTap() {
    if (_flying) return;
    if (_reduced) {
      _onTap();
      return;
    }
    _startFlight();
  }

  void _startFlight() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final markBox = _markKey.currentContext?.findRenderObject();
    final overlayBox = overlay?.context.findRenderObject();
    if (overlay == null ||
        markBox is! RenderBox ||
        !markBox.attached ||
        overlayBox is! RenderBox) {
      // No overlay or layout not ready: fall back to the plain tap.
      _onTap();
      return;
    }
    final originGlobal = markBox.localToGlobal(
      markBox.size.center(Offset.zero),
    );
    final path = LogoFlightPath(
      origin: overlayBox.globalToLocal(originGlobal),
      screen: overlayBox.size,
    );
    // The tweet plays once, at take-off (muted during a listening, like a
    // plain tap: widget.onTap already checks that).
    widget.onTap?.call();
    setState(() => _flying = true);
    _flightEntry = OverlayEntry(
      builder:
          (_) => LogoFlightBird(
            animation: _flightController,
            path: path,
            size: BirdySizes.logoFlightBird,
          ),
    );
    overlay.insert(_flightEntry!);
    _flightController.forward(from: 0).whenComplete(_endFlight);
  }

  void _endFlight() {
    _flightEntry?.remove();
    _flightEntry = null;
    if (mounted) setState(() => _flying = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _next?.cancel();
    _flightEntry?.remove();
    _flightController.dispose();
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
      key: _markKey,
      width: widget.width,
      height: SingingLogo._mark.height * scale,
      // Hidden while flying (logo_flight.dart's overlay bird is the only
      // one on screen); same box, so nothing else moves.
      child: Opacity(
        opacity: _flying ? 0 : 1,
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
                  painter: BirdyGoSingingPainter(
                    clock: _clock,
                    still: _reduced,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // A small pleasure, not a control: nothing to announce.
      excludeFromSemantics: true,
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
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
