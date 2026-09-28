/// Tests for the species page's drag-down-to-close gesture (J6f-b fix).
library;

import 'package:birdnet_live/fork/species_page/species_page_drag_close.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ScrollController scrollController,
  required VoidCallback onClose,
  bool reducedMotion = false,
  double itemsHeight = 2000,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
      home: Scaffold(
        body: SpeciesPageDragClose(
          scrollController: scrollController,
          onClose: onClose,
          child: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: itemsHeight,
              child: const Align(
                alignment: Alignment.topCenter,
                child: Text('content'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('drag down 40% of the screen pops the page', (tester) async {
    var closed = false;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      scrollController: controller,
      onClose: () => closed = true,
    );

    final start = tester.getCenter(find.text('content'));
    final gesture = await tester.startGesture(start);
    // 844 * 0.4 = 337.6: comfortably past the threshold.
    await gesture.moveBy(const Offset(0, 400));
    await tester.pump();
    expect(closed, isFalse); // still following the finger, not closed yet.
    await gesture.up();
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('a small drag springs back instead of closing', (tester) async {
    var closed = false;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      scrollController: controller,
      onClose: () => closed = true,
    );

    final start = tester.getCenter(find.text('content'));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    // Back where it started.
    expect(tester.getCenter(find.text('content')).dy, closeTo(start.dy, 0.5));
  });

  testWidgets(
    'dragging while scrolled down scrolls instead of closing',
    (tester) async {
      var closed = false;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        scrollController: controller,
        onClose: () => closed = true,
      );

      controller.jumpTo(200);
      await tester.pump();
      expect(controller.offset, 200);

      final start = tester.getCenter(find.byType(SingleChildScrollView));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 400));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // The drag-to-close never engaged: the scroll view moved instead.
      expect(closed, isFalse);
      expect(controller.offset, lessThan(200));
    },
  );

  testWidgets(
    'reduced motion: still follows the finger, closes without an '
    'animated fly-off',
    (tester) async {
      var closed = false;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        scrollController: controller,
        onClose: () => closed = true,
        reducedMotion: true,
      );

      final start = tester.getCenter(find.text('content'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      // Follows the finger even with reduced motion.
      expect(
        tester.getCenter(find.text('content')).dy,
        closeTo(start.dy + 100, 0.5),
      );

      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      await gesture.up();
      // No animation to settle: closes on the very next pump.
      await tester.pump();

      expect(closed, isTrue);
    },
  );
}
