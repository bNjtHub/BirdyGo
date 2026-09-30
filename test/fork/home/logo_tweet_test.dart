import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/home/home_widgets.dart';
import 'package:birdnet_live/fork/home/logo_tweet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTweet implements LogoTweetPlayer {
  int plays = 0;
  int prepares = 0;
  int prepareAtFirstPlay = -1;

  @override
  Future<void> prepare() async => prepares++;

  @override
  Future<void> play() async {
    if (plays == 0) prepareAtFirstPlay = prepares;
    plays++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  Future<(_FakeTweet, ProviderContainer)> pump(
    WidgetTester tester, {
    bool reduced = false,
  }) async {
    final tweet = _FakeTweet();
    final container = ProviderContainer(
      overrides: [logoTweetPlayerProvider.overrideWithValue(tweet)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BirdyTheme.light(),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: child!,
              ),
          home: const Scaffold(body: Center(child: HomeLogoRow())),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    return (tweet, container);
  }

  testWidgets('a tap on the logo plays the tweet', (tester) async {
    final (tweet, _) = await pump(tester);
    await tester.tap(find.byType(HomeLogoRow));
    // A double-tap recognizer is also armed (J6f flight): a single tap only
    // fires once the double-tap timeout has passed with no second tap.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(tweet.plays, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the tweet plays with reduced motion too', (tester) async {
    final (tweet, _) = await pump(tester, reduced: true);
    await tester.tap(find.byType(HomeLogoRow));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(tweet.plays, 1);
  });

  testWidgets('silent while a listening runs', (tester) async {
    final (tweet, container) = await pump(tester);
    container.read(liveStateProvider.notifier).state = LiveState.active;
    await tester.tap(find.byType(HomeLogoRow));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 5));
    expect(tweet.plays, 0);
  });

  testWidgets('the tweet is prepared before the first tap', (tester) async {
    final (tweet, _) = await pump(tester);
    expect(tweet.prepares, 1);
    expect(tweet.plays, 0);
    await tester.tap(find.byType(HomeLogoRow));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(tweet.plays, 1);
    // The first tap played what was already prepared: no new loading.
    expect(tweet.prepareAtFirstPlay, 1);
    expect(tweet.prepares, 1);
    await tester.pump(const Duration(seconds: 5));
  });
}
