/// SPEC.md 5.6, J6f-b: the notebook grid card reserves a fixed 2-line
/// height for the name, so the caption / « Nouveau » badge below always
/// sits at the same spot whether the name wraps to one line or two.
library;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/species_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Rect> captionRect(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 110,
            height: 220,
            child: SpeciesCard(
              name: name,
              visual: const SizedBox(width: 40, height: 40),
              caption: const Text('23 fois'),
            ),
          ),
        ),
      ),
    );
    return tester.getRect(find.text('23 fois'));
  }

  testWidgets(
    'the caption sits at the same spot for a 1-line and a 2-line name',
    (tester) async {
      final oneLine = await captionRect(tester, 'Merle');
      final twoLines = await captionRect(
        tester,
        'Fauvette à tête noire, un nom bien plus long',
      );
      expect(oneLine.top, twoLines.top);
      expect(oneLine.bottom, twoLines.bottom);
    },
  );

  testWidgets('a 2-line name does not overflow', (tester) async {
    await captionRect(tester, 'Fauvette à tête noire, un nom bien plus long');
    expect(tester.takeException(), isNull);
  });
}
