import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/game/verified_species.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  List<(String, double, ReviewStatus)> d, {
  bool located = true,
}) {
  final start = DateTime(2026, 9, 26, 7);
  return LiveSession(
    id: id,
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    latitude: located ? 46.7 : null,
    longitude: located ? 1.2 : null,
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
          timestamp: start.add(Duration(minutes: i)),
          reviewStatus: review,
          latitude: located ? 46.7 : null,
          longitude: located ? 1.2 : null,
        ),
    ],
  );
}

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
      _session('located', [
        // Sûr: high score, plausible here.
        ('Erithacus rubecula', 0.95, ReviewStatus.unreviewed),
        ('Erithacus rubecula', 0.4, ReviewStatus.rejected),
        // Rare here: a high score is not enough.
        ('Upupa epops', 0.97, ReviewStatus.unreviewed),
        // Probable only.
        ('Turdus merula', 0.6, ReviewStatus.unreviewed),
        ('Turdus merula', 0.3, ReviewStatus.unreviewed),
        // Confirmed, whatever the score.
        ('Parus major', 0.3, ReviewStatus.confirmed),
        // Rejected only.
        ('Pica pica', 0.99, ReviewStatus.rejected),
      ]),
      // No position: plausibility unknown, the score alone never counts.
      _session('nowhere', [
        ('Sitta europaea', 0.99, ReviewStatus.unreviewed),
      ], located: false),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await index.close();
  });

  test('only Sûr or confirmed species count', () async {
    final verified = await gameVerifiedSpecies(
      index: index,
      presence: container.read(geoPresenceServiceProvider),
    );
    expect(verified, {'Erithacus rubecula', 'Parus major'});
  });

  test('review tallies count contacts, confirmations and the queue', () async {
    final tallies = {
      for (final t in await index.speciesReviewTallies()) t.scientificName: t,
    };
    expect(tallies.keys, isNot(contains('Pica pica')));
    expect(tallies['Erithacus rubecula']!.contacts, 1);
    expect(tallies['Parus major']!.confirmed, 1);
    expect(tallies['Turdus merula']!.inQueue, 2);

    final keys = await index.reviewKeysFor('Turdus merula');
    expect(keys, hasLength(2));
    await index.markSkipped(keys.first);
    expect(await index.reviewKeysFor('Turdus merula'), hasLength(1));
    final after = await index.speciesReviewTallies();
    expect(
      after.firstWhere((t) => t.scientificName == 'Turdus merula').inQueue,
      1,
    );
  });

  test('sure candidates skip confirmed species and low scores', () async {
    final names = [
      for (final d in await index.sureCandidates(
        minScore: ReliabilityConfig.sureMinScore,
      ))
        d.scientificName,
    ];
    expect(names, ['Sitta europaea', 'Upupa epops', 'Erithacus rubecula']);
  });
}
