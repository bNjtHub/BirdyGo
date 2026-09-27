import 'package:birdnet_live/fork/design/svg_path.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absolute, relative, implicit line-tos and close', () {
    final bounds = parseSvgPath('M2 2h10v10H2z m4 4l2 2').getBounds();
    expect(bounds, const Rect.fromLTRB(2, 2, 12, 12));
  });

  test('arcs, with packed flags', () {
    final a = parseSvgPath('M4 12a8 8 0 0 1 16 0').getBounds();
    final b = parseSvgPath('M4 12a8 8 0 0116 0').getBounds();
    expect(a.left, closeTo(4, 0.01));
    expect(a.right, closeTo(20, 0.01));
    expect(a.top, closeTo(4, 0.01));
    expect(b, a);
  });

  test('smooth curves reflect the last control point', () {
    final bounds = parseSvgPath('M3 13.5S6.5 8 12 8s9 5.5 9 5.5').getBounds();
    expect(bounds.left, closeTo(3, 0.01));
    expect(bounds.right, closeTo(21, 0.01));
  });

  test('every game glyph parses inside its 24 grid', () {
    final glyphs = [
      for (final s in GameConfig.statuses) s.glyph,
      GameConfig.migrantGlyph,
    ];
    for (final glyph in glyphs) {
      for (final d in [...glyph.paths, ...glyph.filled]) {
        final bounds = parseSvgPath(d).getBounds();
        expect(
          bounds.isEmpty && bounds.width == 0 && bounds.height == 0,
          isFalse,
          reason: d,
        );
        expect(
          const Rect.fromLTRB(0, 0, 24, 24).expandToInclude(bounds),
          const Rect.fromLTRB(0, 0, 24, 24),
          reason: d,
        );
      }
    }
  });
}
