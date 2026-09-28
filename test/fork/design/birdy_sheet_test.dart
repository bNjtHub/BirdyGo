import 'package:birdnet_live/fork/design/widgets/birdy_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(390, 844);
  final lastKey = UniqueKey();

  Future<void> pumpWithBottomInset(
    WidgetTester tester,
    double bottomInset,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Center(
                  child: ElevatedButton(
                    onPressed:
                        () => showBirdySheet<void>(
                          context: context,
                          builder:
                              (_) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 40, width: 200),
                                  SizedBox(
                                    key: lastKey,
                                    height: 20,
                                    width: double.infinity,
                                  ),
                                ],
                              ),
                        ),
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'clears the bottom nav bar: the sheet\'s last widget ends above it',
    (tester) async {
      await pumpWithBottomInset(tester, 48);

      final bottom = tester.getBottomLeft(find.byKey(lastKey)).dy;

      expect(bottom, lessThanOrEqualTo(size.height - 48 + 0.5));
    },
  );

  testWidgets('a zero inset changes nothing: the sheet still meets the '
      'screen edge', (tester) async {
    await pumpWithBottomInset(tester, 0);

    final bottom = tester.getBottomLeft(find.byKey(lastKey)).dy;

    expect(bottom, closeTo(size.height, 1));
  });
}
