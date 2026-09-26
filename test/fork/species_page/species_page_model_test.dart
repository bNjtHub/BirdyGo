import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/species_page/species_page_model.dart';
import 'package:birdnet_live/fork/species_page/species_page_text.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// 48 weeks: [present] months at 0.5, the others at 0.
List<double> _weeks(Set<int> present, {double score = 0.5}) => [
  for (var w = 0; w < 48; w++) present.contains(w ~/ 4 + 1) ? score : 0.0,
];

IndexedDetection _clip(
  String key, {
  double score = 0.9,
  double? lat = 46.7,
  double? lon = 1.2,
}) => IndexedDetection(
  key: key,
  sessionId: 's',
  position: 0,
  scientificName: 'Erithacus rubecula',
  commonName: 'Rougegorge familier',
  start: DateTime(2026, 9, 26, 7, 41),
  end: null,
  confidence: score,
  reviewStatus: ReviewStatus.unreviewed,
  latitude: lat,
  longitude: lon,
  clipPath: '/clips/$key.wav',
);

void main() {
  late AppLocalizations fr;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    fr = lookupAppLocalizations(const Locale('fr'));
  });

  group('YearPresence', () {
    test('a month takes its best week', () {
      final weeks =
          List<double>.filled(48, 0)
            ..[4] = 0.1
            ..[7] = 0.4;
      final year = YearPresence.fromWeeks(weeks);
      expect(year.months[1], 0.4);
      expect(year.months[0], 0);
      expect(year.bars[1], 1);
    });

    test('48 weeks or nothing', () {
      expect(() => YearPresence.fromWeeks([0.1, 0.2]), throwsArgumentError);
    });

    test('spans', () {
      PresenceSpan span(Set<int> months) =>
          YearPresence.fromWeeks(_weeks(months)).span;
      expect(
        span({for (var m = 1; m <= 12; m++) m}),
        const PresenceSpan.allYear(),
      );
      expect(span({}), const PresenceSpan.rare());
      expect(span({3, 4, 5, 6, 7, 8, 9}), const PresenceSpan.range(3, 9));
      // Wintering birds: across the new year.
      expect(span({11, 12, 1, 2}), const PresenceSpan.range(11, 2));
      expect(span({4, 5, 9, 10}), const PresenceSpan.partOfYear());
    });

    test('below the Explore threshold is absent', () {
      final year = YearPresence.fromWeeks(_weeks({5}, score: 0.01));
      expect(year.span, const PresenceSpan.rare());
    });
  });

  group('presence sentence', () {
    String sentence(Set<int> months, DateTime now) => presenceSentence(
      fr,
      'fr',
      YearPresence.fromWeeks(_weeks(months)),
      now: now,
    );

    test('all year', () {
      expect(
        sentence({for (var m = 1; m <= 12; m++) m}, DateTime(2026, 9)),
        "Présent toute l'année.",
      );
    });

    test('a season, and whether it is now', () {
      expect(
        sentence({3, 4, 5, 6, 7, 8, 9}, DateTime(2026, 6)),
        'Présent de mars à septembre.',
      );
      expect(
        sentence({3, 4, 5, 6, 7, 8, 9}, DateTime(2026, 12)),
        'Présent de mars à septembre. Pas attendu ici en ce moment.',
      );
    });

    test('elision before a vowel', () {
      expect(
        sentence({4, 5, 6, 7, 8}, DateTime(2026, 6)),
        "Présent d'avril à août.",
      );
    });

    test('rare here', () {
      expect(sentence({}, DateTime(2026, 6)), 'Rarement attendu ici.');
    });

    test('months caption', () {
      expect(monthsCaption('fr'), 'janv. – déc.');
    });
  });

  test('chips follow the mockup order and skip empty sections', () {
    final sheet = SpeciesSheet.fromJson({
      'name': 'Rougegorge familier',
      'summary': 'Petit oiseau.',
      'size': '14 cm.',
      'migration': 'Reste.',
      'anecdote': 'Chante la nuit.',
      'by_ear': 'Un filet de notes.',
      'confusions': '',
    });
    expect(sheetChips(sheet), [
      SheetSection.size,
      SheetSection.migration,
      SheetSection.anecdote,
      SheetSection.byEar,
    ]);
  });

  test('page clips: favorites first, then best scores, limited', () {
    final clips = [_clip('a', score: 0.97), _clip('b'), _clip('c'), _clip('d')];
    expect(pageClips(clips, {'c'}, limit: 3).map((c) => c.key), [
      'c',
      'a',
      'b',
    ]);
  });

  test('distinct spots', () {
    final spots = distinctSpots(
      [
        _clip('a', lat: 46.70001, lon: 1.20001),
        _clip('b', lat: 46.70002, lon: 1.20002),
        _clip('c', lat: null, lon: null),
        _clip('d', lat: 46.8, lon: 1.3),
        _clip('e', lat: 46.9, lon: 1.4),
      ],
      limit: 2,
      decimals: 3,
    );
    expect(spots, [
      (latitude: 46.70001, longitude: 1.20001),
      (latitude: 46.8, longitude: 1.3),
    ]);
  });

  test('clip line', () {
    expect(
      clipLine(
        fr,
        'fr',
        _clip('a', score: 0.97),
        now: DateTime(2026, 9, 26, 12),
      ),
      "0,97 · aujourd'hui à 7 h 41",
    );
  });

  test('share text, never a place', () {
    expect(
      speciesShareText(
        name: 'Rougegorge familier',
        latin: 'Erithacus rubecula',
        heard: 'Entendu 3 fois sur 2 jours.',
      ),
      'Rougegorge familier (Erithacus rubecula)\nEntendu 3 fois sur 2 jours.',
    );
    expect(
      speciesShareText(name: 'Rougegorge familier'),
      'Rougegorge familier',
    );
  });
}
