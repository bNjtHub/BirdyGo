import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Size;

import 'package:birdnet_live/fork/design/birdy_tokens.dart';

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
    expect(cache.has(regions, classes, frame, size), isFalse);
    final scene = cache.get(regions, classes, frame, size);
    expect(cache.has(regions, classes, frame, size), isTrue);
    expect(identical(scene, cache.get(regions, classes, frame, size)), isTrue);
    expect(
      cache.get(regions, classes, kWorldFrame, size),
      isNot(same(scene)),
    );
  });

  test('a widespread species (every region resident) builds its scene', () {
    final regions = realRegions();
    final classes = {for (final r in regions.regions) r.id: RangeClass.resident};
    final frame = frameOf(regions, classes);
    final cache = WorldMapSceneCache();
    const size = Size(360, 240);
    final sw = Stopwatch()..start();
    final scene = cache.get(regions, classes, frame, size);
    final build = sw.elapsedMilliseconds;
    sw.reset();
    cache.get(regions, classes, frame, size);
    // ignore: avoid_print
    print(
      'wide scene (${regions.regions.length} regions): build $build ms, '
      'cached get ${sw.elapsedMicroseconds} us',
    );
    expect(scene.byClass[RangeClass.resident], isNotNull);
  });

  testWidgets('the painter draws the static layer from a cached image', (
    tester,
  ) async {
    final regions = realRegions();
    final classes = {regions.regions.first.id: RangeClass.resident};
    final frame = frameOf(regions, classes);
    const size = Size(360, 240);
    final colors = WorldMapColors.of(BirdyColors.light);
    final image = (await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(
        const ui.Rect.fromLTWH(0, 0, 8, 8),
        ui.Paint(),
      );
      return rec.endRecording().toImage(8, 8);
    }))!;
    final cache = WorldMapSceneCache();
    final canvas = _RecordingCanvas();
    WorldMapPainter(
      regions: regions,
      classes: classes,
      frame: frame,
      colors: colors,
      staticImage: image,
      cache: cache,
    ).paint(canvas, size);
    expect(canvas.calls, contains('drawImageRect'));
    expect(canvas.calls, isNot(contains('drawPath')));
    expect(cache.has(regions, classes, frame, size), isFalse);

    final vector = _RecordingCanvas();
    WorldMapPainter(
      regions: regions,
      classes: classes,
      frame: frame,
      colors: colors,
      cache: cache,
    ).paint(vector, size);
    expect(vector.calls, contains('drawPath'));
    expect(vector.calls, isNot(contains('drawImageRect')));
    image.dispose();
  });
}

/// Records the names of the canvas calls.
class _RecordingCanvas implements Canvas {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString().replaceAll(RegExp(r'Symbol\("|"\)'), ''));
    return null;
  }
}
