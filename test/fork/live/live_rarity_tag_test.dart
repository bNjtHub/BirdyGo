import 'package:birdnet_live/features/announcements/domain/announcement_signals.dart';
import 'package:birdnet_live/features/announcements/geo_commonness_provider.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_pill.dart';
import 'package:birdnet_live/fork/live/live_rarity_tag.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GeoCommonnessEntry _entry(CommonnessBin bin, double score) =>
    GeoCommonnessEntry(
      commonness: bin,
      isOutOfSeason: false,
      currentScore: score,
      annualMax: 0.5,
    );

void main() {
  group('liveRarityCause', () {
    final map = {
      'Rare bird': _entry(CommonnessBin.rare, 0.2),
      'Faint bird': _entry(CommonnessBin.uncommon, 0.001),
      'Common bird': _entry(CommonnessBin.common, 0.3),
    };

    test('follows the geo presence rule', () {
      expect(liveRarityCause(map, 'Rare bird'), LiveUnexpectedCause.rare);
      expect(
        liveRarityCause(map, 'Faint bird'),
        LiveUnexpectedCause.belowInclusion,
      );
      expect(liveRarityCause(map, 'Missing bird'), LiveUnexpectedCause.absent);
      expect(liveRarityCause(map, 'Common bird'), isNull);
    });

    test('no map, no tag', () {
      expect(liveRarityCause(null, 'Rare bird'), isNull);
      expect(liveRarityCause(const {}, 'Rare bird'), isNull);
    });
  });

  group('liveRarityKind', () {
    test(
      'rare and absent give « Rare ici », below inclusion « Peu commun »',
      () {
        for (final cause in [
          LiveUnexpectedCause.rare,
          LiveUnexpectedCause.absent,
        ]) {
          expect(
            liveRarityKind(
              cause: cause,
              level: ReliabilityLevel.toCheck,
              score: 0.1,
            ),
            NoveltyKind.rareHere,
          );
        }
        expect(
          liveRarityKind(
            cause: LiveUnexpectedCause.belowInclusion,
            level: ReliabilityLevel.toCheck,
            score: 0.1,
          ),
          NoveltyKind.uncommonHere,
        );
      },
    );

    test('expected here: no tag', () {
      expect(
        liveRarityKind(cause: null, level: ReliabilityLevel.sure, score: 0.95),
        isNull,
      );
    });

    test('no duplicate with « Rare ici · à confirmer »', () {
      // Unexpected + a score that would pass: the merged pill shows.
      final score = ReliabilityConfig.probableMinScore + 0.05;
      for (final cause in LiveUnexpectedCause.values) {
        expect(
          liveRarityKind(
            cause: cause,
            level: ReliabilityLevel.toCheck,
            score: score,
          ),
          isNull,
          reason: cause.name,
        );
      }
    });
  });

  group('LiveReliabilityBadge', () {
    Future<void> pump(
      WidgetTester tester, {
      required LiveUnexpectedCause? cause,
      required double score,
      bool compact = true,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LiveReliabilityBadge(
            level: ReliabilityLevel.toCheck,
            cause: cause,
            score: score,
            compact: compact,
          ),
        ),
      ),
    );

    testWidgets('shows the tag pill next to the badge', (tester) async {
      await pump(tester, cause: LiveUnexpectedCause.rare, score: 0.05);
      expect(find.text('Rare ici'), findsOneWidget);
      await pump(
        tester,
        cause: LiveUnexpectedCause.belowInclusion,
        score: 0.05,
        compact: false,
      );
      expect(find.text('Peu commun ici'), findsOneWidget);
      // The tag replaces the « Inattendu ici » pill and the lone diamond.
      expect(find.text('Inattendu ici'), findsNothing);
    });

    testWidgets('merged pill alone when already shown', (tester) async {
      await pump(
        tester,
        cause: LiveUnexpectedCause.rare,
        score: ReliabilityConfig.probableMinScore + 0.05,
        compact: false,
      );
      expect(find.text('Rare ici'), findsNothing);
      expect(find.text('Rare ici · à confirmer'), findsOneWidget);
    });

    testWidgets('no cause, no tag', (tester) async {
      await pump(tester, cause: null, score: 0.05);
      expect(find.byType(NoveltyPill), findsNothing);
    });
  });
}
