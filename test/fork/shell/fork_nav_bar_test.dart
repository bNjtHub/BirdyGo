import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/shell/fork_nav_bar.dart';
import 'package:birdnet_live/fork/shell/fork_shell.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bottom bar alone (J6j): what takes the touch, and the colors of the
/// disc in every bird theme.
void main() {
  Future<({List<String> taps})> pumpBar(
    WidgetTester tester, {
    BirdyBird bird = BirdyBird.martin,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final taps = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme:
              dark ? BirdyTheme.dark(bird: bird) : BirdyTheme.light(bird: bird),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                // The page behind the bar.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps.add('page'),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ForkNavBar(
                    selected: ForkTab.home,
                    onSelect: (t) => taps.add(t.name),
                    onListen: () => taps.add('listen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return (taps: taps);
  }

  testWidgets('the strip above the bar, beside the disc, is the page\'s', (
    tester,
  ) async {
    final taps = (await pumpBar(tester)).taps;
    final bar = tester.getRect(find.byType(ForkNavBar));
    final disc = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.width == BirdySizes.listenDisc &&
            w.height == BirdySizes.listenDisc,
      ),
    );
    final y = bar.top + BirdySizes.listenDiscLift / 2;
    for (final x in [
      bar.left + 20,
      bar.left + bar.width * 0.3,
      disc.left - 4,
      disc.right + 4,
      bar.left + bar.width * 0.7,
      bar.right - 20,
    ]) {
      await tester.tapAt(Offset(x, y));
    }
    expect(taps, List.filled(6, 'page'));
    // On the disc, above the bar's surface: the listening.
    taps.clear();
    await tester.tapAt(Offset(disc.center.dx, y));
    expect(taps, ['listen']);
    // The bar's surface itself takes the touch, the page does not get it.
    taps.clear();
    await tester.tapAt(Offset(bar.left + 20, bar.bottom - 10));
    expect(taps, ['home']);
  });

  testWidgets('the disc ignores a corner outside its circle', (tester) async {
    final taps = (await pumpBar(tester)).taps;
    final disc = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.width == BirdySizes.listenDisc &&
            w.height == BirdySizes.listenDisc,
      ),
    );
    await tester.tapAt(disc.topLeft + const Offset(2, 2));
    expect(taps, ['page']);
  });

  testWidgets('a tab presses without an ink splash, and still selects', (
    tester,
  ) async {
    final taps = (await pumpBar(tester)).taps;
    final bar = find.byType(ForkNavBar);
    expect(
      find.descendant(of: bar, matching: find.byType(InkWell)),
      findsNothing,
    );
    final tab = find.descendant(of: bar, matching: find.text('Carnet'));
    final gesture = await tester.startGesture(tester.getCenter(tab));
    await tester.pump(const Duration(milliseconds: 50));
    // No ink ripple is painted on a Material under the tab.
    expect(
      find.descendant(of: bar, matching: find.byType(InkResponse)),
      findsNothing,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, contains('notebook'));
  });

  testWidgets('idle: the wing rests, nothing ticks', (tester) async {
    await pumpBar(tester);
    // Idle: nothing ticks once the first frames are over.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  // The disc reads on the bar in every theme: ink on the accent fill (the
  // wing bars), the label in the theme's text accent on the bar's surface.
  // The disc's fill against the bar (2.9 to 3.1 in light themes) is a shape
  // contrast that is not guaranteed, so it is not asserted.
  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      test('contrast ${bird.name} ${dark ? 'dark' : 'light'}', () {
        final c = BirdyColors.forBird(
          bird,
          dark ? Brightness.dark : Brightness.light,
        );
        final ink = _ratio(c.onAccent, c.accent);
        final label = _ratio(c.accentText, c.surface1);
        expect(ink, greaterThanOrEqualTo(4.5));
        expect(label, greaterThanOrEqualTo(4.5));
      });
    }
  }

  test('the press is the one exception: 0.95, deeper than the 0.97 rule', () {
    expect(BirdyMotion.listenDiscPressScale, 0.95);
    expect(BirdyMotion.listenDiscPressScale, lessThan(BirdyMotion.pressScale));
  });
}

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
