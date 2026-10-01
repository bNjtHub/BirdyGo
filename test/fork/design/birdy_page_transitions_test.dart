import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/data/species_bundle_decode.dart';
import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_page_transitions.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/entrance.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  bool reduced = false,
  TargetPlatform platform = TargetPlatform.linux,
  required Widget next,
}) {
  return MaterialApp(
    theme: BirdyTheme.light().copyWith(platform: platform),
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
    home: Builder(
      builder:
          (context) => Scaffold(
            body: TextButton(
              key: const Key('go'),
              onPressed:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => next)),
              child: const Text('go'),
            ),
          ),
    ),
  );
}

double _nextX(WidgetTester t) => t.getTopLeft(find.byKey(const Key('next'))).dx;

void main() {
  test('builder per platform: system gestures kept on Android and iOS', () {
    final b = BirdyTheme.light().pageTransitionsTheme.builders;
    expect(
      b[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
    expect(b[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    expect(b[TargetPlatform.linux], isA<BirdyPageTransitionsBuilder>());
    const t = BirdyPageTransitionsBuilder();
    expect(t.transitionDuration, BirdyMotion.enter);
    expect(t.reverseTransitionDuration, lessThan(t.transitionDuration));
  });

  testWidgets('a pushed page slides at most maxOffset, then rests', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(next: const Scaffold(body: SizedBox(key: Key('next')))),
    );
    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(_nextX(tester), greaterThan(0));
    expect(_nextX(tester), lessThanOrEqualTo(BirdyMotion.maxOffset));
    await tester.pumpAndSettle();
    expect(_nextX(tester), 0);
  });

  testWidgets('reduced motion: fade only, no slide', (tester) async {
    await tester.pumpWidget(
      _app(
        reduced: true,
        next: const Scaffold(body: SizedBox(key: Key('next'))),
      ),
    );
    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(_nextX(tester), 0);
    await tester.pumpAndSettle();
  });

  testWidgets('BirdyEntrance waits for the page transition to end', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        next: const Scaffold(
          body: BirdyEntrance(child: SizedBox(key: Key('next'))),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(BirdyMotion.enter ~/ 2);
    final entrance = find.descendant(
      of: find.byType(BirdyEntrance),
      matching: find.byType(FadeTransition),
    );
    // Mid-transition: the entrance has not started.
    expect(tester.widget<FadeTransition>(entrance).opacity.value, 0);
    await tester.pump(BirdyMotion.enter);
    await tester.pump(BirdyMotion.enter ~/ 2);
    expect(
      tester.widget<FadeTransition>(entrance).opacity.value,
      greaterThan(0),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('BirdyEntrance waits at most the fork transition duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        platform: TargetPlatform.android, // 450 ms system transition
        next: const Scaffold(
          body: BirdyEntrance(child: SizedBox(key: Key('next'))),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    final entrance = find.descendant(
      of: find.byType(BirdyEntrance),
      matching: find.byType(FadeTransition),
    );
    await tester.pump(BirdyMotion.enter - const Duration(milliseconds: 20));
    expect(tester.widget<FadeTransition>(entrance).opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.widget<FadeTransition>(entrance).opacity.value,
      greaterThan(0),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('BirdyEntrance does not wait under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        reduced: true,
        next: const Scaffold(
          body: BirdyEntrance(child: SizedBox(key: Key('next'))),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(BirdyMotion.enter ~/ 2);
    final entrance = find.descendant(
      of: find.byType(BirdyEntrance),
      matching: find.byType(FadeTransition),
    );
    expect(
      tester.widget<FadeTransition>(entrance).opacity.value,
      greaterThan(0),
    );
    await tester.pumpAndSettle();
  });

  test('decodeSpeciesBundle is a pure gzip + JSON decode', () {
    final bytes = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode({'Turdus merula': 'Chant'}))),
    );
    expect(decodeSpeciesBundle(bytes), {'Turdus merula': 'Chant'});
  });
}
