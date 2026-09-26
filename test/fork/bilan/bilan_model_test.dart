import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/bilan/bilan_model.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bilan_fixture.dart';

void main() {
  late LiveSession session;

  setUp(() => session = morningSession());

  BilanSummary build({
    Map<String, GeoPresence>? presence,
    Set<String>? heardBefore,
    Set<String> skipped = const {},
  }) => buildBilan(
    session: session,
    presence: presence ?? morningPresence(),
    heardBefore: heardBefore ?? heardBeforeMorning(),
    skippedKeys: skipped,
  );

  String keyOf(String name) => detectionKey(
    session.id,
    session.detections.firstWhere((d) => d.scientificName == name),
  );

  group('buildBilan on the mockup morning (SPEC 8.2)', () {
    test('counts species, contacts and duration', () {
      final bilan = build();
      expect(bilan.species, hasLength(13));
      expect(bilan.contacts, 52);
      expect(bilan.duration, const Duration(minutes: 42));
      expect(bilan.start, at(7, 12));
      expect(bilan.end, at(7, 54));
      expect(bilan.moment, BilanMoment.morning);
    });

    test('orders the strip by contacts, then first contact', () {
      expect(build().species.map((s) => s.scientificName), [
        robin,
        wren,
        blackbird,
        greatTit,
        blueTit,
        chaffinch,
        magpie,
        chiffchaff,
        sparrow,
        woodpecker,
        owl,
        kingfisher,
        hoopoe,
      ]);
      expect(build().species.first.count, 9);
    });

    test('species with nothing Sûr are pending, with their best level', () {
      final bilan = build();
      final pending = {
        for (final s in bilan.species)
          if (s.pending) s.scientificName: s.level,
      };
      expect(pending, {
        owl: ReliabilityLevel.probable,
        kingfisher: ReliabilityLevel.toCheck,
        hoopoe: ReliabilityLevel.toCheck,
      });
      // Probable at its first contact, Sûr afterwards.
      final chiffchaffRow = bilan.species.firstWhere(
        (s) => s.scientificName == chiffchaff,
      );
      expect(chiffchaffRow.level, ReliabilityLevel.sure);
      expect(chiffchaffRow.toVerifyKeys, isEmpty);
    });

    test('asks to check the three pending detections', () {
      expect(build().toVerifyKeys, [
        keyOf(owl),
        keyOf(kingfisher),
        keyOf(hoopoe),
      ]);
    });

    test('Pic épeiche is new and verified, Huppe new and unexpected', () {
      final bilan = build();
      expect(bilan.newVerified.map((s) => s.scientificName), [woodpecker]);
      expect(bilan.newVerified.single.firstHeard, at(7, 26));
      expect(bilan.newPending.map((s) => s.scientificName), [hoopoe]);
      expect(bilan.newPending.single.unexpected, isTrue);
    });
  });

  group('buildBilan rules', () {
    test('rejected detections are left out', () {
      session.detections
          .firstWhere((d) => d.scientificName == kingfisher)
          .markRejected();
      final bilan = build();
      expect(
        bilan.species.map((s) => s.scientificName),
        isNot(contains(kingfisher)),
      );
      expect(bilan.contacts, 51);
      expect(bilan.toVerifyKeys, hasLength(2));
    });

    test('a confirmed contact settles its species', () {
      session.detections
          .firstWhere((d) => d.scientificName == owl)
          .markConfirmed();
      final bilan = build();
      final owlRow = bilan.species.firstWhere((s) => s.scientificName == owl);
      expect(owlRow.pending, isFalse);
      expect(bilan.toVerifyKeys, [keyOf(kingfisher), keyOf(hoopoe)]);
    });

    test('« Je ne sais pas » answers are not asked again', () {
      final bilan = build(skipped: {keyOf(hoopoe)});
      expect(bilan.toVerifyKeys, [keyOf(owl), keyOf(kingfisher)]);
      // Still pending: the dot stays.
      expect(
        bilan.species.firstWhere((s) => s.scientificName == hoopoe).pending,
        isTrue,
      );
    });

    test('without geo presence nothing is Sûr (J3 rule)', () {
      final bilan = build(presence: const {});
      expect(bilan.species.every((s) => s.pending), isTrue);
      expect(bilan.newVerified, isEmpty);
    });

    test('unknown index: nothing is new', () {
      final bilan = buildBilan(session: session, presence: morningPresence());
      expect(bilan.newVerified, isEmpty);
      expect(bilan.newPending, isEmpty);
    });

    test('the « unknown species » entries are not species', () {
      session.detections.add(
        DetectionRecord(
          scientificName: DetectionRecord.unknownSpeciesName,
          commonName: DetectionRecord.unknownCommonName,
          confidence: 1,
          timestamp: at(7, 40),
        ),
      );
      final bilan = build();
      expect(bilan.species, hasLength(13));
      expect(bilan.contacts, 52);
    });

    test('localized names', () {
      final bilan = buildBilan(
        session: session,
        localizedName: (r) => r.scientificName.toUpperCase(),
      );
      expect(bilan.species.first.commonName, 'ERITHACUS RUBECULA');
    });

    test('an empty session', () {
      session.detections.clear();
      final bilan = build();
      expect(bilan.isEmpty, isTrue);
      expect(bilan.contacts, 0);
      expect(bilan.toVerifyKeys, isEmpty);
    });
  });

  test('momentOf follows the local hour', () {
    DateTime h(int hour, [int minute = 0]) =>
        DateTime(2026, 9, 26, hour, minute);
    expect(momentOf(h(4, 59)), BilanMoment.night);
    expect(momentOf(h(5)), BilanMoment.morning);
    expect(momentOf(h(11, 59)), BilanMoment.morning);
    expect(momentOf(h(12)), BilanMoment.afternoon);
    expect(momentOf(h(18)), BilanMoment.evening);
    expect(momentOf(h(22)), BilanMoment.night);
    expect(momentOf(h(0, 30)), BilanMoment.night);
  });
}
