import 'package:birdnet_live/fork/design/widgets/birdygo_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [24.0, BirdyGoWordmark.startupSize]) {
    testWidgets('the dot sits on the baseline, 2 px after the o (size $size)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Center(child: BirdyGoWordmark(size: size))),
      );
      final scale = size / BirdyGoWordmark.startupSize;
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(BirdyGoWordmark),
          matching: find.byType(RichText),
        ),
      );
      final baselineY =
          paragraph.localToGlobal(Offset.zero).dy +
          paragraph.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final dot = find.descendant(
        of: find.byType(BirdyGoWordmark),
        matching: find.byType(DecoratedBox),
      );
      // Bottom of the dot on the baseline: no raise.
      expect(tester.getBottomLeft(dot).dy, closeTo(baselineY, 1));
      // Gap before the dot: the token, scaled.
      final pad = find.ancestor(of: dot, matching: find.byType(Padding)).first;
      expect(
        tester.getTopLeft(dot).dx - tester.getTopLeft(pad).dx,
        closeTo(BirdyGoWordmark.dotGapBefore * scale, .01),
      );
    });
  }
}
