/// Drag-down-to-close for the species page (J6f-b fix): a vertical drag
/// down from the top area (the photo header), or anywhere once the content
/// is scrolled back to the top, follows the finger and pops the page past a
/// threshold or a fling; otherwise it springs back.
///
/// Tracked with a raw [Listener] rather than a competing gesture recognizer,
/// so it never fights the inner scroll view (a `Scrollable`'s own drag
/// recognizer would usually win the arena over an ancestor's) nor the
/// horizontal gestures inside the page (bar-chart taps, the sheet chips and
/// links carousels): those keep receiving every pointer event exactly as
/// before, and this widget only ever translates the page when the drag is
/// clearly vertical, downward and the content is at the top.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../design/birdy_motion.dart';

/// Fraction of the screen's height that pops the page on release.
const double _closeFraction = 0.4;

/// Downward fling speed (px/s) that pops the page regardless of distance.
const double _flingVelocity = 800;

/// Minimum travel before a gesture is read as vertical vs. horizontal.
const double _slop = 8;

class SpeciesPageDragClose extends StatefulWidget {
  const SpeciesPageDragClose({
    super.key,
    required this.child,
    required this.scrollController,
    required this.onClose,
  });

  final Widget child;

  /// Only read to tell whether the content is scrolled to the top; never
  /// attached to a scroll view by this widget.
  final ScrollController scrollController;

  /// Called once the page has finished animating off-screen (or at once
  /// with reduced motion).
  final VoidCallback onClose;

  @override
  State<SpeciesPageDragClose> createState() => _SpeciesPageDragCloseState();
}

class _SpeciesPageDragCloseState extends State<SpeciesPageDragClose>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() => _offset = _motion.value));

  double _offset = 0;
  int? _pointer;
  Offset? _start;

  /// Null while undecided, then fixed for the rest of the gesture.
  bool? _tracking;
  VelocityTracker? _velocity;

  bool get _atTop =>
      !widget.scrollController.hasClients ||
      widget.scrollController.position.pixels <= 0.5;

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _start = event.position;
    _tracking = null;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _motion.stop();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    final start = _start;
    if (start == null) return;
    final delta = event.position - start;
    if (_tracking == null) {
      if (delta.distance < _slop) return;
      // Decided once, from the gesture's very first clear movement: a
      // downward drag while the content is at the top (J6f-b fix).
      _tracking = delta.dy > 0 && delta.dy.abs() > delta.dx.abs() && _atTop;
    }
    if (_tracking != true) return;
    setState(() => _offset = delta.dy < 0 ? 0 : delta.dy);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    final tracking = _tracking == true;
    final velocity = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
    _pointer = null;
    _start = null;
    _tracking = null;
    _velocity = null;
    if (!tracking) return;
    final height = MediaQuery.sizeOf(context).height;
    final shouldClose =
        _offset > height * _closeFraction || velocity > _flingVelocity;
    if (shouldClose) {
      _close(height, velocity);
    } else {
      _springBack(velocity);
    }
  }

  Future<void> _close(double height, double velocity) async {
    if (BirdyMotion.reduced(context)) {
      widget.onClose();
      return;
    }
    _motion.value = _offset;
    await _motion.animateTo(
      height,
      duration: BirdyMotion.exit,
      curve: BirdyMotion.standard,
    );
    widget.onClose();
  }

  void _springBack(double velocity) {
    if (BirdyMotion.reduced(context)) {
      setState(() => _offset = 0);
      return;
    }
    _motion.value = _offset;
    _motion.animateWith(
      SpringSimulation(BirdyMotion.sheetSpring, _offset, 0, velocity),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: Transform.translate(
        offset: Offset(0, _offset),
        child: widget.child,
      ),
    );
  }
}
