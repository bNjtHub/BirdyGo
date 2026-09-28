import 'dart:io';

import 'package:birdnet_live/fork/map/base_layers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The shared tile cache opens a folder in the app cache directory.
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('tile_cache');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });

  for (final layer in MapBaseLayer.values) {
    test('${layer.name}: tile errors reach the map when it asks', () {
      void onError(TileImage tile, Object error, StackTrace? stack) {}

      final reported = buildBaseTileLayer(layer, onTileError: onError);
      expect(reported.errorTileCallback, same(onError));
      expect(
        (reported.tileProvider as NetworkTileProvider).silenceExceptions,
        isFalse,
      );

      final silent = buildBaseTileLayer(layer);
      expect(silent.errorTileCallback, isNull);
      expect(
        (silent.tileProvider as NetworkTileProvider).silenceExceptions,
        isTrue,
      );
    });
  }
}
