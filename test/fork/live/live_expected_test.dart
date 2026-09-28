import 'dart:async';

import 'package:birdnet_live/features/announcements/domain/announcement_signals.dart';
import 'package:birdnet_live/features/announcements/geo_commonness_provider.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/inference/geo_abundance.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/live/live_expected.dart';
import 'package:birdnet_live/fork/live/live_table.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GeoCommonnessEntry _geo(
  double score, {
  CommonnessBin bin = CommonnessBin.frequent,
  double? annualMax,
}) => GeoCommonnessEntry(
  commonness: bin,
  isOutOfSeason: false,
  currentScore: score,
  annualMax: annualMax ?? 1,
);

Widget _app(
  Widget child, {
  double textScale = 1,
  bool reduceMotion = false,
  Locale locale = const Locale('fr'),
}) => MaterialApp(
  theme: BirdyTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder:
      (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: app!,
      ),
  home: Scaffold(body: child),
);

/// 7 a.m. in September: « ce matin », « septembre ».
final _morning = DateTime(2026, 9, 28, 7);

const _five = [
  LiveExpectedSpecies(
    scientificName: 'Erithacus rubecula',
    commonName: 'Rougegorge familier',
    reason: LiveExpectedReason.frequent,
    goal: true,
  ),
  LiveExpectedSpecies(
    scientificName: 'Turdus merula',
    commonName: 'Merle noir',
    reason: LiveExpectedReason.frequent,
  ),
  LiveExpectedSpecies(
    scientificName: 'Parus major',
    commonName: 'Mésange charbonnière',
    reason: LiveExpectedReason.peak,
    goal: true,
  ),
  LiveExpectedSpecies(
    scientificName: 'Troglodytes troglodytes',
    commonName: 'Troglodyte mignon',
    reason: LiveExpectedReason.possible,
  ),
  LiveExpectedSpecies(
    scientificName: 'Phylloscopus collybita',
    commonName: 'Pouillot véloce',
    reason: LiveExpectedReason.possible,
    goal: true,
  ),
];

LiveTableEntry _entry(String name) => LiveTableEntry(
  scientificName: name,
  commonName: name,
  sessionCount: 1,
  total: 1,
  lastHeard: _morning,
  record: DetectionRecord(
    scientificName: name,
    commonName: name,
    confidence: 0.9,
    timestamp: _morning,
  ),
  singing: false,
);

