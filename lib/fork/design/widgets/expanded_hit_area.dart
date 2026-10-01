/// Touch target larger than the widget it wraps, without changing the layout.
///
/// Hit tests stop at the bounds of every ancestor, so a target that grows
/// past its parent must be routed from a wider box: [ExpandedHitRegion] wraps
/// the whole row, and finds the [ExpandedHitArea] markers below it.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks [child] as a small control that deserves a target of at least
/// [minSize] around its center. Lays out exactly like [child]; the
/// [ExpandedHitRegion] above does the routing.
class ExpandedHitArea extends SingleChildRenderObjectWidget {
  const ExpandedHitArea({super.key, required this.minSize, super.child});

  /// Minimum width and height of the touch target.
  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderExpandedHitArea(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderExpandedHitArea renderObject,
  ) => renderObject.minSize = minSize;
}

class RenderExpandedHitArea extends RenderProxyBox {
  RenderExpandedHitArea(this.minSize);

  double minSize;
}

/// Sends the touches that land in the expanded target of an
/// [ExpandedHitArea] below it to that control, before anything else below
/// gets them (the row's own tap).
class ExpandedHitRegion extends SingleChildRenderObjectWidget {
  const ExpandedHitRegion({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderExpandedHitRegion();
}

class RenderExpandedHitRegion extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      final marker = _findMarker(this);
      if (marker != null && marker.attached && marker.hasSize) {
        final box = MatrixUtils.transformRect(
          marker.getTransformTo(this),
          Offset.zero & marker.size,
        );
        final w = box.width < marker.minSize ? marker.minSize : box.width;
        final h = box.height < marker.minSize ? marker.minSize : box.height;
        final target = Rect.fromCenter(center: box.center, width: w, height: h);
        if (target.contains(position) && !box.contains(position)) {
          // Aim the touch at the nearest point of the control itself.
          final inside = Offset(
            position.dx.clamp(box.left, box.right - 0.01),
            position.dy.clamp(box.top, box.bottom - 0.01),
          );
          final routed = result.addWithRawTransform(
            transform: Matrix4.translationValues(
              inside.dx - position.dx,
              inside.dy - position.dy,
              0,
            ),
            position: position,
            hitTest: (result, p) => super.hitTest(result, position: p),
          );
          if (routed) return true;
        }
      }
    }
    return super.hitTest(result, position: position);
  }

  static RenderExpandedHitArea? _findMarker(RenderObject root) {
    RenderExpandedHitArea? found;
    void visit(RenderObject node) {
      if (found != null) return;
      if (node is RenderExpandedHitArea) {
        found = node;
        return;
      }
      node.visitChildren(visit);
    }

    root.visitChildren(visit);
    return found;
  }
}
