/// Offsets of the day's listening moments around sunrise and sunset (J6h,
/// « Ta journée d'écoute »). Used by [DayTimes].
library;

abstract final class DayTimesConfig {
  /// Golden hour starts this long before sunset.
  static const Duration goldenHourBeforeSunset = Duration(minutes: 45);

  /// Morning birds: from this long before sunrise...
  static const Duration morningBeforeSunrise = Duration(minutes: 45);

  /// ... to this long after it.
  static const Duration morningAfterSunrise = Duration(minutes: 55);

  /// Evening birds: from this long before sunset...
  static const Duration eveningBeforeSunset = Duration(minutes: 30);

  /// ... to this long after it.
  static const Duration eveningAfterSunset = Duration(minutes: 30);
}
