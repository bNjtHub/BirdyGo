import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/fork/game/quiz_sfx.dart';
import 'package:birdnet_live/fork/home/logo_tweet.dart';
import 'package:birdnet_live/fork/sound/birdy_sfx.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_birdy_sfx.dart';

class _Engine implements SfxEngine {
  _Engine({this.failWarmUp = false, this.failSetAsset = false});

  final bool failWarmUp;
  bool failSetAsset;
  final calls = <String>[];

  @override
  Future<void> setAsset(String asset) async {
    calls.add('setAsset');
    if (failSetAsset) throw StateError('no source');
  }

  @override
  Future<void> setVolume(double volume) async => calls.add('volume $volume');

  @override
  void start() => calls.add('start');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekToStart() async => calls.add('seek0');

  @override
  Future<void> waitPlaying(Duration timeout, Duration hold) async {
    calls.add('wait');
    if (failWarmUp) throw StateError('warm-up failed');
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  const asset = 'a.wav';

  test('warm-up: silent play, then pause, seek 0, volume back to 1', () async {
    final engine = _Engine();
    final sfx = EngineBirdySfx(createEngine: () => engine);
    await sfx.prepare([asset]);
    expect(engine.calls, [
      'setAsset',
      'volume 0.0',
      'start',
      'wait',
      'pause',
      'seek0',
      'volume 1.0',
    ]);
  });

  test('play after prepare does not set the asset again', () async {
    final engine = _Engine();
    final sfx = EngineBirdySfx(createEngine: () => engine);
    await sfx.prepare([asset]);
    engine.calls.clear();
    await sfx.play(asset);
    expect(engine.calls, ['seek0', 'start']);
    await sfx.prepare([asset]);
    expect(engine.calls, ['seek0', 'start']);
  });

  test('play without prepare prepares first', () async {
    final engine = _Engine();
    final sfx = EngineBirdySfx(createEngine: () => engine);
    await sfx.play(asset);
    expect(engine.calls.first, 'setAsset');
    expect(engine.calls.last, 'start');
  });

  test(
    'a failing warm-up restores the volume and does not block play',
    () async {
      final engine = _Engine(failWarmUp: true);
      final sfx = EngineBirdySfx(createEngine: () => engine);
      await sfx.prepare([asset]);
      expect(engine.calls.last, 'volume 1.0');
      engine.calls.clear();
      await sfx.play(asset);
      expect(engine.calls, ['seek0', 'start']);
    },
  );

  test(
    'a failing setAsset or constructor is retried on next prepare',
    () async {
      final engine = _Engine(failSetAsset: true);
      var created = 0;
      final sfx = EngineBirdySfx(
        createEngine: () {
          created++;
          if (created == 1) throw StateError('no engine yet');
          return engine;
        },
      );
      await sfx.prepare([asset]);
      expect(created, 1);
      await sfx.prepare([asset]);
      expect(created, 2);
      expect(engine.calls, ['setAsset']);
      engine.failSetAsset = false;
      await sfx.prepare([asset]);
      expect(engine.calls.where((c) => c == 'setAsset').length, 2);
      expect(engine.calls.last, 'volume 1.0');
    },
  );

  group('listening and mute rules', () {
    Future<(FakeBirdySfx, ProviderContainer, WidgetRef)> setUp(
      WidgetTester tester, {
      bool soundOn = true,
    }) async {
      SharedPreferences.setMockInitialValues({kQuizSoundPref: soundOn});
      final prefs = await SharedPreferences.getInstance();
      final sfx = FakeBirdySfx();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          birdySfxProvider.overrideWithValue(sfx),
        ],
      );
      addTearDown(container.dispose);
      late WidgetRef captured;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      return (sfx, container, captured);
    }

    testWidgets('tweet: nothing while a listening runs', (tester) async {
      final (sfx, container, ref) = await setUp(tester);
      container.read(liveStateProvider.notifier).state = LiveState.active;
      prepareLogoTweet(ref);
      playLogoTweet(ref);
      container.read(liveStateProvider.notifier).state = LiveState.paused;
      prepareLogoTweet(ref);
      playLogoTweet(ref);
      expect(sfx.prepared, isEmpty);
      expect(sfx.played, isEmpty);
      container.read(liveStateProvider.notifier).state = LiveState.idle;
      prepareLogoTweet(ref);
      playLogoTweet(ref);
      expect(sfx.prepared, [kLogoTweetAsset]);
      expect(sfx.played, [kLogoTweetAsset]);
    });

    testWidgets('quiz sounds: nothing while a listening runs', (tester) async {
      final (sfx, container, ref) = await setUp(tester);
      container.read(liveStateProvider.notifier).state = LiveState.active;
      prepareQuizSounds(ref);
      playQuizSound(ref, QuizSound.success);
      expect(sfx.prepared, isEmpty);
      expect(sfx.played, isEmpty);
    });

    testWidgets('quiz « Sans son » mutes prepare and play', (tester) async {
      final (sfx, _, ref) = await setUp(tester, soundOn: false);
      prepareQuizSounds(ref);
      playQuizSound(ref, QuizSound.fanfare);
      expect(sfx.prepared, isEmpty);
      expect(sfx.played, isEmpty);
    });

    testWidgets('quiz sound on: prepares all jingles, plays the asked one', (
      tester,
    ) async {
      final (sfx, _, ref) = await setUp(tester);
      prepareQuizSounds(ref);
      playQuizSound(ref, QuizSound.soft);
      expect(sfx.prepared, [for (final s in QuizSound.values) s.asset]);
      expect(sfx.played, [QuizSound.soft.asset]);
    });
  });
}
