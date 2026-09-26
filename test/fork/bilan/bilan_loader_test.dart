import 'dart:io';

import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/bilan/bilan_loader.dart';
import 'package:birdnet_live/fork/data/fork_session_hooks.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'bilan_fixture.dart';

/// Geo presence of the mockup, without the geo-model.
class _FakeGeo extends GeoPresenceService {
  _FakeGeo(super.ref);

  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async => latitude == null ? null : morningPresence()[scientificName];
}

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late SessionRepository repository;
  late ObservationIndex index;
  late ProviderContainer container;
  late LiveSession morning;

  /// A week earlier: the robin and the owl, plus a rejected Pic épeiche.
  LiveSession earlier() => LiveSession(
    id: '2026-09-19T07-00-00.000',
    startTime: DateTime(2026, 9, 19, 7),
    endTime: DateTime(2026, 9, 19, 7, 30),
    settings: morning.settings,
    detections: [
      for (final (name, minute) in [(robin, 5), (owl, 10), (woodpecker, 15)])
        DetectionRecord(
          scientificName: name,
          commonName: name,
          confidence: 0.9,
          timestamp: DateTime(2026, 9, 19, 7, minute),
          reviewStatus:
              name == woodpecker
                  ? ReviewStatus.rejected
                  : ReviewStatus.unreviewed,
        ),
    ],
  );

  BilanLoader loader({bool indexFails = false}) => BilanLoader(
    repository: repository,
    index: () async => indexFails ? throw StateError('no index') : index,
    presence: container.read(geoPresenceServiceProvider),
    localeName: () => 'fr',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bilan_');
    repository = SessionRepository()..basePath = '${tmp.path}/sessions';
    await Directory('${tmp.path}/sessions').create(recursive: true);
    index = await ObservationIndex.open(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    ForkSessionHooks.listener = null;
    container = ProviderContainer(
      overrides: [geoPresenceServiceProvider.overrideWith(_FakeGeo.new)],
    );
    morning = morningSession();
    final before = earlier();
    await repository.save(before);
    await index.rebuild([before]);
    await repository.save(morning);
  });

  tearDown(() async {
    container.dispose();
    await index.close();
    await tmp.delete(recursive: true);
  });

  test('reads the saved session, with the reviews made since', () async {
    final saved = await repository.load(morning.id);
    saved!.detections
        .firstWhere((d) => d.scientificName == owl)
        .markConfirmed();
    await repository.save(saved);

    final inputs = await loader().load(morning);
    expect(
      inputs.session.detections
          .firstWhere((d) => d.scientificName == owl)
          .isConfirmed,
      isTrue,
    );
  });

  test('indexes the session and finds the species heard before', () async {
    final inputs = await loader().load(morning);
    expect((await index.counts()).sessions, 2);
    // The rejected Pic épeiche does not count.
    expect(inputs.heardBefore, {robin, owl});
    expect(inputs.presence[hoopoe]?.unexpected, isTrue);
    expect(inputs.presence[robin]?.unexpected, isFalse);
  });

  test('passes the « Je ne sais pas » answers', () async {
    final key = detectionKey(morning.id, morning.detections.last);
    await index.markSkipped(key);
    expect((await loader().load(morning)).skippedKeys, {key});
  });

  test('without index nothing is new, and no position no presence', () async {
    morning
      ..latitude = null
      ..longitude = null;
    await repository.save(morning);
    final inputs = await loader(indexFails: true).load(morning);
    expect(inputs.heardBefore, isNull);
    expect(inputs.skippedKeys, isEmpty);
    expect(inputs.presence, isEmpty);
  });

  test('place name: the stored one, or none without position', () async {
    morning.locationName = 'Beaulieu-sur-Brenne';
    expect(await loader().placeName(morning), 'Beaulieu-sur-Brenne');

    final nowhere =
        morningSession()
          ..latitude = null
          ..longitude = null;
    expect(await loader().placeName(nowhere), isNull);
  });

  test('place name without consent: no network, nothing saved', () async {
    expect(await loader().placeName(morning), isNull);
    expect((await repository.load(morning.id))!.locationName, isNull);
  });
}
