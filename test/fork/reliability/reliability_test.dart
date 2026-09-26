import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/announcements/domain/announcement_signals.dart';
import 'package:birdnet_live/features/announcements/geo_commonness_provider.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/fork_session_hooks.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/reliability/review_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LiveSession _fixture(String name) => LiveSession.fromJson(
  jsonDecode(File('test/fork/fixtures/$name').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  sqfliteFfiInit();

  group('reliabilityFor', () {
    const plausible = GeoPresence(unexpected: false);
    const unexpected = GeoPresence(unexpected: true);

    test('score bands when the species is plausible here', () {
      expect(
        reliabilityFor(score: 0.80, presence: plausible),
        ReliabilityLevel.sure,
      );
      expect(
        reliabilityFor(score: 0.79, presence: plausible),
        ReliabilityLevel.probable,
      );
      expect(
        reliabilityFor(score: 0.55, presence: plausible),
        ReliabilityLevel.probable,
      );
      expect(
        reliabilityFor(score: 0.54, presence: plausible),
        ReliabilityLevel.toCheck,
      );
    });

    test('unexpected here is always to check, even with a high score', () {
      expect(
        reliabilityFor(score: 0.99, presence: unexpected),
        ReliabilityLevel.toCheck,
      );
    });

    test('without geo information a high score stays probable', () {
      expect(reliabilityFor(score: 0.95), ReliabilityLevel.probable);
    });

    test('a confirmed detection is sure', () {
      expect(
        reliabilityFor(
          score: 0.3,
          review: ReviewStatus.confirmed,
          presence: unexpected,
        ),
        ReliabilityLevel.sure,
      );
    });

    test('score bands for precision', () {
      expect(scoreBand(0.9), ReliabilityLevel.sure);
      expect(scoreBand(0.6), ReliabilityLevel.probable);
      expect(scoreBand(0.2), ReliabilityLevel.toCheck);
    });
  });

  group('presence', () {
    test('from week scores: absent and rarest species are unexpected', () {
      final scores = <String, double>{
        for (var i = 0; i < 40; i++) 'sp$i': 0.05 + i * 0.02,
        'vagrant': 0.001,
        'geoOnly': 0.9,
      };
      final labels = {for (var i = 0; i < 40; i++) 'sp$i', 'vagrant'};
      final presence = presenceFromWeekScores(scores, audioLabels: labels);
      expect(presence['vagrant']!.unexpected, isTrue);
      expect(presence['sp39']!.unexpected, isFalse);
      expect(presence['sp0']!.unexpected, isTrue); // bottom tier: rare here
      expect(presence.containsKey('geoOnly'), isFalse); // not audio-detectable
    });

    test('live presence from the commonness map', () {
      GeoCommonnessEntry entry(CommonnessBin bin, {bool off = false}) =>
          GeoCommonnessEntry(
            commonness: bin,
            isOutOfSeason: off,
            currentScore: 0.3,
            annualMax: 0.5,
          );
      final map = {
        'common': entry(CommonnessBin.common),
        'rare': entry(CommonnessBin.rare),
        'late': entry(CommonnessBin.common, off: true),
      };
      expect(livePresence(map, 'common')!.unexpected, isFalse);
      expect(livePresence(map, 'rare')!.unexpected, isTrue);
      expect(livePresence(map, 'late')!.unexpected, isTrue);
      expect(livePresence(map, 'missing')!.unexpected, isTrue);
      expect(livePresence(null, 'common'), isNull);
    });
  });

  test('drag decisions of the quick review', () {
    expect(
      answerForDrag(const Offset(150, 10), Offset.zero),
      ReviewAnswer.itIs,
    );
    expect(
      answerForDrag(const Offset(-150, 10), Offset.zero),
      ReviewAnswer.itIsNot,
    );
    expect(
      answerForDrag(const Offset(10, -150), Offset.zero),
      ReviewAnswer.dontKnow,
    );
    expect(answerForDrag(const Offset(40, -30), Offset.zero), isNull);
    expect(
      answerForDrag(const Offset(30, 0), const Offset(1200, 0)),
      ReviewAnswer.itIs,
    );
  });

  group('reviews in the index and the session files', () {
    late Directory tmp;
    late SessionRepository repository;
    late ObservationIndex index;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('review_');
      repository = SessionRepository()..basePath = '${tmp.path}/sessions';
      await Directory('${tmp.path}/sessions').create(recursive: true);
      index = await ObservationIndex.open(
        databaseFactoryFfi,
        inMemoryDatabasePath,
      );
      ForkSessionHooks.listener = null;
      final morning = _fixture('session_2026-09-20.json');
      final evening = _fixture('session_2026-09-21.json');
      await repository.save(morning);
      await repository.save(evening);
      await index.rebuild([morning, evening]);
    });

    tearDown(() async {
      await index.close();
      await tmp.delete(recursive: true);
    });

    test('precision per score band and per species', () async {
      final bands = await index.precisionByScoreBand(
        sureMin: ReliabilityConfig.sureMinScore,
        probableMin: ReliabilityConfig.probableMinScore,
      );
      // Robin 0.93 and 0.88 confirmed; blackbird 0.52 rejected.
      expect(bands['sure'], (confirmed: 2, reviewed: 2));
      expect(bands['toCheck'], (confirmed: 0, reviewed: 1));
      expect(bands.containsKey('probable'), isFalse);

      expect(await index.speciesPrecision('Erithacus rubecula'), (
        confirmed: 2,
        reviewed: 2,
      ));
      expect(await index.precisionBySpecies(minReviews: 5), isEmpty);
      final bySpecies = await index.precisionBySpecies(minReviews: 1);
      expect(bySpecies.first.scientificName, 'Erithacus rubecula');
    });

    test('writing a review updates the session file, then the index', () async {
      final writer = ReviewWriter(
        repository: repository,
        index: () async => index,
        now: () => DateTime.utc(2026, 9, 26, 9),
      );
      final queue = await index.reviewQueue();
      expect(queue, hasLength(4));
      final hoopoe = queue.first;
      expect(hoopoe.scientificName, 'Upupa epops');

      expect(await writer.setStatus(hoopoe, ReviewStatus.confirmed), isTrue);
      final saved = await repository.load(hoopoe.sessionId);
      final record = saved!.detections[hoopoe.position];
      expect(record.reviewStatus, ReviewStatus.confirmed);
      expect(record.reviewedAt, DateTime.utc(2026, 9, 26, 9));

      await index.upsertSession(saved); // what the save hook does in the app
      expect(
        (await index.reviewQueue()).map((d) => d.scientificName),
        isNot(contains('Upupa epops')),
      );
    });

    test('"Je ne sais pas" removes a detection from the queue only', () async {
      final writer = ReviewWriter(
        repository: repository,
        index: () async => index,
      );
      final tit = (await index.reviewQueue()).firstWhere(
        (d) => d.scientificName == 'Parus major',
      );
      await writer.skip(tit);
      expect(await index.reviewQueueLength(), 3);
      final saved = await repository.load(tit.sessionId);
      expect(
        saved!.detections[tit.position].reviewStatus,
        ReviewStatus.unreviewed,
      );
      // Survives a rebuild.
      await index.rebuild([saved, _fixture('session_2026-09-21.json')]);
      expect(await index.reviewQueueLength(), 3);
    });
  });
}
