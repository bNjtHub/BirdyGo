import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every species plausible.
class _FakeGeo extends GeoPresenceService {
  _FakeGeo(super.ref);

  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async => latitude == null ? null : const GeoPresence(unexpected: false);
}

const _dawnSpecies = [
  'Erithacus rubecula',
  'Turdus merula',
  'Parus major',
  'Cyanistes caeruleus',
  'Fringilla coelebs',
  'Troglodytes troglodytes',
  'Phylloscopus collybita',
  'Sylvia atricapilla',
  'Columba palumbus',
  'Strix aluco',
];

LiveSession _session(
  String id,
  DateTime start,
  Duration length,
  List<(String, double, ReviewStatus)> d,
) => LiveSession(
  id: id,
  startTime: start,
  endTime: start.add(length),
  latitude: 46.7,
  longitude: 1.2,
  settings: const SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 30,
    inferenceRate: 1.5,
    speciesFilterMode: 'geoMerge',
  ),
  detections: [
    for (final (i, (name, score, review)) in d.indexed)
      DetectionRecord(
        scientificName: name,
        commonName: name,
        confidence: score,
        timestamp: start.add(Duration(seconds: 20 * i)),
        reviewStatus: review,
        latitude: 46.7,
        longitude: 1.2,
      ),
  ],
);

void main() {
  sqfliteFfiInit();

  late ObservationIndex index;
  late ProviderContainer container;

  setUp(() async {
    index = await ObservationIndex.open(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    container = ProviderContainer(
      overrides: [geoPresenceServiceProvider.overrideWith(_FakeGeo.new)],
    );
    await index.rebuild([
      // Before sunrise (whatever the test machine's time zone), with
      // ten sure species: early bird and dawn chorus.
      _session(
        'dawn',
        DateTime(2026, 9, 25, 5, 30),
        const Duration(minutes: 40),
        [for (final s in _dawnSpecies) (s, 0.9, ReviewStatus.unreviewed)],
      ),
      _session('noon', DateTime(2026, 9, 26, 12), const Duration(minutes: 10), [
        ('Pica pica', 0.4, ReviewStatus.confirmed),
        ('Corvus corone', 0.6, ReviewStatus.rejected),
        ('Sturnus vulgaris', 0.6, ReviewStatus.unreviewed),
      ]),
      // Too short to count in the série.
      _session(
        'short',
        DateTime(2026, 9, 27, 9),
        const Duration(minutes: 2),
        const [],
      ),
    ]);
    await index.markSkipped(
      (await index.reviewKeysFor('Sturnus vulgaris')).first,
    );
  });

  tearDown(() async {
    container.dispose();
    await index.close();
  });

  GameLoader loader({Map<String, List<double>>? weekly}) => GameLoader(
    index: () async => index,
    presence: container.read(geoPresenceServiceProvider),
    taxonomy: () async => null,
    position: () async => (latitude: 46.7, longitude: 1.2),
    weeklyScores: (_) async => weekly,
    now: () => DateTime(2026, 9, 27, 12),
  );

  test('facts from the index', () async {
    final facts = await loader().load();
    expect(facts.verifiedBirds, {..._dawnSpecies, 'Pica pica'});
    expect(facts.dawnChoruses, 1);
    expect(facts.earlyStarts, 1);
    // Confirmed, rejected and « Je ne sais pas ».
    expect(facts.reviewed, 3);
    expect(facts.streak.current, 2);
    expect(facts.migrants, isEmpty);
  });

  test('migrants: present some weeks, absent others, here', () async {
    final facts =
        await loader(
          weekly: {
            'Sylvia atricapilla': [0.0, 0.0, 0.3, 0.4],
            'Erithacus rubecula': [0.5, 0.4, 0.5, 0.6],
          },
        ).load();
    expect(facts.migrants, {'Sylvia atricapilla'});
  });

  test('an index that cannot open gives an empty game', () async {
    final facts =
        await GameLoader(
          index: () async => throw StateError('no index'),
          presence: container.read(geoPresenceServiceProvider),
          taxonomy: () async => null,
          position: () async => null,
          weeklyScores: (_) async => null,
        ).load();
    expect(facts.verifiedBirds, isEmpty);
  });
}
