import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/live/live_board_model.dart';
import 'package:birdnet_live/fork/live/live_stats.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 9, 26, 7);

DetectionRecord _rec(
  String name,
  int second, {
  double score = 0.9,
  String? clip,
  ReviewStatus review = ReviewStatus.unreviewed,
}) => DetectionRecord(
  scientificName: name,
  commonName: 'common $name',
  confidence: score,
  timestamp: _t0.add(Duration(seconds: second)),
  audioClipPath: clip,
  reviewStatus: review,
);

List<LiveBoardEntry> _board(
  List<DetectionRecord> records, {
  Set<String> current = const {},
  Map<String, int> saved = const {},
  GeoPresence? Function(String)? presenceOf,
}) => buildLiveBoard(
  sessionDetections: records,
  currentSpecies: current,
  savedTotals: saved,
  presenceOf: presenceOf ?? (_) => const GeoPresence(unexpected: false),
);

void main() {
  group('buildLiveBoard', () {
    test('one row per species, the latest episode first', () {
      final board = _board([_rec('A', 0), _rec('B', 10), _rec('C', 5)]);
      expect(board.map((e) => e.scientificName), ['B', 'C', 'A']);
    });

    test('a species moves to the top only when a new episode starts', () {
      final before = _board([_rec('A', 0), _rec('B', 10)]);
      expect(before.first.scientificName, 'B');

      // A keeps singing: same record, higher score, same start → no move.
      final sameEpisode = _board(
        [_rec('A', 0, score: 0.95), _rec('B', 10)],
        current: {'A'},
      );
      expect(sameEpisode.first.scientificName, 'B');

      // A new episode of A: it goes back to the top and its count goes up.
      final newEpisode = _board([_rec('A', 0), _rec('B', 10), _rec('A', 20)]);
      expect(newEpisode.first.scientificName, 'A');
      expect(newEpisode.first.sessionCount, 2);
    });

    test(
      'record order does not matter (the controller keeps newest first)',
      () {
        final records = [_rec('A', 20), _rec('B', 10), _rec('A', 0)];
        expect(_board(records).map((e) => e.scientificName), ['A', 'B']);
        expect(_board(records.reversed.toList()).map((e) => e.scientificName), [
          'A',
          'B',
        ]);
      },
    );

    test('totals add the session to the saved contacts', () {
      final board = _board(
        [_rec('A', 0), _rec('A', 30), _rec('B', 10)],
        saved: {'A': 140},
      );
      final a = board.firstWhere((e) => e.scientificName == 'A');
      final b = board.firstWhere((e) => e.scientificName == 'B');
      expect(a.sessionCount, 2);
      expect(a.total, 142);
      expect(b.total, 1);
    });

    test('newest clip of the species', () {
      final board = _board([
        _rec('A', 0, clip: 'old.wav'),
        _rec('A', 30, clip: 'new.wav'),
        _rec('A', 60),
      ]);
      expect(board.single.clipPath, 'new.wav');
    });

    test('singing follows the latest cycle', () {
      final board = _board([_rec('A', 0), _rec('B', 1)], current: {'A'});
      expect(
        {for (final e in board) e.scientificName: e.singing},
        {'A': true, 'B': false},
      );
    });

    test('level: best score, confirmed wins, unexpected is to check', () {
      final best = _board([_rec('A', 0, score: 0.6), _rec('A', 9, score: 0.9)]);
      expect(best.single.level, ReliabilityLevel.sure);

      final confirmed = _board([
        _rec('A', 0, score: 0.3, review: ReviewStatus.confirmed),
      ]);
      expect(confirmed.single.level, ReliabilityLevel.sure);

      final unexpected = _board([
        _rec('A', 0),
      ], presenceOf: (_) => const GeoPresence(unexpected: true));
      expect(unexpected.single.level, ReliabilityLevel.toCheck);
      expect(unexpected.single.unexpected, isTrue);

      // Unknown presence: a high score stays "Probable" (J3 rule).
      final unknown = buildLiveBoard(
        sessionDetections: [_rec('A', 0)],
        currentSpecies: const {},
        savedTotals: const {},
      );
      expect(unknown.single.level, ReliabilityLevel.probable);
    });

    test('localized name of the latest record', () {
      final board = buildLiveBoard(
        sessionDetections: [_rec('A', 0)],
        currentSpecies: const {},
        savedTotals: const {},
        localizedName: (r) => 'Rougegorge',
      );
      expect(board.single.commonName, 'Rougegorge');
    });
  });

  test('formatLiveDuration', () {
    expect(
      formatLiveDuration(const Duration(minutes: 12, seconds: 7)),
      '12:07',
    );
    expect(formatLiveDuration(const Duration(seconds: 5)), '00:05');
    expect(formatLiveDuration(const Duration(hours: 1, minutes: 5)), '1 h 05');
  });
}
