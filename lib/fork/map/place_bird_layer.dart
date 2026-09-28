/// Places of the contact map at small zooms (J6f): each hexagon bin shows
/// as the BirdyGo bird, centered on the bin, instead of a hexagon.
///
/// The silhouette is built once from the logo's paths
/// ([BirdyGoLogoPainter]) and scaled once to the marker size; each paint only
/// offsets it. Places are grouped by opacity level so the whole layer costs
/// a few draw calls, whatever the number of places.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../home/birdygo_logo.dart';
import 'map_config.dart';

/// One aggregated place: where it is drawn and how opaque it is.
typedef PlaceBird = ({LatLng point, double opacity});

/// The BirdyGo bird as one filled shape: tail, body and beak joined, the
/// eye cut out. Centered on the origin, its longest side is 1.
final Path birdyGoSilhouette = _buildSilhouette();

Path _buildSilhouette() {
  var shape = Path.combine(
    PathOperation.union,
    BirdyGoLogoPainter.body,
    BirdyGoLogoPainter.tail,
  );
  shape = Path.combine(
    PathOperation.union,
    shape,
    BirdyGoLogoPainter.upperBeak,
  );
  shape = Path.combine(
    PathOperation.union,
    shape,
    BirdyGoLogoPainter.lowerBeak,
  );
  shape = Path.combine(
    PathOperation.difference,
    shape,
    Path()..addOval(
      Rect.fromCircle(
        center: BirdyGoLogoPainter.eyeCenter,
        radius: BirdyGoLogoPainter.eyeRadius,
      ),
    ),
  );
  final bounds = shape.getBounds();
  final scale = 1 / bounds.longestSide;
  final matrix =
      Matrix4.identity()
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1);
  return shape.transform(matrix.storage);
}

/// The silhouette at [kMapPlaceBirdSizePx], built on first use.
final Path _markerPath = birdyGoSilhouette.transform(
  (Matrix4.identity()
        ..scaleByDouble(kMapPlaceBirdSizePx, kMapPlaceBirdSizePx, 1, 1))
      .storage,
);

/// Draws [places] as birds of [color]: the fill carries each place's
/// opacity, the outline stays opaque so faint places remain visible.
class PlaceBirdLayer extends StatelessWidget {
  const PlaceBirdLayer({super.key, required this.places, required this.color});

  final List<PlaceBird> places;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: CustomPaint(
        size: camera.size,
        painter: _PlaceBirdPainter(
          camera: camera,
          places: places,
          color: color,
        ),
      ),
    );
  }
}

class _PlaceBirdPainter extends CustomPainter {
  _PlaceBirdPainter({
    required this.camera,
    required this.places,
    required this.color,
  });

  final MapCamera camera;
  final List<PlaceBird> places;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = (Offset.zero & size).inflate(kMapPlaceBirdSizePx);
    final byOpacity = <double, Path>{};
    final outline = Path();
    for (final place in places) {
      final offset = camera.getOffsetFromOrigin(place.point);
      if (!visible.contains(offset)) continue;
      (byOpacity[place.opacity] ??= Path()).addPath(_markerPath, offset);
      outline.addPath(_markerPath, offset);
    }
    for (final MapEntry(key: opacity, value: path) in byOpacity.entries) {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = kMapPlaceBirdStrokePx
        ..strokeJoin = ui.StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PlaceBirdPainter old) =>
      old.camera != camera || old.places != places || old.color != color;
}
