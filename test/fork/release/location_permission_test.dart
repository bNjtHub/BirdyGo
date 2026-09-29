import 'dart:io';

import 'package:birdnet_live/features/survey/survey_setup_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// First release: no "Allow all the time" location. Screen-off GPS relies on
/// "while in use" plus the foreground service of type location.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('manifest does not declare background location', () {
    final xml = manifest.readAsStringSync();
    // Comments may mention the name; only a real declaration counts.
    final declared = RegExp(
      r'<uses-permission[^>]*ACCESS_BACKGROUND_LOCATION',
    ).hasMatch(xml);
    expect(declared, isFalse);
  });

  test('foreground service keeps location and microphone types', () {
    final xml = manifest.readAsStringSync();
    expect(xml, contains('FOREGROUND_SERVICE_LOCATION'));
    expect(xml, contains('FOREGROUND_SERVICE_MICROPHONE'));
    expect(xml, contains('foregroundServiceType="microphone|location"'));
  });

  test('survey treats "while in use" as enough GPS permission', () {
    expect(hasSurveyGpsPermission(LocationPermission.whileInUse), isTrue);
    expect(hasSurveyGpsPermission(LocationPermission.always), isTrue);
    expect(hasSurveyGpsPermission(LocationPermission.denied), isFalse);
    expect(hasSurveyGpsPermission(LocationPermission.deniedForever), isFalse);
  });

  test('app code never escalates to "Always" nor opens the Always prompt', () {
    // Requests are only Geolocator.requestPermission(), which on Android
    // 11+ can only grant "while in use". Guard against a permission_handler
    // locationAlways request slipping in.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('l10n')) continue;
      final src = entity.readAsStringSync();
      if (src.contains('Permission.locationAlways')) offenders.add(entity.path);
    }
    expect(offenders, isEmpty);
  });
}
