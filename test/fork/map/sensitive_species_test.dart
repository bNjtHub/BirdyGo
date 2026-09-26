import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/map/map_config.dart';
import 'package:birdnet_live/fork/map/sensitive_species.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LiveSession _session(List<(String, double?, double?)> detections) =>
    LiveSession.fromJson({
      'id': 's1',
      'startTime': '2026-09-20T05:10:00.000Z',
      'endTime': '2026-09-20T05:55:00.000Z',
      'latitude': 47.2101,
      'longitude': -1.5502,
      'gpsTrack': [
        {'lat': 47.2101, 'lon': -1.5502, 't': '2026-09-20T05:10:00.000Z'},
      ],
      'detections': [
        for (final (name, lat, lon) in detections)
          {
            'scientificName': name,
            'commonName': name,
            'confidence': 0.9,
            'timestamp': '2026-09-20T05:12:00.000Z',
            if (lat != null) 'detLat': lat,
            if (lon != null) 'detLon': lon,
          },
      ],
    });

void main() {
  test('a blurred coordinate snaps to the center of its grid cell', () {
    expect(blurDegrees(47.2101), closeTo(47.25, 1e-9));
    expect(blurDegrees(47.2999), closeTo(47.25, 1e-9));
    expect(blurDegrees(-1.5502), closeTo(-1.55, 1e-9));
    expect(
      (blurDegrees(47.2101) - 47.2101).abs(),
      lessThanOrEqualTo(kSensitiveBlurDegrees / 2),
    );
  });

  test('sessions without a sensitive species are left untouched', () {
    final session = _session([('Erithacus rubecula', 47.2101, -1.5502)]);
    expect(identical(blurSensitivePositions(session), session), isTrue);
  });

  test('a sensitive species blurs its own position and the session trail, '
      'not the other species', () {
    final session = _session([
      ('Erithacus rubecula', 47.2101, -1.5502),
      ('Bubo bubo', 47.2105, -1.5507),
    ]);
    final blurred = blurSensitivePositions(session);
    expect(blurred.detections[0].latitude, 47.2101);
    expect(blurred.detections[0].longitude, -1.5502);
    expect(blurred.detections[1].latitude, closeTo(47.25, 1e-9));
    expect(blurred.detections[1].longitude, closeTo(-1.55, 1e-9));
    expect(blurred.latitude, closeTo(47.25, 1e-9));
    expect(blurred.longitude, closeTo(-1.55, 1e-9));
    expect(blurred.gpsTrack.single.latitude, closeTo(47.25, 1e-9));
    // The original session is not modified.
    expect(session.detections[1].latitude, 47.2105);
  });

  test('the export hook follows the option, on by default', () async {
    final session = _session([('Bubo bubo', 47.2105, -1.5507)]);
    SharedPreferences.setMockInitialValues({});
    expect(
      (await applyExportPrivacy(session)).detections.single.latitude,
      closeTo(47.25, 1e-9),
    );
    SharedPreferences.setMockInitialValues({kBlurSensitiveExportPref: false});
    expect(
      (await applyExportPrivacy(session)).detections.single.latitude,
      47.2105,
    );
  });
}
