import 'package:birdnet_live/features/live/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

SessionSettings _settings({String? mode}) => SessionSettings(
  windowDuration: 3,
  confidenceThreshold: 25,
  inferenceRate: 1,
  speciesFilterMode: 'off',
  listeningMode: mode,
);

void main() {
  test('the listening mode round-trips through the session JSON', () {
    final json = _settings(mode: 'wind').toJson();
    expect(json['listeningMode'], 'wind');
    expect(SessionSettings.fromJson(json).listeningMode, 'wind');
  });

  test('no mode: the key is absent and reads back as null', () {
    final json = _settings().toJson();
    expect(json.containsKey('listeningMode'), isFalse);
    expect(SessionSettings.fromJson(json).listeningMode, isNull);
  });

  test('an old session JSON without the key still loads', () {
    final s = SessionSettings.fromJson({
      'windowDuration': 3,
      'confidenceThreshold': 25,
      'inferenceRate': 1.0,
      'speciesFilterMode': 'off',
    });
    expect(s.listeningMode, isNull);
    expect(s.windowDuration, 3);
  });
}
