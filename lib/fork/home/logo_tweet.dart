/// The BirdyGo tweet: a short chirp played when the user taps the home logo
/// (assets/fork/sounds/birdygo_tweet.wav, 1.6 s). Its own small player,
/// never the shared clip player; silent while a listening runs, since the
/// microphone would hear it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/live/live_controller.dart';
import '../../features/live/live_providers.dart';

const String kLogoTweetAsset = 'assets/fork/sounds/birdygo_tweet.wav';

/// Plays the tweet, one at a time.
abstract interface class LogoTweetPlayer {
  /// Loads the sound without playing it, so the first tap starts at once.
  /// Safe to call many times: the source is set only once.
  Future<void> prepare();

  Future<void> play();

  Future<void> dispose();
}

class _JustAudioTweetPlayer implements LogoTweetPlayer {
  AudioPlayer? _player;
  Future<void>? _loading;

  @override
  Future<void> prepare() {
    return _loading ??= () async {
      try {
        final player = _player ??= AudioPlayer();
        await player.setAsset(kLogoTweetAsset);
      } catch (e) {
        _loading = null;
        debugPrint('[LogoTweet] $e');
      }
    }();
  }

  @override
  Future<void> play() async {
    try {
      await prepare();
      final player = _player;
      if (player == null) return;
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      // A chirp never breaks the home screen.
      debugPrint('[LogoTweet] $e');
    }
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    _loading = null;
    await player?.dispose();
  }
}

final logoTweetPlayerProvider = Provider<LogoTweetPlayer>((ref) {
  final player = _JustAudioTweetPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Loads the tweet ahead of the first tap (no sound), unless a listening
/// runs.
void prepareLogoTweet(WidgetRef ref) {
  final live = ref.read(liveStateProvider);
  if (live == LiveState.active || live == LiveState.paused) return;
  ref.read(logoTweetPlayerProvider).prepare();
}

/// Plays the tweet unless a listening is running.
void playLogoTweet(WidgetRef ref) {
  final live = ref.read(liveStateProvider);
  if (live == LiveState.active || live == LiveState.paused) return;
  ref.read(logoTweetPlayerProvider).play();
}
