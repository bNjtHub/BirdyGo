// Launcher icon renderer (J6i): one icon set per bird theme, painted from the
// same painter as the in-app logo.
//
// The test always renders into a temp folder and checks the file list. To
// regenerate the committed PNGs and XML under android/app/src/main/res:
//   RENDER_LAUNCHER_ICONS=1 flutter test test/fork/tool/render_launcher_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdygo_silhouette.dart';
import 'package:birdnet_live/fork/home/birdygo_logo.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Density buckets and their scale (legacy icon 48 dp, adaptive layer 108 dp).
const Map<String, double> _densities = {
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// Bird's longest side as a share of the canvas: adaptive foreground (same as
/// the previous icon, then inset 16 % by the XML), legacy square, legacy round.
const double _adaptiveShare = 0.70;
const double _legacyShare = 0.66;
const double _roundShare = 0.58;

Future<void> _writePng(ui.Picture picture, int size, File file) async {
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
}

void _paintBird(ui.Canvas canvas, BirdyBird bird, double size, double share) {
  final bounds = birdyGoLogoBounds;
  canvas
    ..save()
    ..translate(size / 2, size / 2)
    ..scale(size * share / bounds.longestSide)
    ..translate(-bounds.center.dx, -bounds.center.dy);
  BirdyGoLogoPainter(
    progress: const AlwaysStoppedAnimation<double>(1),
    brand: BirdyBrandColors(bird),
  ).paint(canvas, const ui.Size.square(512));
  canvas.restore();
}

void _paintBackground(ui.Canvas canvas, BirdyBird bird, double size) {
  final tonal = BirdyBrandColors(bird).tonal;
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size, size),
    ui.Paint()
      ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(0, size), [
        tonal,
        const ui.Color(0xFFFFFFFF),
      ]),
  );
}

String adaptiveXml(BirdyBird bird) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/ic_launcher_${bird.name}_background"/>
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_${bird.name}_foreground"
          android:inset="16%" />
  </foreground>
</adaptive-icon>
''';

/// Writes every icon file under [res] (an Android `res` folder) and returns
/// the paths written, relative to [res].
Future<List<String>> renderLauncherIcons(Directory res) async {
  final written = <String>[];
  Future<void> write(
    String rel,
    void Function(ui.Canvas) paint,
    int size,
  ) async {
    final rec = ui.PictureRecorder();
    paint(ui.Canvas(rec));
    await _writePng(rec.endRecording(), size, File('${res.path}/$rel'));
    written.add(rel);
  }

  for (final bird in BirdyBird.values) {
    final n = bird.name;
    for (final MapEntry(key: bucket, value: scale) in _densities.entries) {
      final legacy = (48 * scale).round();
      final layer = (108 * scale).round();
      final l = layer.toDouble();
      final s = legacy.toDouble();

      await write(
        'drawable-$bucket/ic_launcher_${n}_background.png',
        (c) => _paintBackground(c, bird, l),
        layer,
      );
      await write(
        'drawable-$bucket/ic_launcher_${n}_foreground.png',
        (c) => _paintBird(c, bird, l, _adaptiveShare),
        layer,
      );
      await write('mipmap-$bucket/ic_launcher_$n.png', (c) {
        _paintBackground(c, bird, s);
        _paintBird(c, bird, s, _legacyShare);
      }, legacy);
      await write('mipmap-$bucket/ic_launcher_${n}_round.png', (c) {
        c.clipPath(ui.Path()..addOval(ui.Rect.fromLTWH(0, 0, s, s)));
        _paintBackground(c, bird, s);
        _paintBird(c, bird, s, _roundShare);
      }, legacy);
    }
    final xml = 'mipmap-anydpi-v26/ic_launcher_$n.xml';
    File('${res.path}/$xml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(adaptiveXml(bird));
    written.add(xml);
  }
  return written;
}

void main() {
  testWidgets('renders 4 icon sets: adaptive layers, legacy, round, XML', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('birdygo_icons');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final written = (await tester.runAsync(() => renderLauncherIcons(tmp)))!;

    // 4 birds x (5 densities x 4 PNG + 1 XML).
    expect(written.length, 4 * (5 * 4 + 1));
    for (final bird in BirdyBird.values) {
      for (final rel in [
        'mipmap-anydpi-v26/ic_launcher_${bird.name}.xml',
        'mipmap-xxxhdpi/ic_launcher_${bird.name}.png',
        'mipmap-mdpi/ic_launcher_${bird.name}_round.png',
        'drawable-xhdpi/ic_launcher_${bird.name}_background.png',
        'drawable-hdpi/ic_launcher_${bird.name}_foreground.png',
      ]) {
        expect(File('${tmp.path}/$rel').existsSync(), isTrue, reason: rel);
      }
    }
    final head = File(
      '${tmp.path}/drawable-mdpi/ic_launcher_loriot_foreground.png',
    ).readAsBytesSync();
    expect(head.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(
      File(
        '${tmp.path}/mipmap-anydpi-v26/ic_launcher_martin.xml',
      ).readAsStringSync(),
      contains('ic_launcher_martin_foreground'),
    );
  });

  testWidgets(
    'regenerate committed icons (RENDER_LAUNCHER_ICONS=1)',
    (tester) async {
      final res = Directory('android/app/src/main/res');
      final written = (await tester.runAsync(() => renderLauncherIcons(res)))!;
      // ignore: avoid_print
      print('Wrote ${written.length} files under ${res.path}');
    },
    skip: Platform.environment['RENDER_LAUNCHER_ICONS'] != '1',
  );
}
