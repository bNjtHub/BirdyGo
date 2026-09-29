import 'package:birdnet_live/fork/design/widgets/birdy_step_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _active = Color(0xFF0B6E77);
const _done = Color(0xFF19A7B3);
const _idle = Color(0xFFC5CCC2);

Future<void> _pump(
  WidgetTester tester, {
  int current = 1,
  Color? doneColor,
  String? label,
  bool reduced = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: BirdyStepDots(
          count: 4,
          current: current,
          activeColor: _active,
          inactiveColor: _idle,
          doneColor: doneColor,
          semanticLabel: label,
        ),
      ),
    ),
  ),
);

List<AnimatedContainer> _dots(WidgetTester tester) =>
    tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();

Color? _color(AnimatedContainer dot) => (dot.decoration as BoxDecoration).color;

void main() {
  testWidgets('the current dot is a longer pill of the active color', (
    tester,
  ) async {
    await _pump(tester);
    final dots = _dots(tester);
    expect(dots, hasLength(4));
    expect(tester.getSize(find.byWidget(dots[1])).width, 22);
    expect(tester.getSize(find.byWidget(dots[0])).width, 8);
    expect(_color(dots[1]), _active);
    expect(_color(dots[0]), _idle);
    expect(_color(dots[2]), _idle);
  });

  testWidgets('done dots take their own color', (tester) async {
    await _pump(tester, current: 2, doneColor: _done);
    final dots = _dots(tester);
    expect(_color(dots[0]), _done);
    expect(_color(dots[1]), _done);
    expect(_color(dots[2]), _active);
    expect(_color(dots[3]), _idle);
  });

  testWidgets('labelled for screen readers, or hidden from them', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, label: '2 sur 4');
    expect(find.bySemanticsLabel('2 sur 4'), findsOneWidget);
    await _pump(tester);
    expect(find.bySemanticsLabel('2 sur 4'), findsNothing);
    handle.dispose();
  });

  testWidgets('moving on animates, unless motion is reduced', (tester) async {
    await _pump(tester, current: 0);
    await _pump(tester, current: 1);
    await tester.pump(const Duration(milliseconds: 40));
    final mid = tester.getSize(find.byWidget(_dots(tester)[1])).width;
    expect(mid, greaterThan(8));
    expect(mid, lessThan(22));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byWidget(_dots(tester)[1])).width, 22);

    await _pump(tester, current: 0, reduced: true);
    await _pump(tester, current: 1, reduced: true);
    await tester.pump();
    expect(tester.getSize(find.byWidget(_dots(tester)[1])).width, 22);
  });
}
