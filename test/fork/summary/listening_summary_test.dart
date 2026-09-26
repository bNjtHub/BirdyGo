import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/summary/listening_summary.dart';
import 'package:birdnet_live/fork/summary/listening_summary_loader.dart';
import 'package:birdnet_live/fork/summary/listening_summary_view.dart';
import 'package:birdnet_live/fork/summary/summary_text.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'summary_fixture.dart';

ListeningSummary _morning({LiveSession? session}) => ListeningSummary.of(
  session ?? morningSession(),
  verifiedBefore: verifiedBeforeMorning,
  presence: morningPresence,
);

void main() {
  sqfliteFfiInit();
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('ListeningSummary', () {
    test('counts the morning of the mockup', () {
      final s = _morning();
      expect(s.species, hasLength(13));
      expect(s.contacts, 52);
      expect(s.duration, const Duration(minutes: 42));
      expect(s.dayPart, DayPart.morning);
    });

    test('lists the species most heard first, ties by first contact', () {
      expect(_morning().species.map((s) => s.commonName), [
        'Rougegorge familier',
        'Troglodyte mignon',
        'Merle noir',
        'Mésange charbonnière',
        'Mésange bleue',
        'Pinson des arbres',
        'Pie bavarde',
        'Pouillot véloce',
        'Moineau domestique',
        'Pic épeiche',
        'Chouette hulotte',
        "Martin-pêcheur d'Europe",
        'Huppe fasciée',
      ]);
    });

    test('the Pic épeiche is a first time, the 24th species, at 7 h 26', () {
      final s = _morning();
      expect(s.firstTimes, hasLength(1));
      final first = s.firstTimes.single;
      expect(first.species.commonName, 'Pic épeiche');
      expect(first.rank, 24);
      expect(first.species.verifiedAt!.toLocal(), DateTime(2026, 9, 26, 7, 26));
    });

    test('the Huppe, unexpected here, is maybe a first', () {
      final s = _morning();
      final huppe = s.maybeFirsts.single;
      expect(huppe.commonName, 'Huppe fasciée');
      expect(huppe.level, ReliabilityLevel.toCheck);
      expect(huppe.unexpected, isTrue);
    });

    test('three detections to check: Chouette, Martin-pêcheur, Huppe', () {
      final s = _morning();
      expect(s.keysToCheck, hasLength(3));
      expect(s.species.where((x) => x.pending).map((x) => x.commonName), [
        'Chouette hulotte',
        "Martin-pêcheur d'Europe",
        'Huppe fasciée',
      ]);
      // The Pouillot's first contact is Probable, but the species is Sûr.
      final pouillot = s.species.firstWhere(
        (x) => x.scientificName == 'Phylloscopus collybita',
      );
      expect(pouillot.level, ReliabilityLevel.sure);
      expect(pouillot.keysToCheck, isEmpty);
    });

    test('rejected and unknown detections do not count', () {
      final s = _morning(
        session: morningSession(
          extra: [
            extraDetection('Bubo bubo', 40, review: 'rejected'),
            extraDetection(DetectionRecord.unknownSpeciesName, 41),
          ],
        ),
      );
      expect(s.species, hasLength(13));
      expect(s.contacts, 52);
    });

    test('a confirmed detection makes a first time, even when rare', () {
      final s = _morning(
        session: morningSession(
          extra: [extraDetection('Upupa epops', 45, review: 'confirmed')],
        ),
      );
      expect(s.maybeFirsts, isEmpty);
      expect(s.firstTimes.map((f) => (f.species.scientificName, f.rank)), [
        ('Dendrocopos major', 24),
        ('Upupa epops', 25),
      ]);
      // The unreviewed contact of a species now « Sûr » needs no check.
      expect(s.keysToCheck, hasLength(2));
    });

    test('without the geo-model, a high score stays Probable', () {
      final s = ListeningSummary.of(
        morningSession(),
        verifiedBefore: verifiedBeforeMorning,
      );
      expect(s.firstTimes, isEmpty);
      expect(s.maybeFirsts.map((x) => x.commonName), [
        'Pic épeiche',
        'Huppe fasciée',
      ]);
      expect(s.species.every((x) => x.pending), isTrue);
    });

    test('an empty session', () {
      final s = ListeningSummary.of(
        LiveSession.fromJson({
          'id': 'empty',
          'startTime': morningStart.toUtc().toIso8601String(),
          'endTime':
              morningStart
                  .add(const Duration(minutes: 5))
                  .toUtc()
                  .toIso8601String(),
        }),
        verifiedBefore: const {},
      );
      expect(s.isEmpty, isTrue);
      expect(s.contacts, 0);
      expect(s.keysToCheck, isEmpty);
    });

    test('parts of the day', () {
      expect(dayPartOf(DateTime(2026, 9, 26, 4, 59)), DayPart.night);
      expect(dayPartOf(DateTime(2026, 9, 26, 5)), DayPart.morning);
      expect(dayPartOf(DateTime(2026, 9, 26, 12)), DayPart.afternoon);
      expect(dayPartOf(DateTime(2026, 9, 26, 18)), DayPart.evening);
      expect(dayPartOf(DateTime(2026, 9, 26, 22)), DayPart.night);
    });
  });

  group('texts', () {
    test('headline, duration and caption', () {
      final s = _morning();
      expect(summaryHeadline(fr, s), 'Belle matinée !');
      expect(summaryHeadline(en, s), 'Lovely morning!');
      expect(summaryDuration(fr, const Duration(minutes: 42)), '42 min');
      expect(summaryDuration(fr, const Duration(minutes: 65)), '1 h 05');
      expect(summaryDuration(en, const Duration(minutes: 65)), '1 h 05 min');
      expect(
        summaryCaption(fr, s, place: 'Beaulieu-sur-Brenne'),
        'Samedi 26 septembre · 07:12 – 07:54 · Beaulieu-sur-Brenne',
      );
    });

    test('novelties heading', () {
      expect(noveltiesHeading(fr, _morning()), 'Une nouvelle, peut-être deux');
      expect(
        noveltiesHeading(
          fr,
          ListeningSummary.of(
            morningSession(),
            verifiedBefore: verifiedBeforeMorning,
          ),
        ),
        'Peut-être 2 nouvelles espèces',
      );
    });

    test('the shared text names verified species only, never the place', () {
      final text = summaryShareText(
        fr,
        _morning(),
        nameOf: (s) => s.commonName,
      );
      expect(text, startsWith('Belle matinée !\n13 espèces et 52 contacts'));
      expect(text, contains('Rougegorge familier ×9'));
      expect(text, contains('Pic épeiche ×2'));
      expect(text, isNot(contains('Huppe')));
      expect(text, contains('Et 3 espèces encore à vérifier.'));
      expect(text, isNot(contains('46.7')));
    });
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

    LiveSession older() => LiveSession.fromJson({
      'id': 'older',
      'startTime': DateTime(2026, 9, 20, 7).toUtc().toIso8601String(),
      'detections': [
        for (final (sci, score, review) in [
          ('Erithacus rubecula', 0.95, null),
          ('Strix aluco', 0.40, 'confirmed'),
          ('Alcedo atthis', 0.60, null),
          ('Upupa epops', 0.99, 'rejected'),
        ])
          {
            'scientificName': sci,
            'commonName': sci,
            'confidence': score,
            'timestamp': DateTime(2026, 9, 20, 7, 5).toUtc().toIso8601String(),
            if (review != null) 'reviewStatus': review,
          },
      ],
    });

    test('verifiedSpecies: confirmed or high score, other sessions', () async {
      await index.upsertSession(older());
      await index.upsertSession(morningSession());
      final verified = await index.verifiedSpecies(
        minScore: ReliabilityConfig.sureMinScore,
        excludeSessionId: 'morning',
      );
      expect(verified, {'Erithacus rubecula', 'Strix aluco'});
    });

    test('reviewQueue narrowed to some keys', () async {
      final session = morningSession();
      await index.upsertSession(session);
      final keys = _morning(session: session).keysToCheck;
      final queue = await index.reviewQueue(onlyKeys: keys);
      expect(queue.map((d) => d.key).toSet(), keys);
      expect(await index.reviewQueue(onlyKeys: const {}), isEmpty);
    });

    test('loadListeningSummary indexes the session first', () async {
      await index.upsertSession(older());
      final summary = await loadListeningSummary(
        session: morningSession(),
        index: index,
        presenceOf: (name) async => morningPresence(name),
      );
      expect((await index.counts()).sessions, 2);
      // Only the Rougegorge and the Chouette were verified before.
      expect(summary.firstTimes.first.rank, 3);
      expect(summary.firstTimes, hasLength(9));
      expect(summary.maybeFirsts.map((s) => s.commonName), [
        "Martin-pêcheur d'Europe",
        'Huppe fasciée',
      ]);
    });
  });
}
