import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/reliability/review_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LiveSession _fixture(String name) => LiveSession.fromJson(
  jsonDecode(File('test/fork/fixtures/$name').readAsStringSync())
      as Map<String, dynamic>,
);

/// The counters (home « N à vérifier ») listen to the index service: every
/// answer that changes the review queue must reach it, « Je ne sais pas »
/// included (it writes no session, so no save hook fires).
void main() {
  sqfliteFfiInit();
  late ObservationIndex index;
  late ObservationIndexService service;
  late ReviewWriter writer;
  var notifications = 0;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('counter_');
    await Directory('${tmp.path}/sessions').create(recursive: true);
    SharedPreferences.setMockInitialValues({});
    index = await ObservationIndex.open(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    await index.rebuild([_fixture('session_2026-09-20.json')]);
    service = ObservationIndexService(
      repository: SessionRepository(),
      prefs: await SharedPreferences.getInstance(),
      openIndex: () async => index,
    );
    notifications = 0;
    service.addListener(() => notifications++);
    writer = ReviewWriter(
      repository: SessionRepository()..basePath = '${tmp.path}/sessions',
      index: () async => index,
      onQueueChanged: service.notifyQueueChanged,
    );
  });

  tearDown(() async {
    await index.close();
    await tmp.delete(recursive: true);
  });

  test('answering « Je ne sais pas » to every card empties the count and '
      'notifies the listeners each time', () async {
    final queue = await index.reviewQueue();
    expect(queue, isNotEmpty);
    expect(await index.reviewQueueLength(), queue.length);
    for (final d in queue) {
      await writer.skip(d);
    }
    expect(notifications, queue.length);
    expect(await index.reviewQueueLength(), 0);
    expect(await index.reviewQueue(), isEmpty);
  });

  test('a detection whose session is gone can be skipped out of the queue '
      '(no phantom « 1 »)', () async {
    // The fixture session was never saved as a file: setStatus fails.
    final ghost = (await index.reviewQueue()).first;
    expect(await writer.setStatus(ghost, ReviewStatus.confirmed), isFalse);
    expect(await index.reviewQueueLength(), greaterThan(0));
    final before = await index.reviewQueueLength();
    await writer.skip(ghost);
    expect(await index.reviewQueueLength(), before - 1);
  });
}
