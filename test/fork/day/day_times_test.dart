import 'package:birdnet_live/fork/day/day_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sunrise = DateTime(2026, 9, 29, 7, 30);
  final sunset = DateTime(2026, 9, 29, 19, 30);

  test('offsets around sunrise and sunset', () {
    final t = DayTimes(sunrise: sunrise, sunset: sunset);
    expect(t.goldenHour, DateTime(2026, 9, 29, 18, 45));
    expect(t.morningBirds.start, DateTime(2026, 9, 29, 6, 45));
    expect(t.morningBirds.end, DateTime(2026, 9, 29, 8, 25));
    expect(t.eveningBirds.start, DateTime(2026, 9, 29, 19, 0));
    expect(t.eveningBirds.end, DateTime(2026, 9, 29, 20, 0));
  });

  test('missing or inverted times give null', () {
    expect(DayTimes.tryCreate(sunrise: sunrise), isNull);
    expect(DayTimes.tryCreate(sunset: sunset), isNull);
    expect(DayTimes.tryCreate(sunrise: sunset, sunset: sunrise), isNull);
    expect(DayTimes.tryCreate(sunrise: sunrise, sunset: sunset), isNotNull);
  });
}
