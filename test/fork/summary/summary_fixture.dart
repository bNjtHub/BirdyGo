/// This morning's session of the mockup (fork/maquette/SPEC.md 8.2).
library;

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';

final DateTime morningStart = DateTime(2026, 9, 26, 7, 12);

/// (scientific name, French name, contacts, first minute, last minute,
/// score). Minutes count from 7 h 00.
const List<(String, String, int, int, int, double)> morningSpecies = [
  ('Erithacus rubecula', 'Rougegorge familier', 9, 13, 52, 0.97),
  ('Strix aluco', 'Chouette hulotte', 1, 14, 14, 0.71),
  ('Troglodytes troglodytes', 'Troglodyte mignon', 7, 15, 50, 0.94),
  ('Turdus merula', 'Merle noir', 6, 17, 49, 0.88),
  ('Parus major', 'Mésange charbonnière', 6, 19, 47, 0.91),
  ('Cyanistes caeruleus', 'Mésange bleue', 5, 24, 45, 0.89),
  ('Fringilla coelebs', 'Pinson des arbres', 4, 24, 44, 0.86),
  ('Phylloscopus collybita', 'Pouillot véloce', 3, 24, 40, 0.84),
  ('Pica pica', 'Pie bavarde', 4, 25, 51, 0.90),
  ('Passer domesticus', 'Moineau domestique', 3, 25, 53, 0.83),
  ('Dendrocopos major', 'Pic épeiche', 2, 26, 33, 0.91),
  ('Alcedo atthis', "Martin-pêcheur d'Europe", 1, 31, 31, 0.52),
  ('Upupa epops', 'Huppe fasciée', 1, 38, 38, 0.58),
];

/// The 23 species verified before this morning: all of this morning's but
/// the Pic épeiche and the Huppe, plus 12 others.
final Set<String> verifiedBeforeMorning = {
  for (final s in morningSpecies)
    if (s.$1 != 'Dendrocopos major' && s.$1 != 'Upupa epops') s.$1,
  for (var i = 1; i <= 12; i++) 'Other species $i',
};

/// The geo-model: the Huppe is rare here, the others are expected.
GeoPresence? morningPresence(String scientificName) =>
    GeoPresence(unexpected: scientificName == 'Upupa epops');

Map<String, dynamic> _detection(
  String sci,
  String name,
  DateTime time,
  double score, {
  String? review,
}) => {
  'scientificName': sci,
  'commonName': name,
  'confidence': score,
  'timestamp': time.toUtc().toIso8601String(),
  if (review != null) 'reviewStatus': review,
};

/// The session, 7 h 12 → 7 h 54. The Pouillot's first contact is
/// « Probable » (0,62), the next ones « Sûr ».
LiveSession morningSession({
  String id = 'morning',
  List<Map<String, dynamic>> extra = const [],
}) {
  final day = DateTime(2026, 9, 26, 7);
  final detections = <Map<String, dynamic>>[
    for (final (sci, name, count, first, last, score) in morningSpecies)
      for (var i = 0; i < count; i++)
        _detection(
          sci,
          name,
          day.add(
            Duration(
              seconds:
                  (first * 60 +
                          (count == 1
                              ? 0
                              : (last - first) * 60 * i / (count - 1)))
                      .round(),
            ),
          ),
          sci == 'Phylloscopus collybita' && i == 0 ? 0.62 : score,
        ),
    ...extra,
  ]..sort(
    (a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String),
  );
  return LiveSession.fromJson({
    'id': id,
    'startTime': morningStart.toUtc().toIso8601String(),
    'endTime': DateTime(2026, 9, 26, 7, 54).toUtc().toIso8601String(),
    'latitude': 46.7,
    'longitude': 1.2,
    'detections': detections,
  });
}

/// A detection to add to [morningSession].
Map<String, dynamic> extraDetection(
  String sci,
  int minute, {
  double score = 0.9,
  String? review,
}) => _detection(
  sci,
  sci,
  DateTime(2026, 9, 26, 7, minute),
  score,
  review: review,
);
