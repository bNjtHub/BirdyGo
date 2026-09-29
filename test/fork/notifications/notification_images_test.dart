import 'dart:async';
import 'dart:typed_data';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/species_accents.dart';
import 'package:birdnet_live/fork/notifications/notification_images.dart';
import 'package:birdnet_live/fork/notifications/notifications_gateway.dart';
import 'package:birdnet_live/fork/notifications/species_notifier.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements NotificationsGateway {
  final images = <NotificationImages?>[];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
    NotificationImages? images,
  }) async => this.images.add(images);

  @override
  Future<void> showSummary({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
  }) async {}

  @override
  Future<void> cancel(Iterable<int> ids) async {}
}

const _strings = SpeciesNotifierStrings(
  channelName: 'c',
  channelDescription: 'd',
  body: _body,
  summaryTitle: _summary,
);
String _body(DateTime at, ReliabilityLevel level, bool rare) => 'b';
String _summary(int n) => '$n';

DetectionRecord _det(String name) => DetectionRecord(
  scientificName: name,
  commonName: name,
  confidence: 0.9,
  timestamp: DateTime(2026, 9, 29, 7, 38),
);

final _photo = NotificationImages(
  largeIcon: Uint8List.fromList([1]),
  bigPicture: Uint8List.fromList([2]),
);

void main() {
  Future<_Gateway> run(NotificationImageLoader loader) async {
    final gateway = _Gateway();
    final notifier = SpeciesNotifier(
      gateway: gateway,
      isBackground: () => true,
      imageLoader: loader,
      imageTimeout: const Duration(milliseconds: 50),
    );
    await notifier.onDetections(
      sessionId: 's',
      detections: [_det('Parus major')],
      enabled: true,
      presenceOf: (_) => null,
      nameOf: (d) => d.commonName,
      strings: _strings,
      photoAssetOf: (name) => 'assets/species_images/$name.webp',
    );
    return gateway;
  }

  test('photo images reach the gateway, with the bundled photo path', () async {
    String? asked;
    final g = await run((name, asset) async {
      asked = asset;
      return _photo;
    });
    expect(g.images.single, same(_photo));
    expect(asked, 'assets/species_images/Parus major.webp');
  });

  test('a silhouette-only result is passed as is (no big picture)', () async {
    final icon = NotificationImages(largeIcon: Uint8List.fromList([9]));
    final g = await run((_, _) async => icon);
    expect(g.images.single!.bigPicture, isNull);
    expect(g.images.single!.largeIcon, [9]);
  });

  test('a slow loader falls back to a plain notification', () async {
    final never = Completer<NotificationImages?>();
    final g = await run((_, _) => never.future);
    expect(g.images, [null]);
  });

  test('a failing loader falls back to a plain notification', () async {
    final g = await run((_, _) async => throw StateError('boom'));
    expect(g.images, [null]);
  });

  test('speciesNotificationDetails wires large icon and big picture', () {
    final d =
        speciesNotificationDetails(
          groupKey: 'g',
          channelName: 'c',
          channelDescription: 'd',
          summary: false,
          images: _photo,
        ).android!;
    expect(d.largeIcon, isA<ByteArrayAndroidBitmap>());
    final style = d.styleInformation as BigPictureStyleInformation;
    expect(style.hideExpandedLargeIcon, isTrue);
    expect(style.bigPicture.data, [2]);
  });

  test('speciesNotificationDetails without images is plain', () {
    final d =
        speciesNotificationDetails(
          groupKey: 'g',
          channelName: 'c',
          channelDescription: 'd',
          summary: false,
        ).android!;
    expect(d.largeIcon, isNull);
    expect(d.styleInformation, isNull);
  });

  testWidgets('silhouette fallback renders a PNG for a missing photo', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final images = await loadNotificationImages(
        'Parus major',
        'assets/images/dummy_species.png',
        tint: SpeciesAccents.tintOf('Parus major'),
      );
      expect(images!.bigPicture, isNull);
      // PNG signature.
      expect(images.largeIcon.sublist(1, 4), [0x50, 0x4E, 0x47]);
    });
  });
}
