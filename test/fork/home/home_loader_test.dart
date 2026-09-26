import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every species plausible but the Huppe; nothing without a position.
class _FakeGeo extends GeoPresenceService {
  _FakeGeo(super.ref);

  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async =>
      latitude == null
          ? null
          : GeoPresence(unexpected: scientificName == 'Upupa epops');
}

LiveSession _session(
  String id,
  DateTime start,
  List<(String, int, double)> d,
) => LiveSession(
  id: id,
  startTime: start,
  endTime: start.add(const Duration(hours: 1)),
  latitude: 46.7,
  longitude: 1.2,
  settings: const SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 30,
    inferenceRate: 1.5,
    speciesFilterMode: 'geoMerge',
  ),
  detections: [
    for (final (name, minute, score) in d)
      DetectionRecord(
        scientificName: name,
        commonName: name,
        confidence: score,
        timestamp: start.add(Duration(minutes: minute)),
      ),
  ],
);

void main() {
  sqfliteFfiInit();

  late ObservationIndex index;
  late ProviderContainer container;
  final now = DateTime(2026, 9, 26, 8, 5);

  HomeLoader loader({bool indexFails = false, HomePosition? position}) =>
      HomeLoader(
        index: () async => indexFails ? throw StateError('no index') : index,
        presence: container.read(geoPresenceServiceProvider),
        position: () async => position,
        localeName: () => 'fr',
        now: () => now,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    index = await ObservationIndex.open(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    container = ProviderContainer(
      overrides: [geoPresenceServiceProvider.overrideWith(_FakeGeo.new)],
    );
    await index.rebuild([
      _session('yesterday', DateTime(2026, 9, 25, 7), [
        ('Erithacus rubecula', 5, 0.95),
      ]),
      _session('today', DateTime(2026, 9, 26, 7, 12), [
        ('Erithacus rubecula', 1, 0.97),
        ('Erithacus rubecula', 30, 0.9),
        ('Dendrocopos major', 14, 0.91),
        ('Upupa epops', 26, 0.58),
        ('Erithacus rubecula', 40, 0.93),
      ]),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await index.close();
  });

  test("today's tiles, last bird and review count", () async {
    final home = await loader().load();
    expect(home.today.species, 3);
    expect(home.today.contacts, 5);
    // Pic épeiche: new and Sûr. Huppe: new but unexpected here.
    expect(home.today.newSpecies, 1);

    final last = home.last!;
    expect(last.scientificName, 'Erithacus rubecula');
    expect(
      last.detection.start.isAtSameMomentAs(DateTime(2026, 9, 26, 7, 52)),
      isTrue,
    );
    expect(last.level, ReliabilityLevel.sure);
    expect(last.total, 4);

    expect(home.toVerify, 6);
  });

  test('an index that cannot open gives an empty home', () async {
    final home = await loader(indexFails: true).load();
    expect(home.today.isEmpty, isTrue);
    expect(home.last, isNull);
    expect(home.toVerify, 0);
  });

  test('no position, no place; no consent, no network', () async {
    expect(await loader().placeName(), isNull);
    expect(
      await loader(position: (latitude: 46.7, longitude: 1.2)).placeName(),
      isNull,
    );
  });
}
