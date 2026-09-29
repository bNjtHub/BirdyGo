/// The real loading behind the startup screen: the heavy resources that the
/// home screen and Live need, loaded while the bird sings, so the app opens
/// ready instead of loading behind a finished splash.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../design/birdy_motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/live/live_providers.dart';
import '../data/observation_index_service.dart';
import '../species_sheet/species_sheet.dart';

/// One loading step, in the order the startup screen names them.
enum BirdyGoLoadStep {
  /// Preferences, notifications, launch intents (main.dart).
  start(1),

  /// The BirdNET audio model.
  audioModel(4),

  /// The geo-model (species expected here and now).
  geoModel(2),

  /// Taxonomy, audio labels and species sheets.
  species(2),

  /// The observation index, filled from the saved sessions if needed.
  observations(1);

  const BirdyGoLoadStep(this.weight);

  /// Share of the progress bar.
  final int weight;

  static final int totalWeight = values.fold(0, (sum, s) => sum + s.weight);
}

/// Steps done so far.
@immutable
class BirdyGoLoadState {
  const BirdyGoLoadState([this.done = const {}]);

  final Set<BirdyGoLoadStep> done;

  /// Weighted share of the work done, 0..1.
  double get fraction =>
      done.fold<int>(0, (sum, s) => sum + s.weight) /
      BirdyGoLoadStep.totalWeight;

  bool get complete => done.length == BirdyGoLoadStep.values.length;

  /// The first step still running, null once everything is loaded.
  BirdyGoLoadStep? get current {
    for (final step in BirdyGoLoadStep.values) {
      if (!done.contains(step)) return step;
    }
    return null;
  }
}

/// Progress of the startup loading, shared by BirdyGoStartup and the splash.
class BirdyGoLoadProgress extends ValueNotifier<BirdyGoLoadState> {
  BirdyGoLoadProgress() : super(const BirdyGoLoadState());

  void markDone(BirdyGoLoadStep step) {
    if (value.done.contains(step)) return;
    value = BirdyGoLoadState({...value.done, step});
  }

  void markAllDone() =>
      value = BirdyGoLoadState(BirdyGoLoadStep.values.toSet());
}

/// Runs [tasks] side by side and marks each step done when it settles.
///
/// A failed or overlong step still counts as done: loading here is an
/// optimisation, and the screen that needs the resource reports the error
/// itself. A step without a task is done at once.
///
/// The steps run one after the other, with [pause] between them: part of
/// each load parses on the UI isolate, and piling them up in parallel stalls
/// the splash animation. [pause] lets a frame through (see
/// [birdyGoFramePause]).
Future<void> runBirdyGoWarmUp(
  Map<BirdyGoLoadStep, Future<void> Function()> tasks,
  BirdyGoLoadProgress progress, {
  Duration stepTimeout = const Duration(seconds: 20),
  Future<void> Function()? pause,
}) async {
  final clock = Stopwatch()..start();
  for (final step in BirdyGoLoadStep.values) {
    if (progress.value.done.contains(step)) continue;
    final task = tasks[step];
    if (task != null) {
      await pause?.call();
      try {
        await task().timeout(stepTimeout);
        debugPrint(
          '[BirdyGoWarmUp] ${step.name} ready in '
          '${clock.elapsedMilliseconds} ms',
        );
      } catch (error) {
        debugPrint('[BirdyGoWarmUp] ${step.name} failed: $error');
      }
    }
    progress.markDone(step);
  }
}

/// Waits for the next frame to be drawn, or at most 100 ms (no frame comes
/// while the app is in the background).
Future<void> birdyGoFramePause() => SchedulerBinding.instance.endOfFrame
    .timeout(BirdyMotion.framePauseTimeout, onTimeout: () {});

/// The loading tasks of the app, read from its provider [container]. They
/// are the same futures the home screen warms up, so nothing loads twice.
Map<BirdyGoLoadStep, Future<void> Function()> birdyGoWarmUpTasks(
  ProviderContainer container,
) => {
  // Settles to ready or error, never throws; the same load Live joins.
  BirdyGoLoadStep.audioModel:
      () => container.read(liveControllerProvider).loadModel(),
  BirdyGoLoadStep.geoModel: () => container.read(geoModelProvider.future),
  // One after the other too, a frame apart, for the same reason.
  BirdyGoLoadStep.species: () async {
    await container.read(taxonomyServiceProvider.future);
    await birdyGoFramePause();
    await container.read(audioLabelsSetProvider.future);
    await birdyGoFramePause();
    await container.read(speciesSheetsProvider.future);
  },
  BirdyGoLoadStep.observations: () async {
    final service = container.read(observationIndexServiceProvider);
    await service.ensureReady();
    // The first fill (or a fill after a schema change) runs in the
    // background; the counts on the home screen need it.
    if (!service.isRebuilding) return;
    final done = Completer<void>();
    void check() {
      if (!service.isRebuilding && !done.isCompleted) done.complete();
    }

    service.addListener(check);
    try {
      await done.future;
    } finally {
      service.removeListener(check);
    }
  },
};
