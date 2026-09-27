/// Sound effects of « Qui chante ? » (J6e, Quiz v2): a jingle on a right
/// answer, a soft note on a wrong one and a fanfare on a good score. They
/// have their own small player, never the shared clip player, and the
/// « Avec son / Sans son » switch of the intro mutes them (never the bird
/// song). Sounds: assets/fork/sounds, made by tools/fork_quiz_sounds.py.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/live/live_controller.dart';
import '../../features/live/live_providers.dart';
import '../../shared/providers/app_providers.dart';

enum QuizSound {
  success('assets/fork/sounds/quiz_success.wav'),
  soft('assets/fork/sounds/quiz_soft.wav'),
  fanfare('assets/fork/sounds/quiz_fanfare.wav');

  const QuizSound(this.asset);

  final String asset;
}

/// Plays one [QuizSound] at a time.
abstract interface class QuizSfxPlayer {
  Future<void> play(QuizSound sound);

  Future<void> dispose();
}

class _JustAudioSfxPlayer implements QuizSfxPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play(QuizSound sound) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setAsset(sound.asset);
      await player.play();
    } catch (e) {
      // A sound effect never breaks the game.
      debugPrint('[QuizSfx] ${sound.name}: $e');
    }
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}

final quizSfxPlayerProvider = Provider<QuizSfxPlayer>((ref) {
  final player = _JustAudioSfxPlayer();
  ref.onDispose(player.dispose);
  return player;
});

const String kQuizSoundPref = 'fork_quiz_sound_on_v1';

/// The « Avec son / Sans son » choice, remembered (on by default).
class QuizSoundSetting extends Notifier<bool> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  bool build() => _prefs.getBool(kQuizSoundPref) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await _prefs.setBool(kQuizSoundPref, on);
  }
}

final quizSoundOnProvider = NotifierProvider<QuizSoundSetting, bool>(
  QuizSoundSetting.new,
);

/// Plays [sound] if the switch is on and no listening is running (the
/// microphone would hear it).
void playQuizSound(WidgetRef ref, QuizSound sound) {
  if (!ref.read(quizSoundOnProvider)) return;
  final live = ref.read(liveStateProvider);
  if (live == LiveState.active || live == LiveState.paused) return;
  ref.read(quizSfxPlayerProvider).play(sound);
}
