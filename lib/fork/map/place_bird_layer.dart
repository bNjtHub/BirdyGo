/// Places of the contact map at small zooms (J6f): each hexagon bin shows
/// as the BirdyGo logo, in its own colors, centered on the bin.
///
/// The logo is recorded once into a [ui.Picture] ([BirdyGoLogoPainter],
/// wings fully drawn) and its silhouette halo once into a [Path]; each paint
/// only offsets and scales them. The number of contacts shows as size, from
/// [kMapPlaceBirdMinSizePx] to [kMapPlaceBirdSizePx], so a quiet place is a
/// small bird, never a faded one.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../design/birdy_tokens.dart';
import '../design/birdygo_silhouette.dart';
import '../home/birdygo_logo.dart';
import 'map_config.dart';

/// One aggregated place: where it is drawn and its weight, the hexagon
/// opacity of its bin ([kMapHexMinOpacity] to [kMapHexMaxOpacity]).
typedef PlaceBird = ({LatLng point, double opacity});

/// Size of a place bird for [opacity].
double placeBirdSize(double opacity) {
  const span = kMapHexMaxOpacity - kMapHexMinOpacity;
  final t = span <= 0 ? 1.0 : ((opacity - kMapHexMinOpacity) / span);
  return ui.lerpDouble(
    kMapPlaceBirdMinSizePx,
    kMapPlaceBirdSizePx,
    t.clamp(0.0, 1.0),
  )!;
}

/// The colored logo, recorded once: the bird's longest side is 1, centered
/// on the origin.
final ui.Picture _logoPicture = _recordLogo();

ui.Picture _recordLogo() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bird = birdyGoLogoBounds;
  final scale = 1 / bird.longestSide;
  // The painter maps its 512 box onto the size it is given.
  const box = Size.square(512);
  canvas
    ..scale(scale)
    ..translate(-bird.center.dx, -bird.center.dy);
  BirdyGoLogoPainter(
    progress: const AlwaysStoppedAnimation<double>(1),
  ).paint(canvas, box);
  return recorder.endRecording();
}

/// Draws [places] as colored BirdyGo logos on a white halo.
class PlaceBirdLayer extends StatelessWidget {
  const PlaceBirdLayer({super.key, required this.places});

  final List<PlaceBird> places;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: CustomPaint(
        size: camera.size,
        painter: _PlaceBirdPainter(camera: camera, places: places),
      ),
    );
  }
}

class _PlaceBirdPainter extends CustomPainter {
  _PlaceBirdPainter({required this.camera, required this.places});

  final MapCamera camera;
  final List<PlaceBird> places;

  static final Paint _halo =
      Paint()
        // White on every base map, whatever the app theme.
        ..color = BirdyColors.light.surface1
        ..style = PaintingStyle.stroke
        ..strokeJoin = ui.StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = (Offset.zero & size).inflate(kMapPlaceBirdSizePx);
    // Small birds first, so a busy place is never hidden under a quiet one.
    final drawn = [
      for (final place in places)
        if (visible.contains(camera.getOffsetFromOrigin(place.point))) place,
    ]..sort((a, b) => a.opacity.compareTo(b.opacity));
    for (final place in drawn) {
      final offset = camera.getOffsetFromOrigin(place.point);
      final side = placeBirdSize(place.opacity);
      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..scale(side)
        ..drawPath(
          birdyGoSilhouette,
          _halo..strokeWidth = 2 * kMapPlaceBirdHaloPx / side,
        )
        ..drawPicture(_logoPicture)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_PlaceBirdPainter old) =>
      old.camera != camera || old.places != places;
}
