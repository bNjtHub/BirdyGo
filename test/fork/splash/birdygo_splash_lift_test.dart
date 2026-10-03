import 'dart:ui' as ui;

import 'package:birdnet_live/fork/splash/birdygo_splash.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:birdnet_live/fork/splash/birdygo_warm_up.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _pixels(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(114, 90));
  final image = await recorder.endRecording().toImage(114, 90);
  return (await image.toByteData())!.buffer.asUint8List().toList();
}

Widget _app({bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BirdyGoSplash(progress: BirdyGoLoadProgress()),
  ),
);

BirdyGoSingingPainter _painter(WidgetTester tester) =>
    tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((c) => c.painter)
            .whereType<BirdyGoSingingPainter>()
            .single;

void main() {
  testWidgets('the splash bird lifts its head mid-song like the home logo', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1750));
    final painter = _painter(tester);
    expect(painter.still, isFalse);
    expect(painter.loop, isTrue);
    final clock = painter.clock.value;
    expect(clock, greaterThan(BirdyGoSingingPainter.firstPhrase));
    // Same clock on the splash's painter and on a bare one: same pixels.
    await tester.runAsync(() async {
      final onSplash = await _pixels(painter);
      final bare = await _pixels(
        BirdyGoSingingPainter(clock: ValueNotifier(clock)),
      );
      expect(listEquals(onSplash, bare), isTrue);
      final rest = await _pixels(
        BirdyGoSingingPainter(clock: ValueNotifier(clock), still: true),
      );
      expect(listEquals(onSplash, rest), isFalse);
    });
  });

  testWidgets('reduced motion: the splash bird stays settled, no lift', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reduced: true));
    await tester.pump(const Duration(milliseconds: 1750));
    final painter = _painter(tester);
    expect(painter.still, isTrue);
    await tester.runAsync(() async {
      final a = await _pixels(painter);
      final b = await _pixels(
        BirdyGoSingingPainter(clock: ValueNotifier(0), still: true),
      );
      expect(listEquals(a, b), isTrue);
    });
  });
}
