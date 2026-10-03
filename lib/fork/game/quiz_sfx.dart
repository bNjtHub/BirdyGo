/// Sound effects of « Qui chante ? » (J6e, Quiz v2): a jingle on a right
/// answer, a soft note on a wrong one and a fanfare on a good score. They
/// use the shared short-sound player (never the clip player), and the
/// « Avec son / Sans son » switch of the intro mutes them (never the bird
/// song). Sounds: assets/fork/sounds, made by tools/fork_quiz_sounds.py.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';
import '../sound/birdy_sfx.dart';

enum QuizSound {
  success('assets/fork/sounds/quiz_success.wav'),
  soft('assets/fork/sounds/quiz_soft.wav'),
  fanfare('assets/fork/sounds/quiz_fanfare.wav');

  const QuizSound(this.asset);

  final String asset;
}

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

/// Prepares (silent) the quiz sounds when the switch is on and no listening
/// runs, so the first jingle is not late.
void prepareQuizSounds(WidgetRef ref) {
  if (!ref.read(quizSoundOnProvider)) return;
  prepareSfx(ref, [for (final s in QuizSound.values) s.asset]);
}

/// Plays [sound] if the switch is on and no listening is running (the
/// microphone would hear it).
void playQuizSound(WidgetRef ref, QuizSound sound) {
  if (!ref.read(quizSoundOnProvider)) return;
  playSfx(ref, sound.asset);
}
