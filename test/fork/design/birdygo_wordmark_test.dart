import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdygo_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  double size, {
  BirdyBird bird = BirdyBird.loriot,
  bool dark = false,
}) => MaterialApp(
  theme: dark ? BirdyTheme.dark(bird: bird) : BirdyTheme.light(bird: bird),
  home: Center(child: BirdyGoWordmark(size: size)),
);

Finder get _dot => find.descendant(
  of: find.byType(BirdyGoWordmark),
  matching: find.byType(DecoratedBox),
);

Finder get _rich => find.descendant(
  of: find.byType(BirdyGoWordmark),
  matching: find.byType(RichText),
);

void main() {
  for (final size in [24.0, BirdyGoWordmark.startupSize]) {
    testWidgets('dot size, margins and height (size $size)', (tester) async {
      await tester.pumpWidget(_host(size));
      final paragraph = tester.renderObject<RenderParagraph>(_rich);
      final baselineY =
          paragraph.localToGlobal(Offset.zero).dy +
          paragraph.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final rect = tester.getRect(_dot);
      expect(rect.width, closeTo(size * BirdyGoWordmark.dotRatio, .01));
      expect(rect.height, closeTo(rect.width, .01));
      // Centre at mid x-height above the baseline.
      expect(
        rect.center.dy,
        closeTo(baselineY - size * BirdyGoWordmark.nunitoXHeight / 2, .6),
      );
      // Equal margins on both sides.
      final pad = find.ancestor(of: _dot, matching: find.byType(Padding)).first;
      final padRect = tester.getRect(pad);
      final margin = size * BirdyGoWordmark.dotMarginRatio;
      expect(rect.left - padRect.left, closeTo(margin, .01));
      expect(padRect.right - rect.right, closeTo(margin, .01));
    });
  }

  test('3 px margin at size 24', () {
    expect(24 * BirdyGoWordmark.dotMarginRatio, 3);
  });

  for (final dark in [false, true]) {
    for (final bird in BirdyBird.values) {
      testWidgets('colors of ${bird.name}, dark $dark', (tester) async {
        await tester.pumpWidget(_host(24, bird: bird, dark: dark));
        final brightness = dark ? Brightness.dark : Brightness.light;
        final brand = BirdyBrandColors(bird, brightness);
        final deco =
            tester.widget<DecoratedBox>(_dot).decoration as ShapeDecoration;
        expect(deco.color, brand.wordmarkDot);
        // Text wraps the given span in its own root span.
        final root =
            (tester.widget<RichText>(_rich).text as TextSpan).children!.first
                as TextSpan;
        final birdy = root.children![0] as TextSpan;
        final go = root.children![2] as TextSpan;
        expect(go.style!.color, brand.accentText);
        expect(go.style!.fontWeight, FontWeight.w900);
        expect(birdy.style!.fontWeight, FontWeight.w800);
        expect(
          birdy.style!.color,
          BirdyColors.forBird(bird, brightness).text1,
        );
      });
    }
  }

  testWidgets('one untranslated semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(24));
    expect(find.bySemanticsLabel('BirdyGo'), findsOneWidget);
    expect(find.bySemanticsLabel('Birdy'), findsNothing);
    handle.dispose();
  });
}
