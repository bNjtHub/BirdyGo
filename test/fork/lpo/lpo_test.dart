import 'package:birdnet_live/features/announcements/domain/announcement_signals.dart';
import 'package:birdnet_live/features/announcements/geo_commonness_provider.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/lpo/atlas_codes.dart';
import 'package:birdnet_live/fork/lpo/lpo_observation.dart';
import 'package:birdnet_live/fork/lpo/lpo_report.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 5, 16, 5, 30);

Map<String, dynamic> _det(
  String sci,
  int minute, {
  String? review,
  double lat = 47.2101,
  double lon = -1.5502,
  double confidence = 0.9,
  String? clip,
  String? source,
}) => {
  'scientificName': sci,
  'commonName': sci,
  'confidence': confidence,
  'timestamp': _start.add(Duration(minutes: minute)).toIso8601String(),
  'detLat': lat,
  'detLon': lon,
  if (review != null) 'reviewStatus': review,
  if (clip != null) 'audioClipPath': clip,
  if (source != null) 'source': source,
};

LiveSession _session(List<Map<String, dynamic>> detections) =>
    LiveSession.fromJson({
      'id': 's1',
      'startTime': _start.toIso8601String(),
      'endTime': _start.add(const Duration(hours: 1)).toIso8601String(),
      'latitude': 47.21,
      'longitude': -1.55,
      'detections': detections,
      'gpsTrack': [
        {
          'lat': 47.2101,
          'lon': -1.5502,
          'acc': 12.4,
          't': _start.add(const Duration(minutes: 2)).toIso8601String(),
          'm': true,
        },
      ],
    });

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  group('eligibility', () {
    test('only confirmed detections become observations', () {
      final session = _session([
        _det('Erithacus rubecula', 1),
        _det('Turdus merula', 2, review: 'rejected'),
        _det('Parus major', 3, review: 'confirmed'),
        _det('Upupa epops', 4, confidence: 0.99),
      ]);
      final observations = lpoObservations(session);
      expect(observations.map((o) => o.scientificName), ['Parus major']);
      for (final d in session.detections) {
        expect(lpoEligible(d), d.reviewStatus == ReviewStatus.confirmed);
      }
    });

    test('a working copy of the detections is used when given', () {
      final session = _session([_det('Parus major', 3, review: 'confirmed')]);
      expect(lpoObservations(session, detections: const []), isEmpty);
    });
  });

  group('grouping', () {
    test('one observation per species and place, oldest first', () {
      final session = _session([
        _det(
          'Parus major',
          9,
          review: 'confirmed',
          clip: '/c/low.wav',
          confidence: 0.7,
        ),
        _det(
          'Parus major',
          3,
          review: 'confirmed',
          clip: '/c/high.wav',
          confidence: 0.95,
        ),
        _det('Parus major', 20, review: 'confirmed', lat: 47.2301),
        _det('Sitta europaea', 5, review: 'confirmed'),
      ]);
      final observations = lpoObservations(session);
      expect(observations.map((o) => o.scientificName), [
        'Parus major',
        'Sitta europaea',
        'Parus major',
      ]);
      final first = observations.first;
      expect(first.records, hasLength(2));
      expect(first.time, _start.add(const Duration(minutes: 3)));
      expect(first.clipPath, '/c/high.wav');
      expect(first.accuracyMeters, 12.4);
      expect(first.aiAssisted, isTrue);
      // 20 minutes after the only GPS fix: no accuracy.
      expect(observations.last.accuracyMeters, isNull);
    });

    test('a detection added by hand is not AI-assisted', () {
      final session = _session([
        _det('Parus major', 3, review: 'confirmed', source: 'manual'),
      ]);
      expect(lpoObservations(session).single.aiAssisted, isFalse);
    });
  });

  group('alerts', () {
    test('sensitive species', () {
      expect(lpoAlerts('Bubo bubo', null), {LpoAlert.sensitive});
      expect(lpoAlerts('Parus major', null), isEmpty);
    });

    test('rare and out of season from geoCommonnessProvider', () {
      const map = {
        'Upupa epops': GeoCommonnessEntry(
          commonness: CommonnessBin.rare,
          isOutOfSeason: true,
          currentScore: 0.01,
          annualMax: 0.2,
        ),
        'Parus major': GeoCommonnessEntry(
          commonness: CommonnessBin.abundant,
          isOutOfSeason: false,
          currentScore: 0.9,
          annualMax: 0.9,
        ),
      };
      expect(
        lpoAlerts('Upupa epops', geoStatusFromCommonness(map, 'Upupa epops')),
        {LpoAlert.rare, LpoAlert.outOfSeason},
      );
      expect(
        lpoAlerts('Parus major', geoStatusFromCommonness(map, 'Parus major')),
        isEmpty,
      );
      // Not expected here at all.
      expect(geoStatusFromCommonness(map, 'Merops apiaster')!.rare, isTrue);
      expect(geoStatusFromCommonness(null, 'Upupa epops'), isNull);
      expect(geoStatusFromCommonness(const {}, 'Upupa epops'), isNull);
    });

    test('rare from the presence at the observation place', () {
      expect(
        lpoAlerts(
          'Upupa epops',
          geoStatusFromPresence(const GeoPresence(unexpected: true)),
        ),
        {LpoAlert.rare},
      );
      expect(geoStatusFromPresence(null), isNull);
    });

    test('here and now: same geo-model week and close to the phone', () {
      final o =
          lpoObservations(
            _session([_det('Parus major', 3, review: 'confirmed')]),
          ).single;
      bool hereAndNow({double lat = 47.25, DateTime? now}) => isHereAndNow(
        o,
        hereLatitude: lat,
        hereLongitude: -1.55,
        now: now ?? _start.add(const Duration(hours: 2)),
      );
      expect(hereAndNow(), isTrue);
      expect(hereAndNow(lat: 47.5), isFalse); // ~32 km away
      expect(hereAndNow(now: _start.add(const Duration(days: 10))), isFalse);
      expect(
        isHereAndNow(o, hereLatitude: null, hereLongitude: null, now: _start),
        isFalse,
      );
    });
  });

  group('atlas codes', () {
    test('only during the breeding period of a known species', () {
      expect(atlasCodesFor('Parus major', DateTime(2026, 5, 16)), [
        AtlasCode.singingMale,
        AtlasCode.presentInHabitat,
      ]);
      expect(atlasCodesFor('Parus major', DateTime(2026, 9, 26)), isEmpty);
      expect(atlasCodesFor('Apus apus', DateTime(2026, 4, 20)), isEmpty);
      expect(atlasCodesFor('Unknown species', DateTime(2026, 5, 16)), isEmpty);
      // Bounds included.
      expect(inBreedingPeriod('Strix aluco', DateTime(2026, 1, 15)), isTrue);
      expect(inBreedingPeriod('Strix aluco', DateTime(2026, 6, 30)), isTrue);
      expect(inBreedingPeriod('Strix aluco', DateTime(2026, 7, 1)), isFalse);
    });

    test('a window across the new year', () {
      const winter = BreedingPeriod(12, 1, 2, 28);
      expect(winter.contains(DateTime(2026, 12, 24)), isTrue);
      expect(winter.contains(DateTime(2026, 1, 10)), isTrue);
      expect(winter.contains(DateTime(2026, 6, 1)), isFalse);
    });
  });

  group('report', () {
    test('carries the fields and the remark of SPEC 7.7', () {
      final o =
          lpoObservations(
            _session([_det('Parus major', 3, review: 'confirmed')]),
          ).single;
      final text = lpoReportText(
        fr,
        o,
        frenchName: 'Mésange charbonnière',
        choices: const LpoCardChoices(
          seen: false,
          count: 2,
          atlasCode: AtlasCode.singingMale,
        ),
      );
      final time = DateTime.utc(2026, 5, 16, 5, 33).toLocal();
      final hh = time.hour.toString().padLeft(2, '0');
      final mm = time.minute.toString().padLeft(2, '0');
      expect(
        text,
        'Espèce : Mésange charbonnière (Parus major)\n'
        'Date : ${time.day.toString().padLeft(2, '0')}/05/2026\n'
        'Heure : $hh:$mm\n'
        'Position : 47.21010, -1.55020 (précision ± 12 m)\n'
        'Nombre : 2\n'
        'Contact : entendu\n'
        'Code atlas : 3 – mâle chanteur en période de nidification\n'
        'Remarque : Contact auditif ; identification assistée par IA puis '
        "confirmée par l'observateur.",
      );
    });

    test('seen, hidden, without position', () {
      final session = LiveSession.fromJson({
        'id': 's2',
        'startTime': _start.toIso8601String(),
        'detections': [
          {
            'scientificName': 'Bubo bubo',
            'commonName': 'Grand-duc',
            'confidence': 0.9,
            'timestamp': _start.toIso8601String(),
            'reviewStatus': 'confirmed',
          },
        ],
      });
      final lines = lpoReportLines(
        fr,
        lpoObservations(session).single,
        frenchName: "Grand-duc d'Europe",
        choices: const LpoCardChoices(seen: true, hideData: true),
      );
      expect(lines, contains('Position : inconnue'));
      expect(lines, contains('Contact : entendu et vu'));
      expect(lines, contains('Donnée à masquer : oui (espèce sensible)'));
      expect(lines.last, contains('Contact auditif et visuel'));
      expect(lines.any((l) => l.startsWith('Code atlas')), isFalse);
    });
  });
}
