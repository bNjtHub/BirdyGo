// The morning of the mockup (fork/maquette/SPEC.md 8.2): samedi 26 septembre
// 2026, 7 h 12 → 7 h 54, 13 species, 52 contacts.

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';

const robin = 'Erithacus rubecula';
const owl = 'Strix aluco';
const wren = 'Troglodytes troglodytes';
const blackbird = 'Turdus merula';
const greatTit = 'Parus major';
const blueTit = 'Cyanistes caeruleus';
const chaffinch = 'Fringilla coelebs';
const chiffchaff = 'Phylloscopus collybita';
const magpie = 'Pica pica';
const sparrow = 'Passer domesticus';
const woodpecker = 'Dendrocopos major';
const kingfisher = 'Alcedo atthis';
const hoopoe = 'Upupa epops';

DateTime at(int hour, int minute) => DateTime(2026, 9, 26, hour, minute);

/// (scientific, common, contacts, first contact, score of the first, score
/// of the others).
const _table = [
  (robin, 'Rougegorge familier', 9, (7, 13), 0.97, 0.97),
  (owl, 'Chouette hulotte', 1, (7, 14), 0.71, 0.71),
  (wren, 'Troglodyte mignon', 7, (7, 15), 0.94, 0.94),
  (blackbird, 'Merle noir', 6, (7, 17), 0.88, 0.88),
  (greatTit, 'Mésange charbonnière', 6, (7, 19), 0.91, 0.91),
  (blueTit, 'Mésange bleue', 5, (7, 24), 0.89, 0.89),
  (chaffinch, 'Pinson des arbres', 4, (7, 24), 0.86, 0.86),
  (chiffchaff, 'Pouillot véloce', 3, (7, 24), 0.62, 0.84),
  (magpie, 'Pie bavarde', 4, (7, 25), 0.90, 0.90),
  (sparrow, 'Moineau domestique', 3, (7, 25), 0.83, 0.83),
  (woodpecker, 'Pic épeiche', 2, (7, 26), 0.91, 0.91),
  (kingfisher, "Martin-pêcheur d'Europe", 1, (7, 31), 0.52, 0.52),
  (hoopoe, 'Huppe fasciée', 1, (7, 38), 0.58, 0.58),
];

/// The session of the mockup, detections in time order.
LiveSession morningSession() {
  final detections = <DetectionRecord>[];
  for (final (name, common, count, (h, m), first, others) in _table) {
    for (var i = 0; i < count; i++) {
      final start = at(h, m).add(Duration(minutes: i * 2));
      detections.add(
        DetectionRecord(
          scientificName: name,
          commonName: common,
          confidence: i == 0 ? first : others,
          timestamp: start,
          endTimestamp: start.add(const Duration(seconds: 6)),
        ),
      );
    }
  }
  detections.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return LiveSession(
    id: '2026-09-26T07-12-00.000',
    startTime: at(7, 12),
    endTime: at(7, 54),
    recordedDurationSeconds: 42 * 60,
    detections: detections,
    settings: const SessionSettings(
      windowDuration: 3,
      confidenceThreshold: 30,
      inferenceRate: 1.5,
      speciesFilterMode: 'geoMerge',
    ),
    latitude: 46.7,
    longitude: 1.2,
  );
}

/// Every species is plausible here but the Huppe.
Map<String, GeoPresence> morningPresence() => {
  for (final (name, _, _, _, _, _) in _table)
    name: GeoPresence(unexpected: name == hoopoe),
};

/// Heard before this morning: all but the Pic épeiche and the Huppe.
Set<String> heardBeforeMorning() => {
  for (final (name, _, _, _, _, _) in _table)
    if (name != woodpecker && name != hoopoe) name,
};
