import 'package:birdnet_live/fork/design/widgets/balanced_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 10);

int _lines(String text, double width, [TextScaler scaler = TextScaler.noScaling]) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    textAlign: TextAlign.center,
  )..layout(maxWidth: width);
  final count = painter.computeLineMetrics().length;
  painter.dispose();
  return count;
}

void main() {
  test('a single line keeps the full width', () {
    expect(
      BalancedText.balancedWidth('Merle', style: _style, maxWidth: 300),
      300,
    );
  });

  test('two lines: narrower box, same number of lines, balanced', () {
    const text = 'Mésange à longue queue';
    // Ahem: 10 px a letter. Room for the first words, not for everything.
    const max = 150.0;
    final full = _lines(text, max);
    expect(full, 2);
    final width = BalancedText.balancedWidth(
      text,
      style: _style,
      maxWidth: max,
    );
    expect(width, lessThan(max));
    expect(_lines(text, width), full);
    // Narrower would need another line.
    expect(_lines(text, width - 3), greaterThan(full));
  });

  test('never wider than the room, follows the text scale', () {
    const text = 'Rougequeue à front blanc';
    for (final scale in [1.0, 1.3]) {
      final scaler = TextScaler.linear(scale);
      final width = BalancedText.balancedWidth(
        text,
        style: _style,
        maxWidth: 170,
        textScaler: scaler,
      );
      expect(width, lessThanOrEqualTo(170));
      expect(_lines(text, width, scaler), _lines(text, 170, scaler));
    }
  });

  testWidgets('renders the text in a narrowed, centered box', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 150,
            child: Column(
              children: [
                BalancedText('Mésange à longue queue', style: _style),
              ],
            ),
          ),
        ),
      ),
    );
    final box = tester.getSize(find.byType(BalancedText));
    expect(box.width, lessThan(150));
    expect(find.text('Mésange à longue queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
