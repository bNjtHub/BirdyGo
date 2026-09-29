import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [BirdyColors.light]),
  home: MediaQuery(
    data: const MediaQueryData(size: Size(400, 800), disableAnimations: true),
    child: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
  ),
);

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Container>(find.byType(Container).first).decoration!
        as BoxDecoration;

void main() {
  testWidgets('box is rounded with a gradient, never a flat rectangle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(BirdySkeleton.box(width: 120, height: 60, radius: BirdyRadii.card)),
    );
    final d = _decoration(tester);
    expect(d.borderRadius, BorderRadius.circular(BirdyRadii.card));
    final g = d.gradient! as LinearGradient;
    expect(g.colors.first, BirdyColors.light.skeleton);
    expect(g.colors.last, isNot(g.colors.first));
  });

  testWidgets('the default radius is not square', (tester) async {
    await tester.pumpWidget(_app(BirdySkeleton.box(width: 50, height: 50)));
    expect(_decoration(tester).borderRadius, isNot(BorderRadius.zero));
  });

  testWidgets('circle and bar are fully rounded', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            BirdySkeleton.circle(size: 36),
            BirdySkeleton.bar(width: 100, height: 8),
          ],
        ),
      ),
    );
    final radii = [
      for (final c in tester.widgetList<Container>(find.byType(Container)))
        (c.decoration! as BoxDecoration).borderRadius,
    ];
    expect(radii, everyElement(BorderRadius.circular(BirdyRadii.pill)));
    expect(tester.getSize(find.byType(Container).first), const Size(36, 36));
  });

  testWidgets('a text skeleton paints one rounded pill per line', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 15);
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 100,
          child: BirdySkeleton.text(
            style,
            placeholder: 'word word word word word word',
            maxLines: null,
          ),
        ),
      ),
    );
    final stack =
        find.ancestor(of: find.byType(Text), matching: find.byType(Stack)).first;
    final painted = find.descendant(
      of: stack,
      matching: find.byType(CustomPaint),
    );
    // 3 wrapped lines at 100 px: three pills.
    expect(painted, paints..rrect()..rrect()..rrect());
    // Same size as the real text would take.
    expect(tester.getSize(stack), tester.getSize(find.byType(Text)));
  });
}
