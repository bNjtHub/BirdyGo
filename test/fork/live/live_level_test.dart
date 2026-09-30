import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/live/live_level.dart';
import 'package:birdnet_live/fork/live/live_moments_model.dart';
import 'package:birdnet_live/fork/live/live_table.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/reliability/levels_sheet.dart';
import 'package:birdnet_live/fork/reliability/reliability_badge.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 9, 30, 7, 5);

/// Scores well above and below the thresholds of [ReliabilityConfig].
const double _high = ReliabilityConfig.sureMinScore + 0.05;
const double _mid = ReliabilityConfig.probableMinScore + 0.05;

const _expected = GeoPresence(unexpected: false);
const _unexpected = GeoPresence(unexpected: true);

DetectionRecord _rec(
  double score, {
  int second = 0,
  ReviewStatus review = ReviewStatus.unreviewed,
  String name = 'Turdus merula',
}) => DetectionRecord(
  scientificName: name,
  commonName: name,
  confidence: score,
  timestamp: _t0.add(Duration(seconds: second)),
  reviewStatus: review,
);

/// One frame of the table: the outing so far and the running window.
LiveTableEntry _frame(
  List<double> session,
  double? running, {
  String name = 'Turdus merula',
}) => buildLiveTable(
  sessionDetections: [
    for (final (i, s) in session.indexed) _rec(s, second: i * 10, name: name),
  ],
  currentDetections: [if (running != null) _rec(running, name: name)],
).single;

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: BirdyTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder:
      (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: app!,
      ),
  home: Scaffold(body: child),
);

