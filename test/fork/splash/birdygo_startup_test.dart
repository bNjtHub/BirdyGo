import 'dart:async';

import 'package:birdnet_live/fork/splash/birdygo_splash.dart';
import 'package:birdnet_live/fork/splash/birdygo_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The splash reports its minimum display on the first frame that reaches it.

  testWidgets('slow initialization opens immediately after the intro is done', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    var calls = 0;
    await tester.pumpWidget(
      BirdyGoStartup(
        bootstrap: () {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.pump(); // Start the ticker before advancing the test clock.
    expect(find.byType(BirdyGoSplash), findsOneWidget);
    expect(find.text('The world is singing.'), findsOneWidget);
    expect(find.text('Listen.'), findsOneWidget);
    await tester.pump(BirdyGoSplash.minimumDisplay);
    await tester.pump(const Duration(milliseconds: 16));
    expect(calls, 1);
    expect(find.byType(BirdyGoSplash), findsOneWidget);
    // The bird keeps singing for as long as initialization takes.
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(BirdyGoSplash), findsOneWidget);
    expect(tester.takeException(), isNull);

    pending.complete(const MaterialApp(home: Text('App ready')));
    await tester.pump();
    await tester.pump();
    await tester.pump(); // Reveal after App has registered its launch holds.
    expect(find.text('App ready'), findsOneWidget);
    expect(find.byType(BirdyGoSplash), findsNothing);
  });

  testWidgets(
    'fast initialization keeps the splash until the intro completes',
    (tester) async {
      final pending = Completer<Widget>();
      await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.hasRunningAnimations, isTrue);
      pending.complete(const MaterialApp(home: Text('App ready')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(BirdyGoSplash), findsOneWidget);
      expect(find.text('App ready'), findsNothing);
      expect(find.text('App ready', skipOffstage: false), findsOneWidget);

      await tester.pump(BirdyGoSplash.minimumDisplay);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(find.text('App ready'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'retry after the intro does not replay it or repeat automatically',
    (tester) async {
      var calls = 0;
      final retry = Completer<Widget>();
      await tester.pumpWidget(
        BirdyGoStartup(
          bootstrap: () {
            calls++;
            return calls == 1
                ? Future<Widget>.error(StateError('Preferences unavailable'))
                : retry.future;
          },
        ),
      );
      await tester.pump();
      expect(
        find.text('BirdyGo could not start. Please try again.'),
        findsOneWidget,
      );
      await tester.pump(BirdyGoSplash.minimumDisplay);
      await tester.pump(const Duration(milliseconds: 16));
      expect(calls, 1);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(calls, 2);
      expect(find.text('Retry'), findsNothing);
      retry.complete(const MaterialApp(home: Text('Recovered')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Recovered'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an error can be retried while the intro is still running', (
    tester,
  ) async {
    var calls = 0;
    final retry = Completer<Widget>();
    await tester.pumpWidget(
      BirdyGoStartup(
        bootstrap: () {
          calls++;
          return calls == 1
              ? Future<Widget>.error(StateError('Preferences unavailable'))
              : retry.future;
        },
      ),
    );
    await tester.pump();
    expect(
      find.text('BirdyGo could not start. Please try again.'),
      findsOneWidget,
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls, 2);
    retry.complete(const MaterialApp(home: Text('Recovered')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BirdyGoSplash), findsOneWidget);
    expect(find.text('Recovered'), findsNothing);
    await tester.pump(BirdyGoSplash.minimumDisplay);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    await tester.pump(); // Paint the reveal scheduled after intro completion.
    expect(find.text('Recovered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an initialization completing after disposal is harmless', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
    final finishIntro =
        tester
            .widget<BirdyGoSplash>(find.byType(BirdyGoSplash))
            .onIntroComplete!;
    await tester.pumpWidget(const SizedBox());
    finishIntro();
    pending.complete(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion adds no intro wait and starts no ticker', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final pending = Completer<Widget>();
    await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    pending.complete(const MaterialApp(home: Text('App ready')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('App ready'), findsOneWidget);
    expect(find.byType(BirdyGoSplash), findsNothing);
  });

  for (final (locale, first, second, loading) in [
    ('fr', 'Le monde chante.', 'Écoute.', 'Chargement…'),
    ('en', 'The world is singing.', 'Listen.', 'Loading…'),
    ('ja', 'The world is singing.', 'Listen.', 'Loading…'),
  ]) {
    testWidgets('startup locale $locale uses the expected accessible copy', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.binding.platformDispatcher.localesTestValue = [Locale(locale)];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final pending = Completer<Widget>();
      await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
      expect(find.text(first), findsOneWidget);
      expect(find.text(second), findsOneWidget);
      expect(find.text(loading), findsOneWidget);
      // A screen reader hears the brand and the tagline as one phrase each.
      expect(find.bySemanticsLabel('BirdyGo'), findsOneWidget);
      expect(find.bySemanticsLabel('$first $second'), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('the tagline enters in two beats after the wordmark', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
    await tester.pump(); // Start the ticker.
    double opacityOf(String text) =>
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: find.text(text), matching: find.byType(Opacity))
                  .first,
            )
            .opacity;
    expect(opacityOf('Birdy'), 0);
    await tester.pump(const Duration(milliseconds: 1700));
    expect(opacityOf('Birdy'), 1);
    expect(opacityOf('The world is singing.'), 1);
    expect(opacityOf('Listen.'), 0);
    await tester.pump(const Duration(milliseconds: 800));
    expect(opacityOf('Listen.'), 1);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366),
  ]) {
    testWidgets('fits $size at 130 percent text scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
      );
      final pending = Completer<Widget>();
      await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
      await tester.pump(BirdyGoSplash.minimumDisplay);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      final wordmark = find.ancestor(
        of: find.text('Birdy'),
        matching: find.byType(Row),
      );
      expect(wordmark, findsOneWidget);
      expect(tester.getCenter(wordmark).dx, closeTo(size.width / 2, 1));
      expect(find.text('Go'), findsOneWidget);
      expect(find.text('The world is singing.'), findsOneWidget);
      expect(find.text('Listen.'), findsOneWidget);
    });
  }
}
