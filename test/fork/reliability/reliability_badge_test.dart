import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/reliability/rare_here_sheet.dart';
import 'package:birdnet_live/fork/reliability/reliability_badge.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _frExplanation =
    'Le chant ressemble bien. C\'est le lieu ou la saison qui surprend : '
    'réécoute-le pour confirmer.';

Widget _app(Widget child, {String locale = 'fr', bool dark = false}) =>
    MaterialApp(
      theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  const unexpected = GeoPresence(unexpected: true);
  const plausible = GeoPresence(unexpected: false);

  group('placeOnlyToCheck', () {
    test('a good score made « À vérifier » by the place alone', () {
      expect(placeOnlyToCheck(score: 0.9, presence: unexpected), isTrue);
      expect(
        placeOnlyToCheck(
          score: ReliabilityConfig.probableMinScore,
          presence: unexpected,
        ),
        isTrue,
      );
      // The level itself does not change (J3 rule).
      expect(
        reliabilityFor(score: 0.9, presence: unexpected),
        ReliabilityLevel.toCheck,
      );
    });

    test('not when the score alone is low, or nothing is unexpected', () {
      expect(placeOnlyToCheck(score: 0.4, presence: unexpected), isFalse);
      expect(placeOnlyToCheck(score: 0.9, presence: plausible), isFalse);
      expect(placeOnlyToCheck(score: 0.9), isFalse);
    });

    test('not once confirmed', () {
      expect(
        placeOnlyToCheck(
          score: 0.9,
          review: ReviewStatus.confirmed,
          presence: unexpected,
        ),
        isFalse,
      );
    });
  });

  group('badge', () {
    testWidgets('place only: one « Rare ici · à confirmer » pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ReliabilityBadge(
            level: ReliabilityLevel.toCheck,
            unexpected: true,
            score: 0.9,
          ),
        ),
      );
      expect(find.text('Rare ici · à confirmer'), findsOneWidget);
      expect(find.text('À vérifier'), findsNothing);
      expect(find.text('Inattendu ici'), findsNothing);
    });

    testWidgets('low score and unexpected: both marks stay', (tester) async {
      await tester.pumpWidget(
        _app(
          const ReliabilityBadge(
            level: ReliabilityLevel.toCheck,
            unexpected: true,
            score: 0.4,
          ),
        ),
      );
      expect(find.text('À vérifier'), findsOneWidget);
      expect(find.text('Inattendu ici'), findsOneWidget);
      expect(find.text('Rare ici · à confirmer'), findsNothing);
    });

    testWidgets('confirmed and unexpected: « Sûr » and « Inattendu ici »', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ReliabilityBadge(
            level: ReliabilityLevel.sure,
            unexpected: true,
            score: 0.9,
          ),
        ),
      );
      expect(find.text('Sûr'), findsOneWidget);
      expect(find.text('Inattendu ici'), findsOneWidget);
      expect(find.text('Rare ici · à confirmer'), findsNothing);
    });

    testWidgets('compact: label for screen readers, no explanation on tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ReliabilityBadge(
            level: ReliabilityLevel.toCheck,
            unexpected: true,
            score: 0.9,
            compact: true,
          ),
        ),
      );
      expect(find.text('Rare ici · à confirmer'), findsNothing);
      expect(find.bySemanticsLabel('Rare ici · à confirmer'), findsOneWidget);
      await tester.tap(find.byType(ReliabilityBadge));
      await tester.pumpAndSettle();
      expect(find.byType(RareHereSheet), findsNothing);
    });
  });

  group('explanation', () {
    testWidgets('a tap on the pill opens it', (tester) async {
      await tester.pumpWidget(
        _app(
          const ReliabilityBadge(
            level: ReliabilityLevel.toCheck,
            unexpected: true,
            score: 0.9,
          ),
        ),
      );
      expect(find.text(_frExplanation), findsNothing);
      await tester.tap(find.text('Rare ici · à confirmer'));
      await tester.pumpAndSettle();
      expect(find.byType(RareHereSheet), findsOneWidget);
      expect(find.text(_frExplanation), findsOneWidget);
    });

    testWidgets('in English, and in the dark theme', (tester) async {
      await tester.pumpWidget(
        _app(
          const ReliabilityBadge(
            level: ReliabilityLevel.toCheck,
            unexpected: true,
            score: 0.9,
          ),
          locale: 'en',
          dark: true,
        ),
      );
      await tester.tap(find.text('Rare here · to confirm'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "The song is a good match. It's the place or the season that's "
          'surprising: listen again to confirm.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('other languages fall back to English', (tester) async {
      await tester.pumpWidget(
        _app(
          const ReliabilityBadge(
            level: ReliabilityLevel.toCheck,
            unexpected: true,
            score: 0.9,
          ),
          locale: 'de',
        ),
      );
      expect(find.text('Rare here · to confirm'), findsOneWidget);
    });
  });
}
