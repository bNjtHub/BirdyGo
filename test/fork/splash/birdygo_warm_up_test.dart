import 'dart:async';

import 'package:birdnet_live/fork/splash/birdygo_warm_up.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress is weighted and names the first step still loading', () {
    final progress = BirdyGoLoadProgress();
    addTearDown(progress.dispose);
    expect(progress.value.fraction, 0);
    expect(progress.value.current, BirdyGoLoadStep.start);

    progress.markDone(BirdyGoLoadStep.start);
    progress.markDone(BirdyGoLoadStep.geoModel);
    expect(
      progress.value.fraction,
      (BirdyGoLoadStep.start.weight + BirdyGoLoadStep.geoModel.weight) /
          BirdyGoLoadStep.totalWeight,
    );
    expect(progress.value.current, BirdyGoLoadStep.audioModel);
    expect(progress.value.complete, isFalse);

    progress.markAllDone();
    expect(progress.value.fraction, 1);
    expect(progress.value.current, isNull);
    expect(progress.value.complete, isTrue);
  });

  test('marking a step twice notifies once', () {
    final progress = BirdyGoLoadProgress();
    addTearDown(progress.dispose);
    var notified = 0;
    progress.addListener(() => notified++);
    progress.markDone(BirdyGoLoadStep.species);
    progress.markDone(BirdyGoLoadStep.species);
    expect(notified, 1);
  });

  test('steps run side by side and each is marked when it settles', () async {
    final progress = BirdyGoLoadProgress()..markDone(BirdyGoLoadStep.start);
    addTearDown(progress.dispose);
    final audio = Completer<void>();
    final geo = Completer<void>();
    var started = 0;
    final run = runBirdyGoWarmUp({
      BirdyGoLoadStep.audioModel: () {
        started++;
        return audio.future;
      },
      BirdyGoLoadStep.geoModel: () {
        started++;
        return geo.future;
      },
    }, progress);
    await Future<void>.delayed(Duration.zero);
    expect(started, 2);
    // Steps without a task are done at once.
    expect(progress.value.done, {
      BirdyGoLoadStep.start,
      BirdyGoLoadStep.species,
      BirdyGoLoadStep.observations,
    });

    geo.complete();
    await Future<void>.delayed(Duration.zero);
    expect(progress.value.done, contains(BirdyGoLoadStep.geoModel));
    expect(progress.value.current, BirdyGoLoadStep.audioModel);

    audio.complete();
    await run;
    expect(progress.value.complete, isTrue);
  });

  test('a failed or stuck step still lets loading finish', () async {
    final progress = BirdyGoLoadProgress();
    addTearDown(progress.dispose);
    await runBirdyGoWarmUp(
      {
        BirdyGoLoadStep.audioModel: () async => throw StateError('no model'),
        BirdyGoLoadStep.geoModel: () => Completer<void>().future,
      },
      progress,
      stepTimeout: const Duration(milliseconds: 20),
    );
    expect(progress.value.complete, isTrue);
  });
}
