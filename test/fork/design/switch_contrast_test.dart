/// The off-state Switch (thumb and track outline) must reach WCAG 1.4.11's
/// 3:1 non-text contrast against the surfaces it sits on (J6f-b phone
/// feedback: an off switch was almost invisible in dark theme).
library;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/species_tint.dart' show contrastRatio;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectUiContrast(Color foreground, Color background, String name) {
  final ratio = contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(3),
    reason: '$name: ${ratio.toStringAsFixed(2)}:1 < 3:1',
  );
}

void main() {
  for (final theme in [BirdyTheme.light(), BirdyTheme.dark()]) {
    final mode = theme.brightness.name;
    final switchTheme = theme.switchTheme;
    const offStates = <WidgetState>{};
    final offThumb = switchTheme.thumbColor!.resolve(offStates)!;
    final offOutline = switchTheme.trackOutlineColor!.resolve(offStates)!;

    test('$mode off switch thumb reaches 3:1', () {
      expectUiContrast(offThumb, theme.colorScheme.surface, '$mode thumb/surface');
    });

    test('$mode off switch outline reaches 3:1', () {
      expectUiContrast(
        offOutline,
        theme.colorScheme.surface,
        '$mode outline/surface',
      );
      expectUiContrast(
        offOutline,
        theme.cardTheme.color!,
        '$mode outline/card',
      );
    });
  }
}
