/// Images of a « new species » notification (J6h): the species photo as a
/// round large icon plus a big picture, or the BirdyGo silhouette on the
/// species tint when there is no photo.
///
/// Android takes PNG bytes (`ByteArrayAndroidBitmap`). iOS will need a file
/// path instead (DarwinNotificationAttachment), see fork/PLAN.md.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../design/birdygo_silhouette.dart';
import '../design/species_tint.dart';
import 'notification_images_config.dart';

/// PNG images of one notification.
@immutable
class NotificationImages {
  const NotificationImages({required this.largeIcon, this.bigPicture});

  /// Round icon shown next to the text.
  final Uint8List largeIcon;

  /// Photo shown when the notification is expanded; null without a photo.
  final Uint8List? bigPicture;
}

/// Prepares the images of [scientificName]. [photoAsset] is the bundled photo
/// path when the species has one. May return null (no image at all).
typedef NotificationImageLoader =
    Future<NotificationImages?> Function(
      String scientificName,
      String? photoAsset,
    );

/// Real loader: bundled photo, or the silhouette on the species [tint].
Future<NotificationImages?> loadNotificationImages(
  String scientificName,
  String? photoAsset, {
  required SpeciesTint tint,
  AssetBundle? bundle,
}) async {
  if (photoAsset != null && photoAsset != kNotificationPlaceholderAsset) {
    try {
      final data = await (bundle ?? rootBundle).load(photoAsset);
      final photo = await _decode(data.buffer.asUint8List());
      try {
        return NotificationImages(
          largeIcon: await _roundIcon(photo),
          bigPicture: await _scaled(photo, kNotificationBigPictureMaxPx),
        );
      } finally {
        photo.dispose();
      }
    } catch (e) {
      debugPrint('[NotificationImages] photo failed for $scientificName: $e');
    }
  }
  return NotificationImages(largeIcon: await silhouetteIcon(tint));
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _png(ui.Picture picture, int width, int height) async {
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encoding failed');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// [source] scaled down so its longest side is at most
/// [kNotificationBigPictureMaxPx].
Future<Uint8List> _scaled(ui.Image source, int maxPx) {
  final longest = source.width > source.height ? source.width : source.height;
  final scale = longest > maxPx ? maxPx / longest : 1.0;
  final w = (source.width * scale).round();
  final h = (source.height * scale).round();
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    source,
    ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  return _png(recorder.endRecording(), w, h);
}

/// Center square of [source], cropped to a circle.
Future<Uint8List> _roundIcon(ui.Image source) {
  const px = kNotificationLargeIconPx;
  final side =
      (source.width < source.height ? source.width : source.height).toDouble();
  final src = ui.Rect.fromCenter(
    center: ui.Offset(source.width / 2, source.height / 2),
    width: side,
    height: side,
  );
  final dst = ui.Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..clipPath(ui.Path()..addOval(dst));
  canvas.drawImageRect(
    source,
    src,
    dst,
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  return _png(recorder.endRecording(), px, px);
}

/// The BirdyGo silhouette on the species halo, as a round PNG icon.
Future<Uint8List> silhouetteIcon(SpeciesTint tint) {
  const px = kNotificationLargeIconPx;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawCircle(
    ui.Offset(px / 2, px / 2),
    px / 2,
    ui.Paint()..color = tint.halo,
  );
  const inner = px * 0.6;
  canvas
    ..save()
    ..translate((px - inner) / 2, (px - inner) / 2);
  BirdyGoSilhouettePainter(
    tint.deep,
  ).paint(canvas, const ui.Size(inner, inner));
  canvas.restore();
  return _png(recorder.endRecording(), px, px);
}
