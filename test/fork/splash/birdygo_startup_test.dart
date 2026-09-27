import 'dart:async';

import 'package:birdnet_live/fork/home/birdygo_logo.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash.dart';
import 'package:birdnet_live/fork/splash/birdygo_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows real pending work and opens immediately when ready', (
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
    expect(find.byType(BirdyGoSplash), findsOneWidget);
    expect(find.text('The world is singing. Listen.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(BirdyGoSplash), findsOneWidget);

    pending.complete(const MaterialApp(home: Text('App ready')));
    await tester.pump();
    await tester.pump();
    await tester.pump(); // Reveal after App has registered its launch holds.
    expect(find.text('App ready'), findsOneWidget);
    expect(find.byType(BirdyGoSplash), findsNothing);
  });

  testWidgets('does not wait for the wing animation when initialization ends', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.hasRunningAnimations, isTrue);
    pending.complete(const MaterialApp(home: Text('App ready')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('App ready'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'failure offers retry without automatic repeated initialization',
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
      await tester.pump(const Duration(seconds: 2));
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

  testWidgets('an initialization completing after disposal is harmless', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
    await tester.pumpWidget(const SizedBox());
    pending.complete(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion draws the complete mark without an active ticker',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final pending = Completer<Widget>();
      await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BirdyGoLogo),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((paint.painter! as BirdyGoLogoPainter).progress.value, 1);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  for (final (locale, tagline) in [
    ('fr', 'Le monde chante. Écoute.'),
    ('en', 'The world is singing. Listen.'),
    ('ja', 'The world is singing. Listen.'),
  ]) {
    testWidgets('startup locale $locale uses the expected accessible copy', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localesTestValue = [Locale(locale)];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final pending = Completer<Widget>();
      await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
      expect(find.text(tagline), findsOneWidget);
      expect(find.text('BirdyGo'), findsOneWidget);
    });
  }

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
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('BirdyGo'), findsOneWidget);
      expect(find.text('The world is singing. Listen.'), findsOneWidget);
    });
  }
}
