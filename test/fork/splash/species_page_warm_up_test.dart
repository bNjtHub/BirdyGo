import 'package:birdnet_live/fork/splash/species_page_warm_up.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('steps run in order, a pause before each', () async {
    final order = <String>[];
    var pauses = 0;
    final ran = await runSpeciesPageWarmUp(
      {
        'a': () async => order.add('a'),
        'b': () async => order.add('b'),
        'c': () async => order.add('c'),
      },
      pause: () async => pauses++,
      delay: Duration.zero,
    );
    expect(order, ['a', 'b', 'c']);
    expect(ran, ['a', 'b', 'c']);
    expect(pauses, 3);
  });

  test('a failing step is skipped, the others still run', () async {
    final ran = await runSpeciesPageWarmUp({
      'a': () async => throw StateError('boom'),
      'b': () async {},
    }, delay: Duration.zero);
    expect(ran, ['b']);
  });

  test('stops when the app leaves the foreground', () async {
    var foreground = true;
    final ran = await runSpeciesPageWarmUp({
      'a': () async => foreground = false,
      'b': () async {},
    }, isForeground: () => foreground, delay: Duration.zero);
    expect(ran, ['a']);
  });

  test('warmed providers stay alive and are not recomputed', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var loads = 0;
    final provider = FutureProvider<int>((ref) async => ++loads);
    await runSpeciesPageWarmUp({
      'p': () => container.read(provider.future),
    }, delay: Duration.zero);
    expect(container.exists(provider), isTrue);
    expect(await container.read(provider.future), 1);
    expect(loads, 1);
  });

  test('the real tasks name only keepAlive providers, in cost order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(speciesPageWarmUpTasks(container).keys.toList(), [
      'descriptions',
      'worldRegions',
      'worldRanges',
      'landCells',
      'yearScores',
    ]);
  });
}
