/// Pure helpers of the palmarès (fork/PLAN.md J4).
library;

/// Periods of the palmarès.
enum RankingPeriod { last30Days, season, year, all }

/// `[from, to)` of [period] around [now] (local time); nulls mean open.
///
/// Seasons are meteorological: spring March–May, summer June–August,
/// autumn September–November, winter December–February.
({DateTime? from, DateTime? to}) periodRange(
  RankingPeriod period,
  DateTime now,
) {
  final local = now.toLocal();
  switch (period) {
    case RankingPeriod.last30Days:
      return (from: local.subtract(const Duration(days: 30)), to: null);
    case RankingPeriod.year:
      return (from: DateTime(local.year), to: null);
    case RankingPeriod.all:
      return (from: null, to: null);
    case RankingPeriod.season:
      final m = local.month;
      if (m <= 2) return (from: DateTime(local.year - 1, 12), to: null);
      final startMonth = m == 12 ? 12 : m - (m % 3);
      return (from: DateTime(local.year, startMonth), to: null);
  }
}

/// Day word for "la dernière fois …": 0 = today, 1 = yesterday, else null.
int? relativeDay(DateTime last, DateTime now) {
  final a = DateTime(last.year, last.month, last.day);
  final b = DateTime(now.year, now.month, now.day);
  final days = b.difference(a).inDays;
  return days == 0 || days == 1 ? days : null;
}

/// Time of day as French people write it ("7 h 42") or "7:42" otherwise.
String shortTime(DateTime time, String languageCode) {
  final minutes = time.minute.toString().padLeft(2, '0');
  return languageCode == 'fr'
      ? '${time.hour} h $minutes'
      : '${time.hour}:$minutes';
}
