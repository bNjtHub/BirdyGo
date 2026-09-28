/// Shared bottom sheet helper (fork/PLAN.md J6f-b bugfix): on Android
/// edge-to-edge, `showModalBottomSheet(useSafeArea: true)` only avoids the
/// top/left/right system intrusions, never the bottom one — a sheet's own
/// content still needs to clear the bottom nav bar (3-button or gesture)
/// itself, or its last texts and buttons end up under it. This helper does
/// that once for every fork sheet instead of each screen redoing it (or
/// forgetting to).
library;

import 'package:flutter/material.dart';

/// Opens a modal bottom sheet like [showModalBottomSheet], always with
/// `useSafeArea: true`, and makes sure the content [builder] returns clears
/// the bottom system inset that `useSafeArea` does not add on its own.
///
/// For a sheet whose body sizes itself to its content (a `Column` with
/// `mainAxisSize: MainAxisSize.min`, a `SingleChildScrollView` that simply
/// grows with what it holds…), leave [addBottomInset] at its default: the
/// helper wraps the content in bottom padding equal to
/// [birdySheetBottomInset].
///
/// For a sheet whose body is a scrolling viewport sized to fill the
/// available height (`DraggableScrollableSheet`, a `ListView`/
/// `SingleChildScrollView` inside an `Expanded`…), pass
/// `addBottomInset: false` — wrapping it in outer padding would shrink that
/// viewport instead of just clearing the nav bar — and add
/// [birdySheetBottomInset] as trailing padding *inside* the scroll view.
/// That way the extra space only appears once scrolled to the end, rather
/// than being reserved (and visible) at all times.
Future<T?> showBirdySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle = true,
  bool useRootNavigator = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  bool isDismissible = true,
  bool enableDrag = true,
  bool addBottomInset = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: backgroundColor,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (sheetContext) {
      final content = builder(sheetContext);
      if (!addBottomInset) return content;
      final inset = birdySheetBottomInset(sheetContext);
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: content,
      );
    },
  );
}

/// The bottom system inset (nav bar) a fork sheet must clear. Used directly
/// by [showBirdySheet]'s default wrap, and by sheets that opt out of it
/// (`addBottomInset: false`) to add the same value as their own trailing
/// scroll padding instead.
double birdySheetBottomInset(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom;
