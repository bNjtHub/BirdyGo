import 'dart:math' as math;

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/map/base_layers.dart';
import 'package:birdnet_live/fork/map/contact_map_data.dart';
import 'package:birdnet_live/fork/map/hex_grid.dart';
import 'package:birdnet_live/fork/map/map_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

var _n = 0;

IndexedDetection _det(
  String species,
  double? lat,
  double? lon, {
  double confidence = 0.8,
  String? clip,
  ReviewStatus status = ReviewStatus.unreviewed,
}) => IndexedDetection(
  key: 'k${_n++}',
  sessionId: 's',
  position: _n,
  scientificName: species,
  commonName: species,
  start: DateTime.utc(2026, 9, 20, 5, _n % 60),
  end: null,
  confidence: confidence,
  reviewStatus: status,
  latitude: lat,
  longitude: lon,
  clipPath: clip,
);

void main() {
  const robin = 'Erithacus rubecula';
  const tit = 'Parus major';

  // Center of the garden's spot, so that the few meters between contacts
  // never cross a spot border.
  final spotGrid = HexGrid(zoom: kMapSpotZoom, radiusPx: kMapSpotRadiusPx);
  final c = spotGrid.center(spotGrid.keyOf(const LatLng(47.2101, -1.5502)));
  final lat = c.latitude;
  final lon = c.longitude;

  List<IndexedDetection> garden() => [
    _det(robin, lat, lon, confidence: 0.9, clip: 'a.flac'),
    _det(robin, lat + 2e-5, lon - 2e-5, confidence: 0.95, clip: 'b.flac'),
    _det(robin, lat - 2e-5, lon + 2e-5, confidence: 0.99),
    _det(tit, lat + 2e-5, lon, status: ReviewStatus.confirmed),
    // The wood, 1 km north.
    _det(tit, lat + 0.01, lon),
    // No position: left out.
    _det(robin, null, null),
  ];

  test('keeps positioned contacts only', () {
    final data = ContactMapData(garden());
    expect(data.points, hasLength(5));
    expect(data.isEmpty, isFalse);
    expect(ContactMapData([_det(robin, null, null)]).isEmpty, isTrue);
  });

  test('hexagon bins hold every contact once, busiest cell counted', () {
    final data = ContactMapData(garden());
    final far = data.hexBins(9);
    expect(far.cells.values.fold<int>(0, (s, c) => s + c.length), 5);
    expect(far.cells, hasLength(1));
    expect(far.maxCount, 5);
    final near = data.hexBins(15);
    expect(near.cells.length, greaterThan(1));
    expect(near.maxCount, 4);
    expect(identical(data.hexBins(9), far), isTrue, reason: 'cached');
  });

  test('one marker per species per spot, with count, clip and review', () {
    final data = ContactMapData(garden());
    expect(data.spots, hasLength(3));
    final gardenRobin = data.spots.first;
    expect(gardenRobin.scientificName, robin);
    expect(gardenRobin.count, 3);
    expect(gardenRobin.hasClip, isTrue);
    expect(gardenRobin.maxConfidence, 0.99);
    expect(gardenRobin.confirmed, isFalse);
    final gardenTit = data.spots.firstWhere(
      (s) => s.scientificName == tit && s.spot == gardenRobin.spot,
    );
    expect(gardenTit.confirmed, isTrue);
    expect(gardenTit.hasClip, isFalse);
    expect(data.indicesAtSpot(gardenRobin.spot), hasLength(4));
  });

  test('species of an area: most contacts first, best clip kept', () {
    final data = ContactMapData(garden());
    final species = data.speciesIn(List.generate(5, (i) => i));
    expect(species.map((s) => s.scientificName), [robin, tit]);
    expect(species.first.contacts, 3);
    // Best-scored contact that has a clip, not the best overall.
    expect(species.first.bestClip?.clipPath, 'b.flac');
    expect(species.last.bestClip, isNull);
  });

  test('hexagon opacity grows with contacts, within its bounds', () {
    expect(hexOpacity(1, 1), kMapHexMaxOpacity);
    final low = hexOpacity(1, 400);
    final mid = hexOpacity(20, 400);
    final high = hexOpacity(400, 400);
    expect(low, greaterThan(kMapHexMinOpacity));
    expect(low, lessThan(mid));
    expect(mid, lessThan(high));
    expect(high, closeTo(kMapHexMaxOpacity, 1e-9));
  });

  test('10 000 contacts bin and group quickly', () {
    final random = math.Random(7);
    final species = List.generate(60, (i) => 'Species $i');
    final points = [
      for (var i = 0; i < 10000; i++)
        _det(
          species[random.nextInt(species.length)],
          46 + random.nextDouble() * 2,
          -2 + random.nextDouble() * 3,
          clip: i.isEven ? 'c$i.flac' : null,
        ),
    ];
    final watch = Stopwatch()..start();
    final data = ContactMapData(points);
    for (var z = 5; z < kMapMarkersFromZoom; z++) {
      data.hexBins(z);
    }
    expect(data.spots, isNotEmpty);
    watch.stop();
    expect(
      data.hexBins(12).cells.values.fold<int>(0, (s, c) => s + c.length),
      10000,
    );
    // Generous bound: a CI machine is slower than a phone's big cores.
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });

  group('base layers', () {
    test('IGN URLs use the Géoplateforme WMTS in Web Mercator', () {
      for (final url in [kIgnPlanUrlTemplate, kIgnPhotoUrlTemplate]) {
        expect(url, startsWith('https://data.geopf.fr/wmts?'));
        expect(url, contains('TILEMATRIXSET=PM'));
        expect(url, contains('TILEMATRIX={z}&TILEROW={y}&TILECOL={x}'));
      }
      expect(
        kIgnPlanUrlTemplate,
        contains('GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2'),
      );
      expect(kIgnPhotoUrlTemplate, contains('ORTHOIMAGERY.ORTHOPHOTOS'));
    });

    test('every base map credits its source; unknown names fall back', () {
      for (final layer in MapBaseLayer.values) {
        expect(baseLayerAttributions(layer), isNotEmpty);
      }
      expect(
        baseLayerAttributions(MapBaseLayer.ignPlan).single,
        contains('IGN'),
      );
      expect(MapBaseLayer.fromName('ignPhoto'), MapBaseLayer.ignPhoto);
      expect(MapBaseLayer.fromName('nope'), MapBaseLayer.osm);
      expect(MapBaseLayer.fromName(null), MapBaseLayer.osm);
    });
  });
}
