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

/// The few audio calls the tweet needs, so a test can fake the engine.
@visibleForTesting
abstract interface class TweetAudio {
  Future<void> setAsset(String asset);

  Future<void> seekToStart();

  Future<void> play();

  Future<void> dispose();
}

class _JustAudio implements TweetAudio {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> setAsset(String asset) => _player.setAsset(asset);

  @override
  Future<void> seekToStart() => _player.seek(Duration.zero);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> dispose() => _player.dispose();
}

/// The real tweet player: one lazily created engine, its source set once.
@visibleForTesting
class JustAudioTweetPlayer implements LogoTweetPlayer {
  JustAudioTweetPlayer({TweetAudio Function()? createAudio})
    : _createAudio = createAudio ?? _JustAudio.new;

  final TweetAudio Function() _createAudio;
  TweetAudio? _audio;
  Future<void>? _loading;

  @override
  Future<void> prepare() => _loading ??= _load();

  Future<void> _load() async {
    // Yield first: the caller stores this future in _loading before any work
    // runs, so a failure below can reset it to null as its very last step
    // (a synchronous throw would otherwise be overwritten by the assignment
    // and block every retry).
    await Future<void>.value();
    try {
      final audio = _audio ??= _createAudio();
      await audio.setAsset(kLogoTweetAsset);
    } catch (e) {
      debugPrint('[LogoTweet] $e');
      _loading = null;
    }
  }

  @override
  Future<void> play() async {
    try {
      await prepare();
      final audio = _audio;
      if (audio == null || _loading == null) return;
      await audio.seekToStart();
      await audio.play();
    } catch (e) {
      // A chirp never breaks the home screen.
      debugPrint('[LogoTweet] $e');
    }
  }

  @override
  Future<void> dispose() async {
    final audio = _audio;
    _audio = null;
    _loading = null;
    await audio?.dispose();
  }
}

final logoTweetPlayerProvider = Provider<LogoTweetPlayer>((ref) {
  final player = JustAudioTweetPlayer();
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
