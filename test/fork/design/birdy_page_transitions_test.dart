import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/data/species_bundle_decode.dart';
import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_page_transitions.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool reduced = false, required Widget next}) {
  return MaterialApp(
    theme: BirdyTheme.light(),
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
  test('theme uses the BirdyGo transition on every platform', () {
    final theme = BirdyTheme.light();
    for (final p in TargetPlatform.values) {
      expect(
        theme.pageTransitionsTheme.builders[p],
        isA<BirdyPageTransitionsBuilder>(),
      );
    }
    const b = BirdyPageTransitionsBuilder();
    expect(b.transitionDuration, BirdyMotion.enter);
    expect(b.reverseTransitionDuration, lessThan(b.transitionDuration));
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

  test('decodeSpeciesBundle is a pure gzip + JSON decode', () {
    final bytes = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode({'Turdus merula': 'Chant'}))),
    );
    expect(decodeSpeciesBundle(bytes), {'Turdus merula': 'Chant'});
  });
}
