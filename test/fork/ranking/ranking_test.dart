import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/ranking/ranking_logic.dart';
import 'package:birdnet_live/fork/ranking/ranking_screen.dart';
import 'package:birdnet_live/fork/ranking/species_activity_section.dart';
import 'package:birdnet_live/l10n/app_localizations_en.dart';
import 'package:birdnet_live/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LiveSession _fixture(String name) => LiveSession.fromJson(
  jsonDecode(File('test/fork/fixtures/$name').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  sqfliteFfiInit();

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('periodRange', () {
    final now = DateTime(2026, 9, 26, 10);

    test('30 days, year and all', () {
      expect(
        periodRange(RankingPeriod.last30Days, now).from,
        DateTime(2026, 8, 27, 10),
      );
      expect(periodRange(RankingPeriod.year, now).from, DateTime(2026));
      expect(periodRange(RankingPeriod.all, now).from, isNull);
    });

    test('meteorological seasons, winter across the new year', () {
      DateTime? season(int month) =>
          periodRange(RankingPeriod.season, DateTime(2026, month, 15)).from;
      expect(season(3), DateTime(2026, 3));
      expect(season(5), DateTime(2026, 3));
      expect(season(6), DateTime(2026, 6));
      expect(season(9), DateTime(2026, 9));
      expect(season(11), DateTime(2026, 9));
      expect(season(12), DateTime(2026, 12));
      expect(season(1), DateTime(2025, 12));
      expect(season(2), DateTime(2025, 12));
    });
  });

  test('relative day and short time', () {
    final now = DateTime(2026, 9, 26, 10);
    expect(relativeDay(DateTime(2026, 9, 26, 6), now), 0);
    expect(relativeDay(DateTime(2026, 9, 25, 23), now), 1);
    expect(relativeDay(DateTime(2026, 9, 20), now), isNull);
    expect(shortTime(DateTime(2026, 9, 26, 7, 5), 'fr'), '7 h 05');
    expect(shortTime(DateTime(2026, 9, 26, 7, 5), 'en'), '7:05');
  });

  test('heard sentence in French and English', () {
    final now = DateTime(2026, 9, 26, 10);
    expect(
      heardSentence(
        AppLocalizationsFr(),
        'fr',
        contacts: 23,
        days: 9,
        last: DateTime(2026, 9, 25, 7, 42),
        now: now,
      ),
      'Entendu 23 fois sur 9 jours, la dernière fois hier à 7 h 42.',
    );
    expect(
      heardSentence(
        AppLocalizationsEn(),
        'en',
        contacts: 1,
        days: 1,
        last: DateTime(2026, 9, 26, 7, 42),
        now: now,
      ),
      'Heard once over 1 day, the last time today at 7:42.',
    );
  });

  group('index queries of the palmarès', () {
    late ObservationIndex index;

    setUp(() async {
      index = await ObservationIndex.open(
        databaseFactoryFfi,
        inMemoryDatabasePath,
      );
      await index.rebuild([
        _fixture('session_2026-09-20.json'),
        _fixture('session_2026-09-21.json'),
      ]);
    });

    tearDown(() => index.close());

    test('species tally and first heard since', () async {
      final robin = await index.speciesTally('Erithacus rubecula');
      expect(robin!.contacts, 3);
      expect(await index.speciesTally('Turdus merula'), isNull); // rejected
      expect(await index.speciesFirstHeardSince(DateTime.utc(2026, 9, 21)), {
        'Strix aluco',
      });
      expect(
        (await index.speciesFirstHeardSince(DateTime.utc(2026))).length,
        4,
      );
    });

    test('ranking value follows the order', () async {
      final tally = (await index.speciesRanking()).first;
      expect(rankingValue(tally, RankingOrder.contacts), tally.contacts);
      expect(rankingValue(tally, RankingOrder.days), tally.days);
    });
  });
}
