import 'package:birdnet_live/fork/design/widgets/birdy_wing_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paints at 28 by default and at the given size', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [BirdyWingIcon(), BirdyWingIcon(size: 40)]),
      ),
    );
    final sizes =
        tester
            .widgetList<BirdyWingIcon>(find.byType(BirdyWingIcon))
            .map((w) => tester.getSize(find.byWidget(w)))
            .toList();
    expect(sizes, [const Size.square(28), const Size.square(40)]);
    expect(tester.takeException(), isNull);
  });
}
