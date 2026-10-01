/// « Qui chante ? » (J6e, SPEC.md 7.3, badge Oreille fine): the player hears
/// one of their own recordings of a verified bird and picks its name among
/// [GameConfig.quizChoices]. Only the right answers are stored (a counter);
/// the questions are drawn from the index each round.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/live/live_session.dart';
import '../../shared/providers/app_providers.dart';
import '../data/observation_index.dart';
import '../reliability/reliability_config.dart';
import 'game_config.dart';

const String kFineEarCorrectPref = 'fork_game_fine_ear_correct_v1';

/// Right answers, all rounds together.
class FineEarStore {
  FineEarStore(this._prefs);

  final SharedPreferences _prefs;

  int correct() => _prefs.getInt(kFineEarCorrectPref) ?? 0;

  Future<void> addCorrect() =>
      _prefs.setInt(kFineEarCorrectPref, correct() + 1);
}

final fineEarStoreProvider = Provider<FineEarStore>(
  (ref) => FineEarStore(ref.watch(sharedPreferencesProvider)),
);

/// One question: the clip to hear and the names offered, the right one
/// among them.
class QuizQuestion {
  const QuizQuestion({required this.answer, required this.choices});

  /// The detection whose clip is played.
  final IndexedDetection answer;

  /// Scientific and common names offered, [answer]'s included.
  final List<({String scientificName, String commonName})> choices;
}

/// The clip each species is asked with: a detection that counts for the
/// game (confirmed, or unreviewed with a « Sûr » score), never a rejected
/// one, whose file still exists; confirmed first, then the best score.
/// [clips] are a species' detections with a clip.
IndexedDetection? quizClip(
  List<IndexedDetection> clips, {
  bool Function(String path)? fileExists,
}) {
  final exists = fileExists ?? (path) => File(path).existsSync();
  final usable = [
    for (final d in clips)
      if (d.clipPath != null &&
          d.isHeard &&
          (d.reviewStatus == ReviewStatus.confirmed ||
              (d.reviewStatus == ReviewStatus.unreviewed &&
                  d.confidence >= ReliabilityConfig.sureMinScore)))
        d,
  ]..sort((a, b) {
    final confirmed = (b.reviewStatus == ReviewStatus.confirmed ? 1 : 0)
        .compareTo(a.reviewStatus == ReviewStatus.confirmed ? 1 : 0);
    return confirmed != 0 ? confirmed : b.confidence.compareTo(a.confidence);
  });
  for (final d in usable) {
    if (exists(d.clipPath!)) return d;
  }
  return null;
}

/// Whether [clips] (one detection per species) are enough for a round.
bool hasQuizRound(Map<String, IndexedDetection> clips) =>
    clips.length >= GameConfig.quizChoices;

/// A round drawn at random from [clips] (one detection per species): up to
/// [GameConfig.quizQuestions] questions, each species asked once, the other
/// choices taken from the other species. Empty below
/// [GameConfig.quizChoices] species.
List<QuizQuestion> drawQuiz(
  Map<String, IndexedDetection> clips,
  Random random,
) {
  if (!hasQuizRound(clips)) return const [];
  final species = clips.keys.toList()..shuffle(random);
  return [
    for (final name in species.take(GameConfig.quizQuestions))
      QuizQuestion(
        answer: clips[name]!,
        choices: [
          for (final other in ([
            name,
            ...(species.where((s) => s != name).toList()..shuffle(random)).take(
              GameConfig.quizChoices - 1,
            ),
          ]..shuffle(random)))
            (scientificName: other, commonName: clips[other]!.commonName),
        ],
      ),
  ];
}

/// One playable clip per species of [verified], read from [index].
Future<Map<String, IndexedDetection>> loadQuizClips(
  ObservationIndex index,
  Set<String> verified, {
  bool Function(String path)? fileExists,
}) async {
  // Queries are queued together rather than one round trip per species;
  // the result keeps the order of [verified].
  final names = verified.toList();
  final clipLists = await Future.wait([
    for (final name in names) index.clipsForSpecies(name),
  ]);
  return {
    for (var i = 0; i < names.length; i++)
      if (quizClip(clipLists[i], fileExists: fileExists) case final clip?)
        names[i]: clip,
  };
}

/// Stars (0 to 3) of a round with [right] answers out of [total]: one per
/// share of [GameConfig.quizStarShares] reached.
int quizStars(int right, int total) {
  if (total <= 0) return 0;
  final share = right / total;
  return GameConfig.quizStarShares.where((s) => share >= s).length;
}

/// Right answers in a row at the end of [results] (the streak pill).
int quizStreak(List<bool> results) {
  var count = 0;
  for (final right in results.reversed) {
    if (!right) break;
    count++;
  }
  return count;
}
