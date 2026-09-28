import 'package:birdnet_live/fork/ranking/activity_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget bars) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 240, height: 100, child: bars),
      ),
    ),
  );

  testWidgets('a tap fires onSelect with the bar\'s index and value', (
    tester,
  ) async {
    int? gotIndex;
    int? gotValue;
    await pump(
      tester,
      ActivityBars(
        values: [for (var h = 0; h < 24; h++) h == 7 ? 10 : 1],
        labels: const {},
        semanticLabel: 'test',
        onSelect: (index, value) {
          gotIndex = index;
          gotValue = value;
        },
      ),
    );
    final rect = tester.getRect(find.byType(ActivityBars));
    final slot = rect.width / 24;
    await tester.tapAt(Offset(rect.left + slot * 7.5, rect.top + 5));
    await tester.pump();
    expect(gotIndex, 7);
    expect(gotValue, 10);
  });

  testWidgets('a long press also fires onSelect', (tester) async {
    int? gotIndex;
    await pump(
      tester,
      ActivityBars(
        values: [for (var h = 0; h < 24; h++) h == 3 ? 4 : 1],
        labels: const {},
        semanticLabel: 'test',
        onSelect: (index, value) => gotIndex = index,
      ),
    );
    final rect = tester.getRect(find.byType(ActivityBars));
    final slot = rect.width / 24;
    await tester.longPressAt(Offset(rect.left + slot * 3.5, rect.top + 5));
    await tester.pump();
    expect(gotIndex, 3);
  });

  testWidgets('without onSelect, taps do nothing (no gesture detector)', (
    tester,
  ) async {
    await pump(
      tester,
      ActivityBars(
        values: [1, 2, 3],
        labels: const {},
        semanticLabel: 'test',
      ),
    );
    await tester.tap(find.byType(ActivityBars));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('colorForValue colors non-zero bars, trackColor the rest', (
    tester,
  ) async {
    await pump(
      tester,
      ActivityBars(
        values: const [0, 5],
        labels: const {},
        semanticLabel: 'test',
        trackColor: Colors.grey,
        colorForValue: (value, maxValue) => Colors.red,
      ),
    );
    final painter =
        tester
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .map((w) => w.painter)
                .firstWhere((p) => p != null)
            as dynamic;
    expect(painter.emptyColor, Colors.grey);
    expect(painter.colorForValue!(5, 5), Colors.red);
  });

  testWidgets('one summary Semantics node, not one per bar', (tester) async {
    await pump(
      tester,
      ActivityBars(
        values: [for (var h = 0; h < 24; h++) h],
        labels: const {},
        semanticLabel: 'Résumé de l\'activité',
      ),
    );
    expect(
      find.bySemanticsLabel('Résumé de l\'activité'),
      findsOneWidget,
    );
  });
}
