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
  Future<void> play();

  Future<void> dispose();
}

class _JustAudioTweetPlayer implements LogoTweetPlayer {
  AudioPlayer? _player;
  bool _loaded = false;

  @override
  Future<void> play() async {
    try {
      final player = _player ??= AudioPlayer();
      if (!_loaded) {
        await player.setAsset(kLogoTweetAsset);
        _loaded = true;
      }
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
    _loaded = false;
    await player?.dispose();
  }
}

final logoTweetPlayerProvider = Provider<LogoTweetPlayer>((ref) {
  final player = _JustAudioTweetPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Plays the tweet unless a listening is running.
void playLogoTweet(WidgetRef ref) {
  final live = ref.read(liveStateProvider);
  if (live == LiveState.active || live == LiveState.paused) return;
  ref.read(logoTweetPlayerProvider).play();
}
