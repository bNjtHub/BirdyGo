import 'package:birdnet_live/fork/live/spectrogram_label_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 400.0;

  test('names far apart are all drawn where their mark starts', () {
    final xs = placeMarkLabels(const [
      MarkLabelSlot(left: 10, width: 60),
      MarkLabelSlot(left: 100, width: 60),
    ], maxWidth: width);
    expect(xs, [10, 100]);
  });

  test('a name that would touch the previous one is skipped (8 px gap)', () {
    final xs = placeMarkLabels(const [
      MarkLabelSlot(left: 10, width: 60),
      MarkLabelSlot(left: 77, width: 50), // 7 px after the first ends
      MarkLabelSlot(left: 78, width: 50), // exactly 8 px: fits
    ], maxWidth: width);
    expect(xs, [10, null, 78]);
  });

  test('a skipped name does not push the next one away', () {
    final xs = placeMarkLabels(const [
      MarkLabelSlot(left: 0, width: 100),
      MarkLabelSlot(left: 50, width: 100),
      MarkLabelSlot(left: 110, width: 40),
    ], maxWidth: width);
    expect(xs, [0, null, 110]);
  });

  test('a passage that began before the window has no name', () {
    final xs = placeMarkLabels(const [
      MarkLabelSlot(left: 0, width: 60, startsBeforeWindow: true),
      MarkLabelSlot(left: 30, width: 60),
    ], maxWidth: width);
    expect(xs, [null, 30]);
  });

  test('near the right edge a name is pushed left to fit', () {
    final xs = placeMarkLabels(const [
      MarkLabelSlot(left: 390, width: 60),
    ], maxWidth: width);
    expect(xs, [340]);
  });

  test('a name wider than the strip is not drawn', () {
    final xs = placeMarkLabels(const [
      MarkLabelSlot(left: 0, width: 500),
    ], maxWidth: width);
    expect(xs, [null]);
  });
}
