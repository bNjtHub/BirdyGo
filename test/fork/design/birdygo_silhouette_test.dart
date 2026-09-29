import 'dart:ui' as ui;

import 'package:birdnet_live/fork/design/birdygo_silhouette.dart';
import 'package:birdnet_live/fork/home/birdygo_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grey = Color(0xFF6B7280);

  void paint(BirdyGoSilhouettePainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size.square(96));
    recorder.endRecording().dispose();
  }

  test('paints with the wing, without it, and at every eye state', () {
    for (final wing in [true, false]) {
      for (final closed in [0.0, 0.3, 1.0]) {
        paint(BirdyGoSilhouettePainter(grey, wing: wing, eyeClosed: closed));
      }
    }
    paint(BirdyGoSilhouettePainter(grey, muted: true));
  });

  test('the wing keeps the logo bar colors by default', () {
    expect(BirdyGoSilhouettePainter(grey).barColors, [
      for (final (_, _, color) in BirdyGoLogoPainter.bars) color,
    ]);
    expect(BirdyGoLogoPainter.bars, hasLength(4));
  });

  test('a muted bird gets bars lighter than its body', () {
    final colors = BirdyGoSilhouettePainter(grey, muted: true).barColors;
    expect(colors, hasLength(4));
    for (final c in colors) {
      expect(c.computeLuminance(), greaterThan(grey.computeLuminance()));
      expect(c, isNot(BirdyGoLogoPainter.bars.first.$3));
    }
  });

  testWidgets('the icon draws at its size, wing on by default', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            BirdyGoSilhouetteIcon(size: 40, color: grey),
            BirdyGoSilhouetteIcon(size: 15, color: grey, muted: true),
            BirdyGoSilhouetteIcon(size: 40, color: grey, eyeClosed: 1),
          ],
        ),
      ),
    );
    final first = find.byType(BirdyGoSilhouetteIcon).first;
    expect(tester.getSize(first), const Size.square(40));
    expect(tester.widget<BirdyGoSilhouetteIcon>(first).wing, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('the closed eye is a curved line as wide as the open eye', () {
    final open = BirdyGoLogoPainter.eyePath(0).getBounds();
    final closed = BirdyGoLogoPainter.eyePath(1).getBounds();
    expect(closed.width, closeTo(open.width, 0.01));
    expect(closed.height, lessThan(open.height / 2));
  });
}
