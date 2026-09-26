import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/species_page/species_page_loader.dart';
import 'package:birdnet_live/fork/species_page/species_page_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LiveSession _session(
  String id,
  DateTime start,
  List<(String, int, double, ReviewStatus, bool)> d, {
  double? latitude = 46.7,
}) => LiveSession(
  id: id,
  startTime: start,
  endTime: start.add(const Duration(hours: 1)),
  latitude: latitude,
  longitude: latitude == null ? null : 1.2,
  settings: const SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 30,
    inferenceRate: 1.5,
    speciesFilterMode: 'geoMerge',
  ),
  detections: [
    for (final (i, (name, minute, score, review, clip)) in d.indexed)
      DetectionRecord(
        scientificName: name,
        commonName: name,
        confidence: score,
        timestamp: start.add(Duration(minutes: minute)),
        reviewStatus: review,
        audioClipPath: clip ? '/clips/$id-$i.wav' : null,
        latitude: latitude,
        longitude: latitude == null ? null : 1.2,
      ),
  ],
);

void main() {
  sqfliteFfiInit();

  late ObservationIndex index;

  SpeciesPageLoader loader({
    bool indexFails = false,
    Map<String, List<double>>? year,
    bool yearFails = false,
    Set<String>? labels,
  }) => SpeciesPageLoader(
    index: () async => indexFails ? throw StateError('no index') : index,
    yearScores: () async => yearFails ? throw StateError('no model') : year,
    audioLabels: labels == null ? null : () async => labels,
  );

  setUp(() async {
    index = await ObservationIndex.open(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    const u = ReviewStatus.unreviewed;
    await index.rebuild([
      _session('a', DateTime(2026, 9, 25, 7), [
        ('Erithacus rubecula', 5, 0.95, ReviewStatus.confirmed, true),
        ('Erithacus rubecula', 20, 0.70, ReviewStatus.rejected, true),
        ('Upupa epops', 26, 0.58, u, false),
      ]),
      _session('b', DateTime(2026, 9, 26, 7, 12), [
        ('Erithacus rubecula', 1, 0.97, u, true),
        ('Erithacus rubecula', 30, 0.60, u, true),
        ('Erithacus rubecula', 40, 0.88, u, false),
      ], latitude: null),
    ]);
  });

  tearDown(() => index.close());

  test('record of a heard species', () async {
    final keys =
        (await index.clipsForSpecies(
          'Erithacus rubecula',
        )).map((c) => c.key).toList();
    // The worst clip is a favorite: it comes first on the page.
    await index.setFavorite(keys.last, favorite: true);

    final record = await loader().record('Erithacus rubecula');
    expect(record.heard, isTrue);
    // The rejected contact never counts, but its review does.
    expect(record.tally!.contacts, 4);
    expect(record.tally!.days, 2);
    expect(record.confirmed, 1);
    expect(record.reviewed, 2);
    expect(record.verified, isTrue);
    expect(record.clipCount, 3);
    expect(record.clips, hasLength(3));
    expect(record.clips.first.key, keys.last);
    expect(record.favorites, {keys.last});
    expect(record.hours[7], 4);
    // Session b has no position: one spot.
    expect(record.spots, [(latitude: 46.7, longitude: 1.2)]);
  });

  test('a low-score, unreviewed species is not verified', () async {
    final record = await loader().record('Upupa epops');
    expect(record.heard, isTrue);
    expect(record.verified, isFalse);
    expect(record.clips, isEmpty);
  });

  test('never heard, or no index: empty record', () async {
    expect((await loader().record('Strix aluco')).heard, isFalse);
    expect(
      (await loader(indexFails: true).record('Erithacus rubecula')).heard,
      isFalse,
    );
  });

  test('favorites go through the index', () async {
    final key = (await index.clipsForSpecies('Erithacus rubecula')).first.key;
    await loader().setFavorite(key, favorite: true);
    expect(await index.favoriteKeys(), {key});
  });

  test("the geo-model's year, when there is one", () async {
    final weeks = List<double>.filled(48, 0.5);
    final year = await loader(
      year: {'Erithacus rubecula': weeks},
    ).presence('Erithacus rubecula');
    expect(year!.span, const PresenceSpan.allYear());
    expect(
      await loader(year: {'Erithacus rubecula': weeks}).presence('Strix aluco'),
      isNull,
    );
    expect(await loader().presence('Erithacus rubecula'), isNull);
    expect(
      await loader(yearFails: true).presence('Erithacus rubecula'),
      isNull,
    );
  });

  test('unexpected here this week, with the reliability rule (J3b)', () async {
    // 40 species with flat years, the rarest one in the bottom tier.
    final year = {
      for (var i = 0; i < 40; i++)
        'sp$i': List<double>.filled(48, 0.05 + i * 0.02),
      'vagrant': List<double>.filled(48, 0.001),
    };
    final labels = year.keys.toSet();
    final now = DateTime(2026, 9, 26);
    final l = loader(year: year, labels: labels);
    expect(await l.unexpectedNow('sp0', now: now), isTrue);
    expect(await l.unexpectedNow('vagrant', now: now), isTrue);
    expect(await l.unexpectedNow('unknown', now: now), isTrue);
    expect(await l.unexpectedNow('sp39', now: now), isFalse);
    // Unknown without a position, a model or the audio labels.
    expect(
      await loader(labels: labels).unexpectedNow('sp0', now: now),
      isFalse,
    );
    expect(await loader(year: year).unexpectedNow('sp0', now: now), isFalse);
    expect(
      await loader(
        yearFails: true,
        labels: labels,
      ).unexpectedNow('sp0', now: now),
      isFalse,
    );
  });
}
