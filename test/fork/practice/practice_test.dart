import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/home/home_loader.dart';
import 'package:birdnet_live/fork/lpo/lpo_observation.dart';
import 'package:birdnet_live/fork/practice/practice.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/summary/listening_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LiveSession _fixture(String name) => LiveSession.fromJson(
  jsonDecode(File('test/fork/fixtures/$name').readAsStringSync())
      as Map<String, dynamic>,
);

/// The morning fixture again, under another id: a recording or a file.
LiveSession _copy(
  LiveSession source,
  String id, {
  bool practice = false,
  SessionType? type,
}) {
  final json = source.toJson()..['id'] = id;
  final copy = LiveSession.fromJson(json)..practice = practice;
  if (type != null) copy.type = type;
  return copy;
}

/// Plausible everywhere: only there so the home can call the geo-model.
class _FakeGeo extends GeoPresenceService {
  _FakeGeo(super.ref);

  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async => const GeoPresence(unexpected: false);
}

void main() {
  sqfliteFfiInit();

  late LiveSession morning;

  setUp(() => morning = _fixture('session_2026-09-20.json'));

  group('LiveSession.practice', () {
    test('round-trips through JSON', () {
      final session = _copy(morning, 'rec', practice: true);
      final json = session.toJson();
      expect(json['practice'], isTrue);
      expect(LiveSession.fromJson(json).practice, isTrue);
    });

    test('absent from the JSON when false; old sessions read as false', () {
      expect(morning.practice, isFalse);
      expect(morning.toJson().containsKey('practice'), isFalse);
      final json = morning.toJson()..['practice'] = 'yes';
      expect(LiveSession.fromJson(json).practice, isFalse);
    });
  });

  test('countsAsObservation: recordings and file analyses do not count', () {
    expect(countsAsObservation(morning), isTrue);
    expect(countsAsObservation(_copy(morning, 'a', practice: true)), isFalse);
    expect(
      countsAsObservation(_copy(morning, 'b', type: SessionType.fileUpload)),
      isFalse,
    );
    expect(
      countsAsObservation(_copy(morning, 'c', type: SessionType.pointCount)),
      isTrue,
    );
  });

  group('index', () {
    late ObservationIndex index;

    setUp(() async {
      index = await ObservationIndex.open(
        databaseFactoryFfi,
        inMemoryDatabasePath,
      );
    });

    tearDown(() => index.close());

    Future<void> expectEmpty() async {
      final counts = await index.counts();
      expect(counts.sessions, 0);
      expect(counts.detections, 0);
      expect(await index.speciesRanking(), isEmpty);
      expect(await index.speciesFirstHeardSince(DateTime(2000)), isEmpty);
      expect(await index.mapPoints(), isEmpty);
      expect(await index.totalContactsBySpecies(), isEmpty);
      expect(await index.detectionsSince(DateTime(2000)), isEmpty);
      expect(await index.lastDetection(), isNull);
      expect(await index.clipsForSpecies('Erithacus rubecula'), isEmpty);
      expect(await index.verifiedSpecies(minScore: 0), isEmpty);
      expect(await index.reviewQueue(), isEmpty);
      expect(await index.reviewQueueLength(), 0);
      expect(
        await index.precisionByScoreBand(sureMin: 0.9, probableMin: 0.5),
        isEmpty,
      );
      expect(await index.precisionBySpecies(minReviews: 1), isEmpty);
      expect(await index.speciesPrecision('Erithacus rubecula'), (
        confirmed: 0,
        reviewed: 0,
      ));
    }

    test('a recording and a file analysis count nowhere', () async {
      await index.upsertSession(_copy(morning, 'rec', practice: true));
      await index.upsertSession(
        _copy(morning, 'file', type: SessionType.fileUpload),
      );
      await expectEmpty();
    });

    test('marking a session after the fact takes it out, and back', () async {
      await index.upsertSession(morning);
      expect((await index.counts()).detections, 5);
      expect(await index.verifiedSpecies(minScore: 0.9), isNotEmpty);

      morning.practice = true;
      await index.upsertSession(morning);
      await expectEmpty();

      morning.practice = false;
      await index.upsertSession(morning);
      expect((await index.counts()).detections, 5);
    });

    test('rebuild leaves recordings and file analyses out', () async {
      await index.rebuild([
        morning,
        _copy(morning, 'rec', practice: true),
        _copy(morning, 'file', type: SessionType.fileUpload),
      ]);
      final counts = await index.counts();
      expect(counts.sessions, 1);
      expect(counts.detections, 5);
      final robin = (await index.speciesRanking()).firstWhere(
        (t) => t.scientificName == 'Erithacus rubecula',
      );
      expect(robin.contacts, 2);
    });
  });

  test('an index from before J5c is rebuilt, favorites kept', () async {
    final dir = await Directory.systemTemp.createTemp('practice_index');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/index.db';
    // Schema 2, with a file analysis already indexed and a favorite.
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE sessions (id TEXT PRIMARY KEY, type TEXT NOT NULL, '
            'start_ms INTEGER NOT NULL, end_ms INTEGER, latitude REAL, '
            'longitude REAL, detection_count INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE detections (key TEXT PRIMARY KEY, '
            'session_id TEXT NOT NULL)',
          );
          await db.execute('CREATE TABLE favorites (key TEXT PRIMARY KEY)');
          await db.insert('sessions', {
            'id': 'file',
            'type': 'fileUpload',
            'start_ms': 0,
            'detection_count': 1,
          });
          await db.insert('favorites', {'key': 'fav'});
        },
      ),
    );
    await old.close();

    final index = await ObservationIndex.open(databaseFactoryFfi, path);
    addTearDown(index.close);
    expect(ObservationIndex.schemaVersion, 3);
    expect(index.needsRebuild, isTrue);
    expect((await index.counts()).sessions, 0);
    expect(await index.favoriteKeys(), {'fav'});

    await index.rebuild([
      morning,
      _copy(morning, 'file', type: SessionType.fileUpload),
    ]);
    expect(index.needsRebuild, isFalse);
    expect((await index.counts()).sessions, 1);
  });

  test('the home shows nothing from a recording', () async {
    SharedPreferences.setMockInitialValues({});
    final index = await ObservationIndex.open(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    addTearDown(index.close);
    final container = ProviderContainer(
      overrides: [geoPresenceServiceProvider.overrideWith(_FakeGeo.new)],
    );
    addTearDown(container.dispose);
    final day = morning.startTime.toLocal();
    await index.rebuild([_copy(morning, 'rec', practice: true)]);

    final loader = HomeLoader(
      index: () async => index,
      presence: container.read(geoPresenceServiceProvider),
      position: () async => null,
      localeName: () => 'fr',
      now: () => DateTime(day.year, day.month, day.day, 23),
    );
    final home = await loader.load();
    expect(home.today.isEmpty, isTrue);
    expect(home.last, isNull);
    expect(home.toVerify, 0);

    // The same listening, real, fills the home.
    await index.rebuild([morning]);
    final real = await loader.load();
    expect(real.today.isEmpty, isFalse);
    expect(real.last, isNotNull);
  });

  test('the LPO gets nothing from a recording or a file analysis', () {
    expect(lpoObservations(morning), isNotEmpty);
    expect(lpoObservations(_copy(morning, 'rec', practice: true)), isEmpty);
    expect(
      lpoObservations(_copy(morning, 'file', type: SessionType.fileUpload)),
      isEmpty,
    );
  });

  test('the summary of a recording: no first time, nothing to check', () {
    final summary = ListeningSummary.of(
      _copy(morning, 'rec', practice: true),
      verifiedBefore: const {},
      presence: (_) => const GeoPresence(unexpected: true),
    );
    expect(summary.isRecording, isTrue);
    expect(summary.species, isNotEmpty);
    expect(summary.firstTimes, isEmpty);
    expect(summary.maybeFirsts, isEmpty);
    expect(summary.keysToCheck, isEmpty);
    expect(summary.species.any((s) => s.unexpected), isFalse);

    final real = ListeningSummary.of(morning, verifiedBefore: const {});
    expect(real.isRecording, isFalse);
    expect(real.firstTimes, isNotEmpty);
  });
}
