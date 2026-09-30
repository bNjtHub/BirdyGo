import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/quiz_entry_row.dart';
import 'package:birdnet_live/fork/game/quiz_intro.dart' show QuizTitleMark;
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BadgeProgress _p(int value) =>
    BadgeProgress(kind: BadgeKind.fineEar, value: value);

Future<void> _pump(WidgetTester tester, Widget row, {bool reduced = false}) =>
    tester.pumpWidget(
      MaterialApp(
        builder:
            (context, app) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: app!,
            ),
        theme: BirdyTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: row),
      ),
    );

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  test('filled segments follow the way to the next tier', () {
    // Tiers 10, 50, 150.
    expect(QuizEntryRow.filledSegments(_p(0)), 0);
    expect(QuizEntryRow.filledSegments(_p(5)), 5);
    expect(QuizEntryRow.filledSegments(_p(9)), 9);
    expect(QuizEntryRow.filledSegments(_p(10)), 0); // 0 of 40
    expect(QuizEntryRow.filledSegments(_p(30)), 5); // 20 of 40
    expect(QuizEntryRow.filledSegments(_p(49)), 9);
    expect(QuizEntryRow.filledSegments(_p(50)), 0);
    expect(QuizEntryRow.filledSegments(_p(150)), BirdySizes.quizEntrySegments);
    expect(QuizEntryRow.filledSegments(_p(400)), BirdySizes.quizEntrySegments);
  });

  final hooks = {
    3: fr.forkQuizEntryHook(7),
    10: fr.forkQuizEntryHookNext,
    50: fr.forkQuizEntryHookTier('two'),
    150: fr.forkQuizEntryHookTier('all'),
  };
  for (final e in hooks.entries) {
    testWidgets('hook for ${e.key} right answers', (tester) async {
      await _pump(tester, QuizEntryRow(progress: _p(e.key)));
      expect(find.text(e.value), findsOneWidget);
      expect(find.text(fr.forkQuizEntrySubtitle), findsNothing);
    });
  }

  testWidgets('bar has 10 segments, filled ones first', (tester) async {
    await _pump(tester, QuizEntryRow(progress: _p(5)));
    expect(find.byKey(const ValueKey('quiz-segment-on')), findsNWidgets(5));
    expect(find.byKey(const ValueKey('quiz-segment-off')), findsNWidgets(5));
  });

  testWidgets('semantics: button labelled title and hook', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, QuizEntryRow(progress: _p(3)));
    expect(
      find.bySemanticsLabel('${fr.forkQuizTitle}. ${fr.forkQuizEntryHook(7)}'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('without progress: subtitle, no bar', (tester) async {
    await _pump(tester, const QuizEntryRow());
    expect(find.text(fr.forkQuizEntrySubtitle), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-segment-off')), findsNothing);
    expect(find.byKey(const ValueKey('quiz-segment-on')), findsNothing);
  });

  testWidgets('title wears the yellow question mark', (tester) async {
    await _pump(tester, const QuizEntryRow());
    expect(find.byType(QuizTitleMark), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('logo bobs once, never in a loop', (tester) async {
    await _pump(tester, const QuizEntryRow());
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle(); // would time out if it looped
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: no animation at all', (tester) async {
    await _pump(tester, const QuizEntryRow(), reduced: true);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
