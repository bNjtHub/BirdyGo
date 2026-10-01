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

  testWidgets('the highlighted bar label is bold, in the highlight color', (
    tester,
  ) async {
    const mark = Color(0xFF13233A);
    await pump(
      tester,
      ActivityBars(
        values: const [1, 2, 3, 4],
        labels: const {0: 'J', 1: 'F', 2: 'M', 3: 'A'},
        semanticLabel: 'test',
        highlightIndex: 2,
        highlightColor: mark,
      ),
    );
    final current = tester.widget<Text>(find.text('M')).style!;
    expect(current.fontWeight, FontWeight.w800);
    expect(current.color, mark);
    final other = tester.widget<Text>(find.text('F')).style!;
    expect(other.fontWeight, isNot(FontWeight.w800));
    expect(other.color, isNot(mark));
  });

  group('dimUnselected', () {
    const bar = Color(0xFF2255AA);
    final dimmed = bar.withValues(alpha: ActivityBars.dimmedOpacity);

    Widget bars({required bool dim, int? selected}) => ActivityBars(
      values: const [1, 2, 3],
      labels: const {},
      semanticLabel: 'test',
      color: bar,
      selectedIndex: selected,
      dimUnselected: dim,
    );

    testWidgets('fades the other bars to the dimmed opacity', (tester) async {
      await pump(tester, bars(dim: true));
      await pump(tester, bars(dim: true, selected: 1));
      await tester.pumpAndSettle();
      final chart = find.descendant(
        of: find.byType(ActivityBars),
        matching: find.byType(CustomPaint),
      );
      expect(
        tester.renderObject(chart.first),
        paints
          ..rrect(color: dimmed)
          ..rrect(color: bar)
          ..rrect(color: dimmed),
      );
    });

    testWidgets('full opacity without a selection', (tester) async {
      await pump(tester, bars(dim: true));
      await tester.pumpAndSettle();
      final chart = find.descendant(
        of: find.byType(ActivityBars),
        matching: find.byType(CustomPaint),
      );
      expect(
        tester.renderObject(chart.first),
        paints
          ..rrect(color: bar)
          ..rrect(color: bar)
          ..rrect(color: bar),
      );
    });

    testWidgets('off by default: a selection changes nothing', (tester) async {
      await pump(tester, bars(dim: false, selected: 1));
      await tester.pumpAndSettle();
      final chart = find.descendant(
        of: find.byType(ActivityBars),
        matching: find.byType(CustomPaint),
      );
      expect(
        tester.renderObject(chart.first),
        paints
          ..rrect(color: bar)
          ..rrect(color: bar)
          ..rrect(color: bar),
      );
    });
  });
}
