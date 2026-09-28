import 'package:birdnet_live/fork/home/birdygo_logo.dart';
import 'package:birdnet_live/fork/map/place_bird_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;

void main() {
  test('the silhouette is centered, unit-sized and keeps the eye open', () {
    final bounds = birdyGoSilhouette.getBounds();
    expect(bounds.longestSide, closeTo(1, 1e-6));
    expect(bounds.center.dx, closeTo(0, 1e-6));
    expect(bounds.center.dy, closeTo(0, 1e-6));

    // Maps a point of the logo's 512 box to the silhouette's space.
    final logo = Path.combine(
      PathOperation.union,
      BirdyGoLogoPainter.body,
      BirdyGoLogoPainter.tail,
    );
    final full =
        Path.combine(
          PathOperation.union,
          Path.combine(PathOperation.union, logo, BirdyGoLogoPainter.upperBeak),
          BirdyGoLogoPainter.lowerBeak,
        ).getBounds();
    Offset toUnit(Offset p) => (p - full.center) / full.longestSide;

    // Belly, tail and beak are inside; the eye is a hole.
    expect(birdyGoSilhouette.contains(toUnit(const Offset(260, 300))), isTrue);
    expect(birdyGoSilhouette.contains(toUnit(const Offset(430, 200))), isTrue);
    expect(birdyGoSilhouette.contains(toUnit(const Offset(90, 162))), isTrue);
    expect(
      birdyGoSilhouette.contains(toUnit(BirdyGoLogoPainter.eyeCenter)),
      isFalse,
    );
  });

  testWidgets('the layer paints many places inside a map', (tester) async {
    final places = <PlaceBird>[
      for (var i = 0; i < 200; i++)
        (
          point: LatLng(46 + (i % 20) * 0.2, 1 + (i ~/ 20) * 0.3),
          opacity: 0.18 + (i % 8) * 0.08,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(47, 2.4),
            initialZoom: 6,
          ),
          children: [PlaceBirdLayer(places: places, color: Colors.teal)],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(PlaceBirdLayer),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
