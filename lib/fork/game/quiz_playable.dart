/// Whether « Qui chante ? » can be played now: the same threshold as the
/// quiz itself (enough verified species with a playable clip).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/observation_index_service.dart';
import 'fine_ear.dart';
import 'game_loader.dart';

final quizPlayableProvider = FutureProvider<bool>((ref) async {
  final progress = await ref.watch(gameProgressProvider.future);
  final index = await ref.read(observationIndexServiceProvider).ensureReady();
  final clips = await loadQuizClips(index, progress.facts.verifiedBirds);
  return hasQuizRound(clips);
});