void main() {
  group('level of the best contact (model)', () {
    test('0.85, then 0.6, then 0.9: Sure from the first score on', () {
      final levels = [
        liveLevelOf(_frame([_high], _high), _expected),
        liveLevelOf(_frame([_high], _mid), _expected),
        liveLevelOf(_frame([_high], 0.9), _expected),
      ];
      expect(levels, everyElement(ReliabilityLevel.sure));
    });

    test('the running score moves, the level does not', () {
      final low = _frame([_high], _mid);
      expect(low.record.confidence, _mid);
      expect(low.bestScore, _high);
      expect(low.bestAt, _t0);
    });

    test('0.6 then 0.85: Probable, then Sure', () {
      expect(
        liveLevelOf(_frame([_mid], _mid), _expected),
        ReliabilityLevel.probable,
      );
      expect(
        liveLevelOf(_frame([_mid, _high], _high), _expected),
        ReliabilityLevel.sure,
      );
      // ... and the level stays when the score falls back.
      expect(
        liveLevelOf(_frame([_mid, _high], _mid), _expected),
        ReliabilityLevel.sure,
      );
    });

    test('the running window can be the best one', () {
      final entry = _frame([_mid], _high);
      expect(entry.bestScore, _high);
      expect(liveLevelOf(entry, _expected), ReliabilityLevel.sure);
    });

    test('an unexpected species stays « À vérifier »', () {
      final entry = _frame([_high, _high], _high);
      expect(liveLevelOf(entry, _unexpected), ReliabilityLevel.toCheck);
      expect(
        placeOnlyToCheck(score: entry.bestScore, presence: _unexpected),
        isTrue,
      );
    });

    test('without geo information a high score stays Probable', () {
      expect(liveLevelOf(_frame([_high], _high), null), ReliabilityLevel.probable);
    });

    test('a confirmed contact makes it Sure whatever its score', () {
      final entry =
          buildLiveTable(
            sessionDetections: [
              _rec(_high, second: 10),
              _rec(0.2, review: ReviewStatus.confirmed),
            ],
            currentDetections: const [],
          ).single;
      expect(entry.levelRecord.reviewStatus, ReviewStatus.confirmed);
      expect(liveLevelOf(entry, _unexpected), ReliabilityLevel.sure);
    });

    test('on a tie the earlier contact is the best one', () {
      final entry =
          buildLiveTable(
            sessionDetections: [_rec(_high), _rec(_high, second: 30)],
            currentDetections: [_rec(_high, second: 60)],
          ).single;
      expect(entry.bestAt, _t0);
      expect(entry.sessionCount, 2);
    });

    test('a first encounter follows the best contact too', () {
      final tracker = LiveMomentTracker(verifiedBefore: {});
      final entry = _frame([_high], _mid);
      final moment = tracker.next(
        [entry],
        presenceOf: (_) => _expected,
        isBird: (_) => true,
      );
      expect(moment?.kind, LiveMomentKind.firstTime);
    });

    test('the summary keeps the same rule: best level over the contacts', () {
      // ListeningSummary.of takes bestLevel over the contacts, and the
      // level is monotone in the score: same result as the live row.
      final levels = [
        for (final s in [_mid, _high, _mid])
          reliabilityFor(score: s, presence: _expected),
      ];
      expect(bestLevel(levels), liveLevelOf(_frame([_mid, _high], _mid), _expected));
    });
  });

  group('« chante » bars follow the current score', () {
    Widget bars(double level) => _app(SingingBars(color: Colors.teal, level: level));

    double? painted(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(SingingBars),
          matching: find.byType(CustomPaint),
        ),
      );
      return (paint.painter as dynamic).level as double?;
    }

    testWidgets('the bars scale with the score', (tester) async {
      await tester.pumpWidget(bars(1));
      await tester.pump(const Duration(seconds: 1));
      expect(painted(tester), 1);
      await tester.pumpWidget(bars(0.5));
      await tester.pump(const Duration(seconds: 1));
      expect(painted(tester), closeTo(0.5, 0.001));
    });

    testWidgets('a row hands its running score to the bars', (tester) async {
      final entry = _frame([_high], _mid);
      await tester.pumpWidget(
        _app(LiveTable(entries: [entry])),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<SingingBars>(find.byType(SingingBars)).level,
        _mid,
      );
    });
  });

  group('« Confirmé »', () {
    final levels = <String, ReliabilityLevel>{};

    Widget table(List<LiveTableEntry> entries, {bool reduced = false}) => _app(
      LiveTable(
        entries: entries,
        levelFor: (e) => levels[e.scientificName]!,
        badgeFor:
            (e, {required compact}) =>
                ReliabilityBadge(level: levels[e.scientificName]!),
      ),
      reduced: reduced,
    );

    final merle = _frame([_high], _high);
    final merle2 = _frame([_high, _high], _high);
    final merle3 = _frame([_high, _high, _high], _high);

    setUp(levels.clear);

    testWidgets('Probable then Sure: shown once, then the badge is back', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      levels['Turdus merula'] = ReliabilityLevel.probable;
      await tester.pumpWidget(table([merle]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Confirmé'), findsNothing);

      levels['Turdus merula'] = ReliabilityLevel.sure;
      await tester.pumpWidget(table([merle2]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Confirmé'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Turdus merula : confirmé')),
        findsOneWidget,
      );

      await tester.pump(BirdyMotion.confirmedShown + const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Confirmé'), findsNothing);
      expect(find.text('Sûr'), findsOneWidget);

      // Once per species and outing: no second « Confirmé ».
      levels['Turdus merula'] = ReliabilityLevel.probable;
      await tester.pumpWidget(table([merle3]));
      levels['Turdus merula'] = ReliabilityLevel.sure;
      await tester.pumpWidget(table([merle2]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Confirmé'), findsNothing);
      handle.dispose();
    });

    testWidgets('a species that arrives Sure is not « confirmed »', (
      tester,
    ) async {
      levels['Turdus merula'] = ReliabilityLevel.sure;
      await tester.pumpWidget(table([merle]));
      await tester.pumpWidget(table([merle2]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Confirmé'), findsNothing);
    });

    testWidgets('reduced motion: only the badge changes', (tester) async {
      final handle = tester.ensureSemantics();
      levels['Turdus merula'] = ReliabilityLevel.probable;
      await tester.pumpWidget(table([merle], reduced: true));
      levels['Turdus merula'] = ReliabilityLevel.sure;
      await tester.pumpWidget(table([merle2], reduced: true));
      await tester.pump();
      expect(find.text('Confirmé'), findsNothing);
      expect(find.text('Sûr'), findsOneWidget);
      // A screen reader still hears it.
      expect(
        find.bySemanticsLabel(RegExp('Turdus merula : confirmé')),
        findsOneWidget,
      );
      await tester.pump(BirdyMotion.confirmedShown + const Duration(seconds: 1));
      handle.dispose();
    });
  });

  group('levels sheet from the badge', () {
    testWidgets('tapping the badge calls back with the entry', (tester) async {
      LiveTableEntry? tapped;
      final entry = _frame([_high], _high);
      await tester.pumpWidget(
        _app(
          LiveTable(
            entries: [entry],
            badgeFor:
                (e, {required compact}) =>
                    const ReliabilityBadge(level: ReliabilityLevel.sure),
            onBadgeTap: (e) => tapped = e,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Sûr'));
      expect(tapped?.scientificName, 'Turdus merula');
    });

    testWidgets('shows the best score, its time and the contacts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          LevelsSheet(
            species: LevelsSpecies(
              name: 'Merle noir',
              level: ReliabilityLevel.sure,
              bestScore: 0.87,
              bestAt: DateTime(2026, 9, 30, 7, 12),
              contacts: 3,
            ),
          ),
        ),
      );
      expect(find.text('Niveau de Merle noir'), findsOneWidget);
      expect(find.text('Meilleur score : 87 %'), findsOneWidget);
      expect(find.textContaining('Meilleur contact à'), findsOneWidget);
      expect(find.textContaining('7:12'), findsOneWidget);
      expect(find.text('3 contacts pendant cette sortie'), findsOneWidget);
      // The general explanation is still there.
      expect(find.text('Sûr'), findsWidgets);
    });

    testWidgets('without a species the sheet is the usual one', (tester) async {
      await tester.pumpWidget(_app(const LevelsSheet()));
      expect(find.byKey(const ValueKey('levels-species')), findsNothing);
    });
  });
}