void main() {
  group('liveExpectedSpecies', () {
    test('most likely birds first, unexpected and non-birds left out', () {
      final list = liveExpectedSpecies(
        commonness: {
          'A': _geo(0.5),
          'B': _geo(0.9),
          'Frog': _geo(0.95),
          'Rare': _geo(0.8, bin: CommonnessBin.rare),
          'Faint': _geo(kAbundanceInclusionThreshold / 2),
          'C': _geo(0.7),
        },
        isBird: (name) => name != 'Frog',
        commonName: (name) => 'nom $name',
        goal: {'C'},
      );
      expect(list.map((s) => s.scientificName), ['B', 'C', 'A']);
      expect(list.first.commonName, 'nom B');
      expect(list.map((s) => s.goal), [false, true, false]);
    });

    test('takes the configured count', () {
      final list = liveExpectedSpecies(
        commonness: {for (var i = 0; i < 12; i++) 'S$i': _geo(0.1 + i / 100)},
        isBird: (_) => true,
        commonName: (name) => name,
      );
      expect(list, hasLength(ReliabilityConfig.liveExpectedCount));
      expect(list.first.scientificName, 'S11');
    });

    test('reasons follow the geo-model only', () {
      expect(
        liveExpectedReason(_geo(0.3, bin: CommonnessBin.abundant)),
        LiveExpectedReason.frequent,
      );
      expect(
        liveExpectedReason(_geo(0.3, bin: CommonnessBin.common)),
        LiveExpectedReason.frequent,
      );
      // At its peak, not among the most common.
      expect(
        liveExpectedReason(_geo(0.3, annualMax: 0.33)),
        LiveExpectedReason.peak,
      );
      expect(
        liveExpectedReason(_geo(0.3, annualMax: 0.9)),
        LiveExpectedReason.possible,
      );
      expect(
        liveExpectedReason(_geo(0, annualMax: 0)),
        LiveExpectedReason.possible,
      );
    });
  });

  group('LiveExpectedView', () {
    testWidgets('title, goal count, reasons and « Objectif » pills', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(LiveExpectedView(now: _morning, species: _five)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attendus ici ce matin'), findsOneWidget);
      expect(
        find.text(
          "Ils s'allument dès qu'ils chantent. "
          '3 comptent pour ton objectif du jour.',
        ),
        findsOneWidget,
      );
      expect(find.text('Rougegorge familier'), findsOneWidget);
      expect(
        find.text('Parmi les plus fréquents ici en septembre'),
        findsNWidgets(2),
      );
      expect(find.text('En pleine saison ici'), findsOneWidget);
      expect(find.text('Peut chanter ici en septembre'), findsNWidgets(2));
      expect(find.text('Objectif'), findsNWidgets(3));
      expect(
        find.text('Micro vers le haut, ne bouge plus pendant une minute.'),
        findsOneWidget,
      );
    });

    testWidgets('part of the day in the title', (tester) async {
      for (final (hour, title) in [
        (14, 'Attendus ici cet après-midi'),
        (19, 'Attendus ici ce soir'),
        (23, 'Attendus ici cette nuit'),
      ]) {
        await tester.pumpWidget(
          _app(
            LiveExpectedView(
              now: DateTime(2026, 9, 28, hour),
              species: const [],
            ),
          ),
        );
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('no goal species: no goal sentence', (tester) async {
      await tester.pumpWidget(
        _app(
          LiveExpectedView(
            now: _morning,
            species: [
              for (final s in _five)
                LiveExpectedSpecies(
                  scientificName: s.scientificName,
                  commonName: s.commonName,
                  reason: s.reason,
                ),
            ],
          ),
        ),
      );
      expect(find.text("Ils s'allument dès qu'ils chantent."), findsOneWidget);
      expect(find.text('Objectif'), findsNothing);
    });

    testWidgets('English', (tester) async {
      await tester.pumpWidget(
        _app(
          LiveExpectedView(now: _morning, species: _five.take(1).toList()),
          locale: const Locale('en'),
        ),
      );
      expect(find.text('Expected here this morning'), findsOneWidget);
      expect(
        find.text('Among the most common here in September'),
        findsOneWidget,
      );
      expect(find.text('Goal'), findsOneWidget);
    });

    for (final size in const [Size(360, 520), Size(420, 300)]) {
      testWidgets('130 % text, ${size.width}×${size.height}: no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(LiveExpectedView(now: _morning, species: _five), textScale: 1.3),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The rows scroll: the tip is reachable.
        await tester.scrollUntilVisible(
          find.text('Micro vers le haut, ne bouge plus pendant une minute.'),
          100,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('LiveExpectedEmpty', () {
    Widget scoped(Map<String, GeoCommonnessEntry>? commonness) => ProviderScope(
      overrides: [
        taxonomyServiceProvider.overrideWith(
          (ref) => Completer<TaxonomyService>().future,
        ),
        effectiveSpeciesLocaleProvider.overrideWithValue('fr'),
        liveGoalSpeciesProvider.overrideWithValue({'Parus major'}),
      ],
      child: _app(
        LiveExpectedEmpty(commonness: commonness, now: () => _morning),
      ),
    );

    testWidgets('without the geo-model: title and tip only', (tester) async {
      await tester.pumpWidget(scoped(null));
      await tester.pumpAndSettle();
      expect(find.text('Attendus ici ce matin'), findsOneWidget);
      expect(
        find.text('Micro vers le haut, ne bouge plus pendant une minute.'),
        findsOneWidget,
      );
      expect(find.byType(LiveExpectedRow), findsNothing);
      expect(find.textContaining('objectif'), findsNothing);
    });

    testWidgets('with the geo-model: rows and the goal pill', (tester) async {
      await tester.pumpWidget(
        scoped({
          'Parus major': _geo(0.9, bin: CommonnessBin.abundant),
          'Turdus merula': _geo(0.8),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LiveExpectedRow), findsNWidgets(2));
      expect(find.text('Objectif'), findsOneWidget);
      expect(
        find.textContaining('1 compte pour ton objectif du jour.'),
        findsOneWidget,
      );
    });
  });

  group('LiveTable leaves the empty state', () {
    Widget table(List<LiveTableEntry> entries) => LiveTable(
      entries: entries,
      empty: LiveExpectedView(now: _morning, species: _five),
    );

    testWidgets('fades out as the first species comes in', (tester) async {
      await tester.pumpWidget(_app(table(const [])));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(table([_entry('Merle')])));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(LiveExpectedView), findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(LiveExpectedView),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.byType(LiveExpectedView), findsNothing);
      expect(find.text('Merle'), findsOneWidget);
    });

    testWidgets('reduced motion: gone at once', (tester) async {
      await tester.pumpWidget(_app(table(const []), reduceMotion: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app(table([_entry('Merle')]), reduceMotion: true),
      );
      await tester.pump();
      expect(find.byType(LiveExpectedView), findsNothing);
    });
  });

  group('contrast (AA)', () {
    const c = BirdyColors.dark;
    Color on(Color color, Color under) => Color.alphaBlend(color, under);
    void aa(Color fg, Color bg, String name, {double min = 4.5}) =>
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(min), reason: name);

    test('expected row, tip and goal pill on the dark background', () {
      final row = on(
        c.surface1.withValues(alpha: BirdyAlpha.expectedRow),
        c.background,
      );
      aa(c.text1, row, 'text1/expectedRow');
      aa(c.text2, row, 'text2/expectedRow');
      final tip = on(c.orioleContainer, c.background);
      aa(c.text1, tip, 'text1/tip');
      aa(c.orioleText, tip, 'orioleText icon/tip', min: 3);
      aa(c.onOriole, c.oriole, 'onOriole/oriole');
    });
  });
}
