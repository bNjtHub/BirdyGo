import 'dart:ui';

import 'package:birdnet_live/fork/world_map/range_class.dart';
import 'package:birdnet_live/fork/world_map/range_frame.dart';
import 'package:birdnet_live/fork/world_map/world_map_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'world_map_test_data.dart';

void main() {
  test('scene is built once and culled to the frame', () {
    final regions = realRegions();
    final classes = {regions.regions.first.id: RangeClass.resident};
    final frame = frameOf(regions, classes);
    final cache = WorldMapSceneCache();
    const size = Size(360, 240);
    final sw = Stopwatch()..start();
    final scene = cache.get(regions, classes, frame, size);
    final build = sw.elapsedMilliseconds;
    sw.reset();
    final again = cache.get(regions, classes, frame, size);
    expect(identical(scene, again), isTrue);
    // ignore: avoid_print
    print('scene build: $build ms, cached get: ${sw.elapsedMicroseconds} us');
    expect(
      cache.get(regions, classes, kWorldFrame, size),
      isNot(same(scene)),
    );
  });
}
