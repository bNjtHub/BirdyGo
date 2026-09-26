/// Rows of the live table (J6c): one per species heard during the outing,
/// the species heard last on top.
library;

import 'package:flutter/foundation.dart';

import '../../features/live/live_session.dart';

/// One species of the live table.
@immutable
class LiveTableEntry {
  const LiveTableEntry({
    required this.scientificName,
    required this.commonName,
    required this.sessionCount,
    required this.total,
    required this.lastHeard,
    required this.record,
    required this.singing,
    bool? singingVisual,
  }) : singingVisual = singingVisual ?? singing;

  final String scientificName;

  /// Localized common name.
  final String commonName;

  /// Contacts of this outing (« ×3 »).
  final int sessionCount;

  /// Contacts over every outing, this one included (« 142 au total »).
  final int total;

  /// Start of the newest contact: the table is sorted on it.
  final DateTime lastHeard;

  /// Record that gives the reliability: the running one while the species
  /// sings, else the newest.
  final DetectionRecord record;

  /// The species is in the current inference results.
  final bool singing;

  /// The « chante » symbol is on: [singing], until the last windows fall
  /// under the support threshold (J6c-bis-b, `live_heard.dart`).
  final bool singingVisual;
}

/// Totals of the header.
@immutable
class LiveStats {
  const LiveStats({required this.species, required this.contacts});

  factory LiveStats.of(List<LiveTableEntry> entries) => LiveStats(
    species: entries.length,
    contacts: entries.fold(0, (sum, e) => sum + e.sessionCount),
  );

  final int species;
  final int contacts;
}

/// Builds the table from the session records ([sessionDetections]) and the
/// current results ([currentDetections]).
///
/// A new species comes in on top; a species heard again (a new contact)
/// goes back to the top; a contact that goes on does not move its row.
/// Every species of the outing stays in the table, singing or not.
/// [totals] are the all-time counts including this outing; missing species
/// fall back to their session count. [singingVisual] puts out the symbol of
/// singing species missing from it; null keeps it on while they sing.
List<LiveTableEntry> buildLiveTable({
  required List<DetectionRecord> sessionDetections,
  required List<DetectionRecord> currentDetections,
  Set<String>? singingVisual,
  Map<String, int> totals = const {},
  String Function(DetectionRecord record)? localizedName,
}) {
  final counts = <String, int>{};
  final newest = <String, DetectionRecord>{};
  void add(DetectionRecord record) {
    final name = record.scientificName;
    final seen = newest[name];
    if (seen == null || record.timestamp.isAfter(seen.timestamp)) {
      newest[name] = record;
    }
  }

  for (final record in sessionDetections) {
    counts.update(record.scientificName, (n) => n + 1, ifAbsent: () => 1);
    add(record);
  }
  // Current detections get a new timestamp every cycle: they only stand in
  // for a species the session does not hold yet, so rows do not reorder
  // while a contact goes on.
  final current = <String, DetectionRecord>{};
  for (final record in currentDetections) {
    current[record.scientificName] = record;
    if (!counts.containsKey(record.scientificName)) {
      counts[record.scientificName] = 1;
      add(record);
    }
  }

  final entries = [
    for (final MapEntry(key: name, value: last) in newest.entries)
      LiveTableEntry(
        scientificName: name,
        commonName: localizedName?.call(last) ?? last.commonName,
        sessionCount: counts[name]!,
        total: totals[name] ?? counts[name]!,
        lastHeard: last.timestamp,
        record: current[name] ?? last,
        singing: current.containsKey(name),
        singingVisual:
            current.containsKey(name) &&
            (singingVisual?.contains(name) ?? true),
      ),
  ];
  entries.sort((a, b) {
    final byTime = b.lastHeard.compareTo(a.lastHeard);
    return byTime != 0 ? byTime : a.scientificName.compareTo(b.scientificName);
  });
  return entries;
}

/// Detections to show as singing: none while [paused] or [replaying] a clip,
/// since inference is stopped or skips the replayed audio. The « chante »
/// bars and the running marks go out; the session keeps its records.
List<DetectionRecord> singingDetections(
  List<DetectionRecord> current, {
  required bool paused,
  required bool replaying,
}) => paused || replaying ? const [] : current;
