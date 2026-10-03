/// The one player of BirdyGo's short sounds (home logo tweet, quiz jingles).
///
/// One just_audio engine per asset, never the shared clip player. [prepare]
/// sets the source AND wakes Android's output path with a silent play/pause,
/// so the first audible [play] starts at once (otherwise the first sound is
/// late on HyperOS: renderer, AudioTrack and audio focus are created then).
/// Nothing is ever played while a listening runs, the microphone would hear
/// it: see [prepareSfx] and [playSfx].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/live/live_controller.dart';
import '../../features/live/live_providers.dart';

/// How long the silent warm-up waits for the player to report playing.
const Duration kSfxWarmUpTimeout = Duration(milliseconds: 600);

/// Extra silent play time once playing, so the audio path is really open.
const Duration kSfxWarmUpHold = Duration(milliseconds: 100);

/// Prepares and plays short sounds, one engine per asset.
abstract interface class BirdySfx {
  /// Loads [assets] and warms the output path, silently. Safe to call many
  /// times: a prepared asset is left alone, a failed one is retried.
  Future<void> prepare(Iterable<String> assets);

  /// Plays [asset] from the start, preparing it first if needed.
  Future<void> play(String asset);

  Future<void> dispose();
}

/// The few audio calls a sound needs, so a test can fake the engine.
@visibleForTesting
abstract interface class SfxEngine {
  Future<void> setAsset(String asset);

  Future<void> setVolume(double volume);

  /// Starts playback. Must not wait for the end of the sound.
  void start();

  Future<void> pause();

  Future<void> seekToStart();

  /// Returns once the engine reports playing (bounded by [timeout]) and
  /// [hold] has passed.
  Future<void> waitPlaying(Duration timeout, Duration hold);

  Future<void> dispose();
}

class _JustAudioEngine implements SfxEngine {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> setAsset(String asset) => _player.setAsset(asset);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  void start() => unawaited(
    _player.play().catchError((Object e) {
      debugPrint('[BirdySfx] play: $e');
    }),
  );

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekToStart() => _player.seek(Duration.zero);

  @override
  Future<void> waitPlaying(Duration timeout, Duration hold) async {
    try {
      await _player.playerStateStream
          .firstWhere(
            (s) => s.playing && s.processingState == ProcessingState.ready,
          )
          .timeout(timeout);
    } on TimeoutException {
      // Bounded: go on, the warm-up is best effort.
    }
    await Future<void>.delayed(hold);
  }

  @override
  Future<void> dispose() => _player.dispose();
}

class _Slot {
  _Slot(this.engine);

  final SfxEngine engine;

  /// Non-null once loading started or succeeded; reset to null on failure so
  /// the next prepare retries.
  Future<void>? loading;
}

/// The real player: a small map asset -> engine.
@visibleForTesting
class EngineBirdySfx implements BirdySfx {
  EngineBirdySfx({SfxEngine Function()? createEngine})
    : _createEngine = createEngine ?? _JustAudioEngine.new;

  final SfxEngine Function() _createEngine;
  final Map<String, _Slot> _slots = {};

  @override
  Future<void> prepare(Iterable<String> assets) =>
      Future.wait(assets.map(_prepareOne));

  Future<void> _prepareOne(String asset) {
    try {
      final slot = _slots[asset] ??= _Slot(_createEngine());
      return slot.loading ??= _load(asset, slot);
    } catch (e) {
      // A throwing constructor leaves no slot behind: retried next time.
      debugPrint('[BirdySfx] $asset: $e');
      return Future<void>.value();
    }
  }

  Future<void> _load(String asset, _Slot slot) async {
    // Yield first: the caller stores this future in `loading` before any
    // work runs, so a failure below can reset it to null as its last step.
    await Future<void>.value();
    try {
      await slot.engine.setAsset(asset);
    } catch (e) {
      debugPrint('[BirdySfx] $asset: $e');
      slot.loading = null;
      return;
    }
    await _warmUp(slot.engine);
  }

  /// Silent play/pause. Never throws; always leaves volume 1 at position 0.
  Future<void> _warmUp(SfxEngine engine) async {
    try {
      await engine.setVolume(0);
      engine.start();
      await engine.waitPlaying(kSfxWarmUpTimeout, kSfxWarmUpHold);
      await engine.pause();
      await engine.seekToStart();
    } catch (e) {
      debugPrint('[BirdySfx] warm-up: $e');
      try {
        await engine.pause();
        await engine.seekToStart();
      } catch (_) {}
    } finally {
      try {
        await engine.setVolume(1);
      } catch (e) {
        debugPrint('[BirdySfx] volume: $e');
      }
    }
  }

  @override
  Future<void> play(String asset) async {
    try {
      await prepare([asset]);
      final slot = _slots[asset];
      if (slot == null || slot.loading == null) return;
      await slot.engine.seekToStart();
      slot.engine.start();
    } catch (e) {
      // A sound never breaks the screen.
      debugPrint('[BirdySfx] $asset: $e');
    }
  }

  @override
  Future<void> dispose() async {
    final slots = _slots.values.toList();
    _slots.clear();
    for (final slot in slots) {
      try {
        await slot.engine.dispose();
      } catch (_) {}
    }
  }
}

final birdySfxProvider = Provider<BirdySfx>((ref) {
  final sfx = EngineBirdySfx();
  ref.onDispose(sfx.dispose);
  return sfx;
});

bool _listening(WidgetRef ref) {
  final live = ref.read(liveStateProvider);
  return live == LiveState.active || live == LiveState.paused;
}

/// Prepares [assets] ahead of time (silent), unless a listening runs.
void prepareSfx(WidgetRef ref, Iterable<String> assets) {
  if (_listening(ref)) return;
  unawaited(ref.read(birdySfxProvider).prepare(assets));
}

/// Plays [asset] unless a listening runs.
void playSfx(WidgetRef ref, String asset) {
  if (_listening(ref)) return;
  unawaited(ref.read(birdySfxProvider).play(asset));
}
