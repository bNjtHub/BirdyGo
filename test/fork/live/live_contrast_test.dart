import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design/contrast_test.dart' show expectAA, on;

/// The Live screen follows the app theme (J7): every pair it draws must read
/// in the four bird themes, light and dark. Text 4.5:1, graphics 3:1.
void main() {
  for (final bird in BirdyBird.values) {
    for (final brightness in Brightness.values) {
      final name = '${bird.name} ${brightness.name}';
      final c = BirdyColors.forBird(bird, brightness);
      // The page, the table rows and the cards of the Live screen.
      final surfaces = {
        'background': c.background,
        'surface1': c.surface1,
        'surface2': c.surface2,
      };

      group('Live $name', () {
        test('text on the page, the rows and the cards', () {
          for (final MapEntry(key: sName, value: bg) in surfaces.entries) {
            expectAA(c.text1, bg, '$name text1/$sName');
            expectAA(c.text2, bg, '$name text2/$sName');
            expectAA(c.accentText, bg, '$name accentText/$sName');
            expectAA(c.orioleText, bg, '$name orioleText/$sName');
          }
        });

        test('level badges, « Confirmé » and the rarity pills', () {
          for (final MapEntry(key: sName, value: bg) in surfaces.entries) {
            for (final (lName, level) in [
              ('sure', c.sure),
              ('probable', c.probable),
              ('toCheck', c.toCheck),
            ]) {
              expectAA(
                level.foreground,
                on(level.background, bg),
                '$name $lName/$sName',
              );
            }
            expectAA(c.text2, on(c.line, bg), '$name uncommon/$sName');
            expectAA(
              c.orioleText,
              on(c.orioleContainer, bg),
              '$name rare/$sName',
            );
          }
        });

        test('buttons and the volume alert', () {
          expectAA(c.onAccent, c.accent, '$name onAccent/accent');
          expectAA(c.onOriole, c.oriole, '$name onOriole/oriole');
          for (final bg in [c.background, c.surface1]) {
            final tint = on(c.orioleContainer, bg);
            expectAA(c.text1, tint, '$name alert title/tint');
            expectAA(c.text2, tint, '$name alert caption/tint');
          }
        });

        test('graphics: outline of the play button, rings (3:1)', () {
          for (final MapEntry(key: sName, value: bg) in surfaces.entries) {
            expectAA(
              c.accentText,
              bg,
              '$name play outline/$sName',
              min: 3,
            );
          }
          expectAA(c.accent, c.onAccent, '$name accent fill/ink', min: 3);
        });
      });
    }
  }
}
