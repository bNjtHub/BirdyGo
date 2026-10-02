import 'package:birdnet_live/fork/map/base_layers.dart';
import 'package:birdnet_live/fork/map/map_config.dart';
import 'package:birdnet_live/fork/map/map_region.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('emptyMapView', () {
    test('without known position: neutral world view', () {
      final v = emptyMapView(null);
      expect(v.center, const LatLng(kMapWorldCenterLat, kMapWorldCenterLng));
      expect(v.zoom, kMapWorldZoom);
    });

    test('with known position: centered on it', () {
      const p = LatLng(48.85, 2.35);
      final v = emptyMapView(p);
      expect(v.center, p);
      expect(v.zoom, kMapKnownPositionZoom);
    });
  });

  group('IGN visibility', () {
    test('shown for FR region or French UI', () {
      expect(ignLayersAvailable(regionCode: 'FR', languageCode: 'en'), isTrue);
      expect(ignLayersAvailable(regionCode: 'US', languageCode: 'fr'), isTrue);
      expect(ignLayersAvailable(regionCode: 'fr'), isTrue);
    });

    test('hidden otherwise', () {
      expect(ignLayersAvailable(regionCode: 'US', languageCode: 'en'), isFalse);
      expect(ignLayersAvailable(), isFalse);
      expect(availableBaseLayers(regionCode: 'GB', languageCode: 'en'), [
        MapBaseLayer.osm,
      ]);
      expect(availableBaseLayers(regionCode: 'FR'), MapBaseLayer.values);
    });

    test('hidden IGN selection falls back to OSM', () {
      expect(
        effectiveBaseLayer(
          MapBaseLayer.ignPhoto,
          regionCode: 'US',
          languageCode: 'en',
        ),
        MapBaseLayer.osm,
      );
      expect(
        effectiveBaseLayer(MapBaseLayer.ignPlan, languageCode: 'fr'),
        MapBaseLayer.ignPlan,
      );
      expect(effectiveBaseLayer(MapBaseLayer.osm), MapBaseLayer.osm);
    });
  });
}
