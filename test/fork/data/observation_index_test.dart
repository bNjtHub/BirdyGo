import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/fork_session_hooks.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LiveSession _fixture(String name) => LiveSession.fromJson(
  jsonDecode(File('test/fork/fixtures/$name').readAsStringSync())
      as Map<String, dynamic>,
);

Future<ObservationIndex> _openMemory() =>
    ObservationIndex.open(databaseFactoryFfi, inMemoryDatabasePath);

void main() {
  sqfliteFfiInit();

  late LiveSession morning;
  late LiveSession evening;

  setUp(() {
    morning = _fixture('session_2026-09-20.json');
    evening = _fixture('session_2026-09-21.json');
  });

  group('indexRowsForSession', () {
    test('flattens detections with stable keys and GPS fallback', () {
      final rows = indexRowsForSession(morning);
      expect(rows, hasLength(5));
      expect(
        rows.first.key,
        '2026-09-20T07-10-00.000|Erithacus rubecula|2026-09-20T05:12:00.000Z',
      );
      // Parus major has no own position: takes the session position.
      final tit = rows.firstWhere((r) => r.scientificName == 'Parus major');
      expect(tit.latitude, 47.21);
      expect(tit.longitude, -1.55);
      expect(rows.map((r) => r.position), [0, 1, 2, 3, 4]);
    });
  });

  group('ObservationIndex', () {
    late ObservationIndex index;

    setUp(() async {
      index = await _openMemory();
      await index.rebuild([morning, evening]);
    });

    tearDown(() => index.close());

    test('counts sessions and detections', () async {
      final counts = await index.counts();
      expect(counts.sessions, 2);
      expect(counts.detections, 7);
    });

    test('ranking ignores rejected detections and counts days', () async {
      final ranking = await index.speciesRanking();
      expect(ranking.first.scientificName, 'Erithacus rubecula');
      expect(ranking.first.contacts, 3);
      final expectedDays =
          {
            for (final t in [
              DateTime.utc(2026, 9, 20, 5, 12),
              DateTime.utc(2026, 9, 20, 5, 30),
              DateTime.utc(2026, 9, 21, 17, 5),
            ])
              '${t.toLocal().year}-${t.toLocal().month}-${t.toLocal().day}',
          }.length;
      expect(ranking.first.days, expectedDays);
      expect(
        ranking.map((t) => t.scientificName),
        isNot(contains('Turdus merula')),
      );
      expect(ranking, hasLength(4));
    });

    test('ranking filters by period and confirmed only', () async {
      final confirmed = await index.speciesRanking(confirmedOnly: true);
      expect(confirmed.map((t) => t.scientificName), ['Erithacus rubecula']);
      expect(confirmed.single.contacts, 2);

      final eveningOnly = await index.speciesRanking(
        from: DateTime.utc(2026, 9, 21),
      );
      expect(eveningOnly.map((t) => t.scientificName).toSet(), {
        'Erithacus rubecula',
        'Strix aluco',
      });
    });

    test('ranking by last heard puts the newest species first', () async {
      final ranking = await index.speciesRanking(order: RankingOrder.lastHeard);
      expect(ranking.first.scientificName, 'Strix aluco');
    });

    test('all-time totals per species', () async {
      final totals = await index.totalContactsBySpecies();
      expect(totals['Erithacus rubecula'], 3);
      expect(totals['Strix aluco'], 1);
      expect(totals.containsKey('Turdus merula'), isFalse);
    });

    test(
      'map points only include positioned, non-rejected detections',
      () async {
        final points = await index.mapPoints();
        expect(points, hasLength(6));
        expect(points.every((p) => p.latitude != null), isTrue);
        final hoopoe = await index.mapPoints(scientificName: 'Upupa epops');
        expect(hoopoe.single.latitude, 47.2110);
      },
    );

    test('clips of a species, by score or by date, and favorites', () async {
      final byScore = await index.clipsForSpecies('Erithacus rubecula');
      expect(byScore.map((c) => c.confidence), [0.93, 0.81]);
      final byDate = await index.clipsForSpecies(
        'Erithacus rubecula',
        byDate: true,
      );
      expect(byDate.first.confidence, 0.81);

      await index.setFavorite(byScore.last.key, favorite: true);
      final favorites = await index.clipsForSpecies(
        'Erithacus rubecula',
        favoritesOnly: true,
      );
      expect(favorites.single.key, byScore.last.key);

      await index.setFavorite(byScore.last.key, favorite: false);
      expect(await index.favoriteKeys(), isEmpty);
    });

    test('species with clips, with clip and favorite counts', () async {
      final robin = (await index.clipsForSpecies('Erithacus rubecula')).first;
      await index.setFavorite(robin.key, favorite: true);
      final species = await index.speciesWithClips();
      expect(species.map((s) => s.scientificName), [
        'Erithacus rubecula',
        'Parus major',
      ]);
      expect(species.first.clips, 2);
      expect(species.first.favorites, 1);
      expect(species.last.favorites, 0);
    });

    test('favorites survive a rebuild', () async {
      final key = indexRowsForSession(morning).first.key;
      await index.setFavorite(key, favorite: true);
      await index.rebuild([morning, evening]);
      expect(await index.favoriteKeys(), {key});
    });

    test('activity histograms sum to the non-rejected detections', () async {
      final hours = await index.activityByHour();
      final months = await index.activityByMonth();
      expect(hours, hasLength(24));
      expect(months, hasLength(12));
      expect(hours.reduce((a, b) => a + b), 6);
      expect(months[8], 6); // September
      final robinHours = await index.activityByHour(
        scientificName: 'Erithacus rubecula',
      );
      expect(robinHours.reduce((a, b) => a + b), 3);
    });

    test(
      'review queue lists unreviewed detections, most doubtful first',
      () async {
        final queue = await index.reviewQueue();
        expect(queue.map((d) => d.scientificName).toList(), [
          'Upupa epops',
          'Parus major',
          'Strix aluco',
          'Erithacus rubecula',
        ]);
      },
    );

    test('last detection and detections since a time (home)', () async {
      expect((await index.lastDetection())?.scientificName, 'Strix aluco');
      final since = await index.detectionsSince(
        DateTime.utc(2026, 9, 20, 5, 35),
      );
      // Turdus merula (05:45) is rejected.
      expect(since.map((d) => d.scientificName), [
        'Upupa epops',
        'Erithacus rubecula',
        'Strix aluco',
      ]);

      await index.clear();
      expect(await index.lastDetection(), isNull);
    });

    test('species verified before a time (home)', () async {
      expect(await index.verifiedSpecies(minScore: 0.7), {
        'Erithacus rubecula',
        'Strix aluco',
      });
      expect(
        await index.verifiedSpecies(
          minScore: 0.7,
          before: DateTime.utc(2026, 9, 21),
        ),
        {'Erithacus rubecula'},
      );
    });

    test('upsert replaces a session and remove deletes it', () async {
      morning.detections.removeLast();
      await index.upsertSession(morning);
      expect((await index.counts()).detections, 6);

      await index.removeSession(morning.id);
      final counts = await index.counts();
      expect(counts.sessions, 1);
      expect(counts.detections, 2);

      await index.clear();
      expect((await index.counts()).detections, 0);
    });
  });

  group('ObservationIndexService', () {
    late Directory tmp;
    late SessionRepository repository;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('obs_index_');
      repository = SessionRepository()..basePath = '${tmp.path}/sessions';
      await Directory('${tmp.path}/sessions').create(recursive: true);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      ForkSessionHooks.listener = null;
      await tmp.delete(recursive: true);
    });

    Future<void> settle(ObservationIndexService service) async {
      for (var i = 0; i < 50 && service.isRebuilding; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    test('fills the index once from saved sessions, then follows saves '
        'and deletes', () async {
      ForkSessionHooks.listener = null;
      await repository.save(morning);

      final prefs = await SharedPreferences.getInstance();
      final service = ObservationIndexService(
        repository: repository,
        prefs: prefs,
        openIndex: _openMemory,
      );
      final index = await service.ensureReady();
      await settle(service);
      expect((await index.counts()).sessions, 1);
      expect(
        prefs.getInt(kObservationIndexFilledVersion),
        ObservationIndex.schemaVersion,
      );

      await repository.save(evening);
      await settle(service);
      expect((await index.counts()).sessions, 2);

      await repository.delete(morning.id);
      await settle(service);
      expect((await index.counts()).sessions, 1);

      await repository.deleteAll();
      await settle(service);
      expect((await index.counts()).sessions, 0);
      await index.close();
    });
  });
}
