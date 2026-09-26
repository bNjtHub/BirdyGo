/// Plays the recordings of the species page through the listening
/// controller's replay: one player for the whole app, and inference skips
/// the replay (plus its tail) if a listening session is running (J2).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/live/live_controller.dart';
import '../../features/live/live_providers.dart';

abstract interface class SpeciesClipPlayer {
  /// Path of the clip playing, or null.
  ValueListenable<String?> get playing;

  Future<void> play(String clipPath);

  Future<void> stop();
}

class _LiveReplayPlayer implements SpeciesClipPlayer {
  _LiveReplayPlayer(this._controller);

  final LiveController _controller;

  @override
  ValueListenable<String?> get playing => _controller.replayingClip;

  @override
  Future<void> play(String clipPath) => _controller.replayClip(clipPath);

  @override
  Future<void> stop() => _controller.stopReplay();
}

final speciesClipPlayerProvider = Provider<SpeciesClipPlayer>(
  (ref) => _LiveReplayPlayer(ref.read(liveControllerProvider)),
);
