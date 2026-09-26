import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/home/home_model.dart';
import 'package:birdnet_live/fork/home/home_text.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

IndexedDetection det(
  String name,
  int minute, {
  double score = 0.9,
  ReviewStatus review = ReviewStatus.unreviewed,
}) => IndexedDetection(
  key: '$name|$minute',
  sessionId: 's',
  position: minute,
  scientificName: name,
  commonName: name,
  start: DateTime(2026, 9, 26, 7, minute),
  end: null,
  confidence: score,
  reviewStatus: review,
  latitude: 46.7,
  longitude: 1.2,
  clipPath: null,
);

const _plausible = GeoPresence(unexpected: false);

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  setUpAll(() => initializeDateFormatting('fr'));

  group('bestLevel', () {
    test('keeps the most trusted level', () {
      expect(
        bestLevel([ReliabilityLevel.toCheck, ReliabilityLevel.sure]),
        ReliabilityLevel.sure,
      );
      expect(
        bestLevel([ReliabilityLevel.toCheck, ReliabilityLevel.probable]),
        ReliabilityLevel.probable,
      );
      expect(bestLevel(const []), ReliabilityLevel.toCheck);
    });
  });

  group('buildDaySummary', () {
    final today = [
      det('Erithacus rubecula', 13),
      det('Erithacus rubecula', 20),
      det('Dendrocopos major', 26),
      det('Upupa epops', 38, score: 0.58),
      det('Strix aluco', 14, score: 0.71, review: ReviewStatus.confirmed),
    ];
    final presence = {for (final d in today) d.scientificName: _plausible};

    test('counts species and contacts', () {
      final day = buildDaySummary(detections: today, presence: presence);
      expect(day.species, 4);
      expect(day.contacts, 5);
      expect(day.isEmpty, isFalse);
    });

    test('new = never heard before and Sûr or confirmed', () {
      final day = buildDaySummary(
        detections: today,
        presence: presence,
        heardBefore: {'Erithacus rubecula'},
      );
      // Pic épeiche (Sûr), Chouette (confirmed); not the Huppe (to check).
      expect(day.newSpecies, 2);
    });

    test('unknown history or plausibility: nothing new', () {
      expect(buildDaySummary(detections: today).newSpecies, 0);
      expect(
        buildDaySummary(detections: today, heardBefore: const {}).newSpecies,
        1, // only the confirmed Chouette
      );
    });

    test('no detection today', () {
      final day = buildDaySummary(detections: const []);
      expect(day.isEmpty, isTrue);
      expect(day.species, 0);
    });
  });

  group('texts', () {
    test('greeting by hour', () {
      DateTime h(int hour) => DateTime(2026, 9, 26, hour);
      expect(homeGreeting(fr, h(7)), 'Bonjour');
      expect(homeGreeting(fr, h(14)), 'Bon après-midi');
      expect(homeGreeting(fr, h(19)), 'Bonsoir');
      expect(homeGreeting(fr, h(23)), 'Bonne nuit');
    });

    test('date line', () {
      final now = DateTime(2026, 9, 26, 8, 5);
      expect(homeDateLine('fr', now), 'Samedi 26 septembre');
      expect(
        homeDateLine('fr', now, place: 'Beaulieu-sur-Brenne'),
        'Samedi 26 septembre · Beaulieu-sur-Brenne',
      );
    });

    test('when the last bird was heard', () {
      final now = DateTime(2026, 9, 26, 8, 5);
      expect(
        homeHeardWhen(fr, 'fr', DateTime(2026, 9, 26, 7, 52), now),
        '7 h 52',
      );
      expect(
        homeHeardWhen(fr, 'fr', DateTime(2026, 9, 25, 19, 3), now),
        'hier, 19 h 03',
      );
      expect(
        homeHeardWhen(fr, 'fr', DateTime(2026, 9, 24, 7, 30), now),
        '24 sept., 7 h 30',
      );
      // Across the spring clock change (a 23-hour day).
      expect(
        homeHeardWhen(
          fr,
          'fr',
          DateTime(2026, 3, 28, 7),
          DateTime(2026, 3, 29, 8),
        ),
        'hier, 7 h 00',
      );
    });
  });
}
