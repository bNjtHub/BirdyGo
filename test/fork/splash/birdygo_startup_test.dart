import 'dart:async';

import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:birdnet_live/fork/splash/birdygo_startup.dart';
import 'package:birdnet_live/fork/splash/birdygo_warm_up.dart';
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

  for (final (brightness, background) in [
    (Brightness.light, BirdyBrand.mist),
    (Brightness.dark, BirdyBrand.ink),
  ]) {
    testWidgets('startup background follows the device theme: $brightness', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final pending = Completer<Widget>();
      await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(BirdyGoSplash),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, background);
      pending.complete(const MaterialApp(home: Text('App ready')));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  }

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
      // The board shows the bar only; a screen reader still hears the step.
      expect(find.text(loading), findsNothing);
      expect(find.bySemanticsLabel(loading), findsOneWidget);
      // A screen reader hears the brand and the tagline as one phrase each.
      expect(find.bySemanticsLabel('BirdyGo'), findsOneWidget);
      expect(find.bySemanticsLabel('$first $second'), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('the splash waits for the real loading, step by step', (
    tester,
  ) async {
    final audio = Completer<void>();
    final geo = Completer<void>();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      BirdyGoStartup(
        bootstrap: () async => const MaterialApp(home: Text('App ready')),
        warmUp:
            (progress) => runBirdyGoWarmUp({
              BirdyGoLoadStep.audioModel: () => audio.future,
              BirdyGoLoadStep.geoModel: () => geo.future,
            }, progress),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      find.bySemanticsLabel('Loading the bird song model…'),
      findsOneWidget,
    );

    audio.complete();
    await tester.pump();
    expect(
      find.bySemanticsLabel('Loading the species of your area…'),
      findsOneWidget,
    );

    // The minimum display is over, but the geo-model still loads.
    await tester.pump(BirdyGoSplash.minimumDisplay);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(BirdyGoSplash), findsOneWidget);
    // App is not even mounted yet: its home would start the same loads.
    expect(find.text('App ready', skipOffstage: false), findsNothing);

    geo.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('App ready'), findsOneWidget);
    expect(find.byType(BirdyGoSplash), findsNothing);
    semantics.dispose();
  });

  testWidgets('fast loading still keeps the minimum display, then says ready', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      BirdyGoStartup(
        bootstrap: () async => const MaterialApp(home: Text('App ready')),
        warmUp: (progress) => runBirdyGoWarmUp(const {}, progress),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.bySemanticsLabel('Ready.'), findsOneWidget);
    expect(find.text('App ready'), findsNothing);
    await tester.pump(BirdyGoSplash.minimumDisplay);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(find.text('App ready'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('loading that never ends opens the app after the time limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      BirdyGoStartup(
        bootstrap: () async => const MaterialApp(home: Text('App ready')),
        warmUp: (progress) => Completer<void>().future,
      ),
    );
    await tester.pump();
    await tester.pump(BirdyGoSplash.minimumDisplay);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('App ready'), findsNothing);
    await tester.pump(BirdyGoStartup.loadTimeout);
    await tester.pump();
    await tester.pump();
    expect(find.text('App ready'), findsOneWidget);
  });

  testWidgets('the name comes after the song: wordmark, then two beats', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
    await tester.pump(); // Start the ticker.
    Finder textOf(String text) => find.textContaining(text, findRichText: true);
    double opacityOf(String text) =>
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: textOf(text), matching: find.byType(Opacity))
                  .first,
            )
            .opacity;
    bool blurred(String text) =>
        tester
            .widget<ImageFiltered>(
              find
                  .ancestor(
                    of: textOf(text),
                    matching: find.byType(ImageFiltered),
                  )
                  .first,
            )
            .enabled;
    double bottomOf(String text) => tester.getBottomLeft(textOf(text)).dy;

    expect(opacityOf('Birdy'), 0);
    expect(opacityOf('The world is singing.'), 0);
    final low = bottomOf('Birdy');
    // Mid-entrance: fading in, still soft.
    await tester.pump(const Duration(milliseconds: 2600));
    expect(opacityOf('Birdy'), inExclusiveRange(0, 1));
    expect(blurred('Birdy'), isTrue);
    expect(opacityOf('The world is singing.'), 0);
    await tester.pump(const Duration(milliseconds: 650));
    expect(opacityOf('Birdy'), 1);
    expect(blurred('Birdy'), isFalse);
    expect(opacityOf('Listen.'), 0);
    await tester.pump(const Duration(milliseconds: 800));
    expect(opacityOf('The world is singing.'), 1);
    expect(opacityOf('Listen.'), 1);
    // The centred block has risen as the name came.
    expect(bottomOf('Birdy'), lessThan(low - 40));
  });

  testWidgets('reduced motion draws the settled composition at once', (
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
    for (final text in ['Birdy', 'The world is singing.', 'Listen.']) {
      final finder = find.textContaining(text, findRichText: true);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: finder, matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<ImageFiltered>(
              find
                  .ancestor(of: finder, matching: find.byType(ImageFiltered))
                  .first,
            )
            .enabled,
        isFalse,
      );
    }
    final painter =
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((paint) => paint.painter)
            .whereType<BirdyGoSingingPainter>()
            .single;
    expect(painter.still, isTrue);
    expect(
      tester
          .widgetList<Transform>(find.byType(Transform))
          .every((t) => t.transform.getTranslation().y == 0),
      isTrue,
    );
  });

  for (final (brightness, track) in [
    (Brightness.light, BirdyGoLoadingPainter.lightTrack),
    (Brightness.dark, BirdyBrand.mist.withValues(alpha: .12)),
  ]) {
    testWidgets('loading bar track follows the device theme: $brightness', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final pending = Completer<Widget>();
      await tester.pumpWidget(BirdyGoStartup(bootstrap: () => pending.future));
      await tester.pump();
      final bar =
          tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .where((paint) => paint.painter is BirdyGoLoadingPainter)
              .single;
      expect((bar.painter! as BirdyGoLoadingPainter).track, track);
      expect(bar.size, const Size(120, 3));
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
      await tester.pump(BirdyGoSplash.minimumDisplay);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      // « Birdy », the Oriole dot (a widget span) and « Go » are one text.
      final wordmark = find.textContaining(
        RegExp(r'^Birdy.Go$'),
        findRichText: true,
      );
      expect(wordmark, findsOneWidget);
      expect(tester.getCenter(wordmark).dx, closeTo(size.width / 2, 1));
      expect(find.text('The world is singing.'), findsOneWidget);
      expect(find.text('Listen.'), findsOneWidget);
    });
  }
}
