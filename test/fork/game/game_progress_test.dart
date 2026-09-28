import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:flutter_test/flutter_test.dart';

GameProgress _progress({
  Set<String> verified = const {},
  int reviewed = 0,
  int record = 0,
}) => GameProgress(
  GameFacts(
    verifiedBirds: verified,
    dawnChoruses: 0,
    earlyStarts: 0,
    reviewed: reviewed,
    migrants: const {},
    streak: Streak(current: 0, record: record, calendar: const []),
  ),
);

void main() {
  test('the 8 statuses and their thresholds (SPEC.md 7.2)', () {
    expect(statusFor(0), isNull);
    expect(statusFor(1)!.rank, 1);
    expect(statusFor(4)!.rank, 1);
    expect(statusFor(5)!.rank, 2);
    expect(statusFor(24)!.rank, 4);
    expect(statusFor(100)!.rank, 8);
    expect(statusFor(250)!.rank, 8);
  });

  test('progress to the next status, like the mockup (24 → 11 more)', () {
    final p = _progress(verified: {for (var i = 0; i < 24; i++) 'Sp $i'});
    expect(p.status!.rank, 4);
    expect(p.next!.rank, 5);
    expect(p.remaining, 11);
    expect(p.progress, closeTo(4 / 15, 1e-9));
  });

  test('before the first species and at the top', () {
    expect(_progress().next!.rank, 1);
    expect(_progress().remaining, 1);
    final top = _progress(verified: {for (var i = 0; i < 100; i++) 'Sp $i'});
    expect(top.next, isNull);
    expect(top.progress, 1);
  });

  test('badges: tiers and next targets', () {
    final p = _progress(
      verified: {
        'Strix aluco',
        'Parus major',
        'Cyanistes caeruleus',
        'Pica pica',
      },
      reviewed: 36,
      record: 9,
    );
    BadgeProgress badge(BadgeKind kind) =>
        p.badges.firstWhere((b) => b.kind == kind);
    expect(badge(BadgeKind.nightOwl).tier, 1);
    expect(badge(BadgeKind.tits).value, 2);
    expect(badge(BadgeKind.tits).tier, 1);
    expect(badge(BadgeKind.reviewer).tier, 1);
    expect(badge(BadgeKind.reviewer).nextTarget, 50);
    expect(badge(BadgeKind.streak).tier, 1);
    expect(badge(BadgeKind.earlyBird).tier, 0);
    expect(badge(BadgeKind.earlyBird).nextTarget, 1);
  });
}
