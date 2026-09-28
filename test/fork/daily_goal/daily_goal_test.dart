import 'dart:convert';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/daily_goal/daily_goal.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _robin = DailyGoalSpecies(
  scientificName: 'Erithacus rubecula',
  commonName: 'Robin',
  geoScore: 0.9,
  unexpected: false,
);
const _tit = DailyGoalSpecies(
  scientificName: 'Parus major',
  commonName: 'Great tit',
  geoScore: 0.8,
  unexpected: false,
);
const _rare = DailyGoalSpecies(
  scientificName: 'Upupa epops',
  commonName: 'Hoopoe',
  geoScore: 0.035,
  unexpected: true,
);

DailyGoal _goal({
  List<DailyGoalSpecies> species = const [_robin, _tit, _rare],
}) => DailyGoal(
  day: DateTime(2026, 9, 27),
  latitude: 47.21,
  longitude: -1.55,
  species: species,
  candidates: const [_robin, _tit, _rare],
);

IndexedDetection _detection({
  String name = 'Erithacus rubecula',
  double confidence = ReliabilityConfig.sureMinScore,
  DetectionSource source = DetectionSource.auto,
  DetectionEvidence? evidence,
  ReviewStatus review = ReviewStatus.unreviewed,
  DateTime? time,
  double? latitude = 47.21,
  double? longitude = -1.55,
}) => IndexedDetection(
  key: 'session|$name',
  sessionId: 'session',
  position: 0,
  scientificName: name,
  commonName: name,
  start: time ?? DateTime(2026, 9, 27, 9),
  end: null,
  confidence: confidence,
  reviewStatus: review,
  latitude: latitude,
  longitude: longitude,
  clipPath: null,
  source: source,
  evidence: evidence,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('candidates intersect birds, audio and current-week local scores', () {
    final candidates = dailyGoalCandidates(
      scores: const {
        'Parus major': .8,
        'Erithacus rubecula': .8,
        'Strix aluco': .01,
        'Vulpes vulpes': .95,
        'Missing audio': .9,
        'Missing class': .7,
      },
      audioClasses: const {
        'Parus major': 'Aves',
        'Erithacus rubecula': 'Aves',
        'Strix aluco': 'Aves',
        'Vulpes vulpes': 'Mammalia',
        'Missing class': '',
      },
      commonName: (name) => name,
    );
    expect(candidates.map((bird) => bird.scientificName), [
      'Erithacus rubecula',
      'Parus major',
    ]);
  });

  test('selection caps at eight, de-duplicates and accepts sparse areas', () {
    final birds = List.generate(
      10,
      (i) => DailyGoalSpecies(
        scientificName: 'Bird $i',
        commonName: 'Bird $i',
        geoScore: .9 - i / 100,
        unexpected: false,
      ),
    );
    final goal = DailyGoal.create(
      day: DateTime(2026, 9, 27),
      latitude: 0,
      longitude: 0,
      candidates: [birds.first, ...birds],
    );
    expect(goal.total, 8);
    expect(
      goal.species.map((bird) => bird.scientificName).toSet(),
      hasLength(8),
    );
    expect(goal.availableReplacements, hasLength(2));
    expect(
      DailyGoal.create(
        day: goal.day,
        latitude: 0,
        longitude: 0,
        candidates: const [_robin],
      ).total,
      1,
    );
  });

  test('replacement preserves day and area and cannot duplicate a target', () {
    final original = _goal(species: const [_robin]);
    final replaced = original.replace(
      _robin.scientificName,
      _tit.scientificName,
    );
    expect(replaced.species.single.scientificName, _tit.scientificName);
    expect(replaced.day, original.day);
    expect(replaced.latitude, original.latitude);
    expect(replaced.longitude, original.longitude);
    expect(replaced.availableReplacements.map((bird) => bird.scientificName), [
      _robin.scientificName,
      _rare.scientificName,
    ]);
    expect(
      identical(replaced.replace(_tit.scientificName, 'Unknown'), replaced),
      isTrue,
    );
    expect(
      identical(
        replaced.replace(_tit.scientificName, _tit.scientificName),
        replaced,
      ),
      isTrue,
    );
    final multiple = _goal();
    expect(
      identical(
        multiple.replace(_robin.scientificName, _tit.scientificName),
        multiple,
      ),
      isTrue,
    );
  });

  test(
    'persistence restores candidates offline only for the local day',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final goal = _goal(
        species: const [_robin],
      ).replace(_robin.scientificName, _tit.scientificName);
      await DailyGoalStore(prefs).save(goal);
      final restored =
          DailyGoalStore(prefs).readToday(DateTime(2026, 9, 27, 23, 59))!;
      expect(restored.toJson(), goal.toJson());
      expect(restored.availableReplacements, hasLength(2));
      expect(DailyGoalStore(prefs).readToday(DateTime(2026, 9, 28)), isNull);
      expect(DailyGoalStore(prefs).readToday(DateTime(2026, 9, 26)), isNull);
    },
  );

  test('invalid persisted data never invents a selection', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.dailyBirdGoal: '{broken'});
    final prefs = await SharedPreferences.getInstance();
    final store = DailyGoalStore(prefs);
    expect(store.readToday(DateTime(2026, 9, 27)), isNull);
    final invalid = _goal().toJson()..['latitude'] = 999;
    await prefs.setString(PrefKeys.dailyBirdGoal, jsonEncode(invalid));
    expect(store.readToday(DateTime(2026, 9, 27)), isNull);
  });

  test('acoustic evidence is explicit for manual records', () {
    for (final source in DetectionSource.values) {
      final withoutEvidence = _detection(source: source);
      expect(withoutEvidence.isHeard, source == DetectionSource.auto);
      expect(
        _detection(source: source, evidence: DetectionEvidence.seen).isHeard,
        isFalse,
      );
      expect(
        _detection(source: source, evidence: DetectionEvidence.heard).isHeard,
        isTrue,
      );
    }
  });

  test(
    'seen-only and unspecified manual records never complete an audio goal',
    () {
      for (final source in [
        DetectionSource.manual,
        DetectionSource.manualGlobal,
        DetectionSource.userSpecified,
      ]) {
        for (final evidence in [null, DetectionEvidence.seen]) {
          expect(
            completedDailyGoalSpecies(_goal(), [
              _detection(
                source: source,
                evidence: evidence,
                review: ReviewStatus.confirmed,
                confidence: 1,
              ),
            ]),
            isEmpty,
          );
        }
      }
    },
  );

  test('manual heard and heard+seen count, rejected manual does not', () {
    for (final evidence in [
      DetectionEvidence.heard,
      DetectionEvidence.heardAndSeen,
    ]) {
      expect(
        completedDailyGoalSpecies(_goal(), [
          _detection(
            source: DetectionSource.manualGlobal,
            evidence: evidence,
            confidence: 0,
          ),
        ]),
        {_robin.scientificName},
      );
    }
    expect(
      completedDailyGoalSpecies(_goal(), [
        _detection(
          source: DetectionSource.manual,
          evidence: DetectionEvidence.heard,
          review: ReviewStatus.rejected,
        ),
      ]),
      isEmpty,
    );
  });

  test(
    'automatic progress requires sure reliability or human confirmation',
    () {
      expect(completedDailyGoalSpecies(_goal(), [_detection()]), {
        _robin.scientificName,
      });
      expect(
        completedDailyGoalSpecies(_goal(), [_detection(confidence: .79)]),
        isEmpty,
      );
      expect(
        completedDailyGoalSpecies(_goal(), [
          _detection(name: _rare.scientificName, confidence: .99),
        ]),
        isEmpty,
      );
      expect(
        completedDailyGoalSpecies(_goal(), [
          _detection(
            name: _rare.scientificName,
            confidence: .3,
            review: ReviewStatus.confirmed,
          ),
        ]),
        {_rare.scientificName},
      );
      expect(
        completedDailyGoalSpecies(_goal(), [
          _detection(review: ReviewStatus.rejected, confidence: 1),
        ]),
        isEmpty,
      );
    },
  );

  test(
    'goal counts once across sessions, within local day and saved area only',
    () {
      final goal = _goal();
      expect(completedDailyGoalSpecies(goal, [_detection(), _detection()]), {
        _robin.scientificName,
      });
      for (final detection in [
        _detection(time: DateTime(2026, 9, 26, 23, 59, 59)),
        _detection(time: DateTime(2026, 9, 28)),
        _detection(latitude: 48.8, longitude: 2.3),
        _detection(latitude: null),
        _detection(longitude: null),
        _detection(name: 'Not a target'),
      ]) {
        expect(completedDailyGoalSpecies(goal, [detection]), isEmpty);
      }
      expect(completedDailyGoalSpecies(goal, [_detection(time: goal.day)]), {
        _robin.scientificName,
      });
      expect(
        completedDailyGoalSpecies(goal, [
          _detection(
            time: goal.nextDay.subtract(const Duration(microseconds: 1)),
          ),
        ]),
        {_robin.scientificName},
      );
      expect(goal.containsPosition(47.25, -1.55), isTrue);
      expect(goal.containsPosition(47.35, -1.55), isFalse);
    },
  );
}
