import 'package:birdnet_live/fork/design/widgets/birdy_cross_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget column(Widget child) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 358,
        child: ListView(children: [BirdyCrossFade(child: child)]),
      ),
    ),
  );

  testWidgets('a block keeps the full width before and after the fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      column(const SizedBox(key: ValueKey('skeleton'), height: 40)),
    );
    expect(tester.getSize(find.byKey(const ValueKey('skeleton'))).width, 358);

    await tester.pumpWidget(
      column(const Text('Rougegorge', key: ValueKey('content'))),
    );
    // Mid-fade: both layers are full width.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 358);
    expect(tester.getSize(find.byKey(const ValueKey('skeleton'))).width, 358);

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 358);
    expect(find.byKey(const ValueKey('skeleton')), findsNothing);
  });
}
