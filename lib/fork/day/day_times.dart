/// The moments of a listening day, from sunrise and sunset (J6h). Pure: the
/// caller supplies the two times (null at the poles or without a position).
library;

import 'day_times_config.dart';

typedef TimeSpan = ({DateTime start, DateTime end});

class DayTimes {
  const DayTimes({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;

  /// Null when either time is unknown, or the sun does not set that day.
  static DayTimes? tryCreate({DateTime? sunrise, DateTime? sunset}) =>
      sunrise == null || sunset == null || !sunset.isAfter(sunrise)
          ? null
          : DayTimes(sunrise: sunrise, sunset: sunset);

  DateTime get goldenHour =>
      sunset.subtract(DayTimesConfig.goldenHourBeforeSunset);

  TimeSpan get morningBirds => (
    start: sunrise.subtract(DayTimesConfig.morningBeforeSunrise),
    end: sunrise.add(DayTimesConfig.morningAfterSunrise),
  );

  TimeSpan get eveningBirds => (
    start: sunset.subtract(DayTimesConfig.eveningBeforeSunset),
    end: sunset.add(DayTimesConfig.eveningAfterSunset),
  );
}
