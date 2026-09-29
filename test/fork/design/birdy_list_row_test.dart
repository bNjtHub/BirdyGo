import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_list_block.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_list_row.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: BirdyTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('a row is at least 72 high and 48 wide-tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.topLeft,
          child: BirdyListRow(
            title: 'Réglages',
            icon: AppIcons.search,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(BirdyListRow));
    expect(size.height, greaterThanOrEqualTo(BirdySizes.row));
    expect(size.height, greaterThanOrEqualTo(BirdySizes.target));
    expect(size.width, greaterThanOrEqualTo(BirdySizes.target));
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
    // Far right edge of the row still taps.
    await tester.tapAt(Offset(size.width - 4, size.height / 2));
    expect(taps, 1);
  });

  testWidgets('no chevron without a tap; subtitle shown', (tester) async {
    await tester.pumpWidget(
      _app(const BirdyListRow(title: 'Titre', subtitle: 'Sous-titre')),
    );
    expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    expect(find.text('Sous-titre'), findsOneWidget);
  });

  testWidgets('the block titles its rows and separates them by dividers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BirdyListBlock(
          title: 'Bloc',
          trailing: Text('3'),
          children: [
            BirdyListRow(title: 'A'),
            BirdyListRow(title: 'B'),
            BirdyListRow(title: 'C'),
          ],
        ),
      ),
    );
    expect(find.text('Bloc'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });
}
