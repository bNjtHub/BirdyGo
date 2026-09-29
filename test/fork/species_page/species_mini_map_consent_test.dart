import 'package:birdnet_live/fork/map/base_layers.dart';
import 'package:birdnet_live/fork/species_page/species_page_screen.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('species mini map tiles need the online-map consent', () {
    for (final layer in MapBaseLayer.values) {
      test('no tile layer without consent (${layer.name})', () async {
        final container = await _container({kMapBaseLayerPref: layer.name});
        expect(container.read(speciesMiniMapTilesProvider), isNull);
      });
    }

    test('consent is off by default', () async {
      final container = await _container({});
      expect(container.read(speciesMiniMapTilesProvider), isNull);
    });
  });
}
