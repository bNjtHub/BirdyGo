/// Smooth reordering for a [Column] (J6c): when a child changes place, it
/// is painted at its old place first, then slides to the new one
/// (250 ms, [BirdyMotion.move]). Works with rows of any height.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../design/birdy_motion.dart';

/// Wraps one keyed child of a [Column]. Must be a direct child of the
/// column: the move is read from the column's layout, not from the screen,
/// so scrolling never triggers it.
class FlipMove extends StatefulWidget {
  const FlipMove({super.key, required this.child});

  final Widget child;

  @override
  State<FlipMove> createState() => _FlipMoveState();
}

class _FlipMoveState extends State<FlipMove>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BirdyMotion.reorder,
    value: 1,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: BirdyMotion.move,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FlipBox(
    progress: _progress,
    enabled: !BirdyMotion.reduced(context),
    onMoved: () {
      if (mounted) _controller.forward(from: 0);
    },
    child: widget.child,
  );
}

class _FlipBox extends SingleChildRenderObjectWidget {
  const _FlipBox({
    required this.progress,
    required this.enabled,
    required this.onMoved,
    required super.child,
  });

  final Animation<double> progress;
  final bool enabled;
  final VoidCallback onMoved;

  @override
  RenderFlipMove createRenderObject(BuildContext context) =>
      RenderFlipMove(progress: progress, enabled: enabled, onMoved: onMoved);

  @override
  void updateRenderObject(BuildContext context, RenderFlipMove renderObject) {
    renderObject
      ..progress = progress
      ..enabled = enabled
      ..onMoved = onMoved;
  }
}

/// Paints its child shifted from where it was in the previous layout,
/// easing the shift to zero with [progress] (0 → 1).
class RenderFlipMove extends RenderProxyBox {
  RenderFlipMove({
    required Animation<double> progress,
    required this.enabled,
    required this.onMoved,
  }) : _progress = progress;

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (identical(value, _progress)) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
  }

  bool enabled;
  VoidCallback onMoved;

  double? _lastY;
  double _from = 0;

  /// Set while the move waits for its animation to start (next frame).
  bool _pending = false;

  /// Current vertical shift, in logical pixels.
  double get shift => _pending ? _from : _from * (1 - _progress.value);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final data = parentData;
    final y = data is BoxParentData ? data.offset.dy : 0.0;
    final last = _lastY;
    if (last != null && last != y && enabled) {
      // Continue from where the child is drawn, even mid-move.
      _from = last + shift - y;
      if (!_pending) {
        _pending = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _pending = false;
          onMoved();
        });
      }
    }
    _lastY = y;
    final dy = shift;
    if (dy == 0) {
      super.paint(context, offset);
    } else if (child != null) {
      context.paintChild(child!, offset + Offset(0, dy));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final dy = shift;
    if (dy == 0) return super.hitTestChildren(result, position: position);
    return result.addWithPaintOffset(
      offset: Offset(0, dy),
      position: position,
      hitTest:
          (result, transformed) =>
              super.hitTestChildren(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, shift, 0, 1);
  }
}
