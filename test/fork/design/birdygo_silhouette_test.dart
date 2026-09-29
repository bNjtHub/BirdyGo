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

  Widget host(List<Widget> children) => Directionality(
    textDirection: TextDirection.ltr,
    child: Column(children: children),
  );

  testWidgets('the icon draws at its size', (tester) async {
    await tester.pumpWidget(
      host(const [
        BirdyGoSilhouetteIcon.glyph(size: 40, color: grey),
        BirdyGoSilhouetteIcon.glyph(size: 15, color: grey, eyeClosed: 1),
      ]),
    );
    final first = find.byType(BirdyGoSilhouetteIcon).first;
    expect(tester.getSize(first), const Size.square(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('species: the wing from the wing size up, plain below', (
    tester,
  ) async {
    const big = BirdyGoSilhouetteIcon.species(size: 40, color: grey);
    const small = BirdyGoSilhouetteIcon.species(size: 28, color: grey);
    await tester.pumpWidget(host(const [big, small]));
    expect(big.showsWing, isTrue);
    expect(small.showsWing, isFalse);
    expect(big.showsMark || small.showsMark, isFalse);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('mystery: a « ? » from the mark size up, no wing ever', (
    tester,
  ) async {
    const big = BirdyGoSilhouetteIcon.mystery(size: 40, color: grey);
    const small = BirdyGoSilhouetteIcon.mystery(size: 16, color: grey);
    await tester.pumpWidget(host(const [big, small]));
    expect(big.showsMark, isTrue);
    expect(small.showsMark, isFalse);
    expect(big.showsWing || small.showsWing, isFalse);
    expect(find.text('?'), findsOneWidget);
    expect(tester.getSize(find.byWidget(big)), const Size.square(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('glyph: no wing, no « ? » at any size', (tester) async {
    const big = BirdyGoSilhouetteIcon.glyph(size: 96, color: grey);
    await tester.pumpWidget(host(const [big]));
    expect(big.showsWing, isFalse);
    expect(big.showsMark, isFalse);
    expect(find.text('?'), findsNothing);
  });

  test('the closed eye is a curved line as wide as the open eye', () {
    final open = BirdyGoLogoPainter.eyePath(0).getBounds();
    final closed = BirdyGoLogoPainter.eyePath(1).getBounds();
    expect(closed.width, closeTo(open.width, 0.01));
    expect(closed.height, lessThan(open.height / 2));
  });
}
