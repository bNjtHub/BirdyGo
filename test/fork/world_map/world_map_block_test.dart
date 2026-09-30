/// `WorldMapBlock` and `WorldMapSection` (J7): season chips, legend, hidden
/// without a geo-model, no overflow, contrast of the colored cells, goldens
/// (Windows only, like the other fork goldens; regenerate with
/// `flutter test --update-goldens test/fork/world_map`).
library;

import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_filter_chip.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/fork/world_map/land_outline.dart';
import 'package:birdnet_live/fork/world_map/season_presence.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_block.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:birdnet_live/fork/world_map/world_map_painter.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/world_map/world_map_section.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

const _species = 'Hirundo rustica';

LandOutline _outline() => LandOutline.parse(
  ByteData.sublistView(File(WorldMapConfig.landAsset).readAsBytesSync()),
);

bool _migrantPresence(double lat, double lon, int week) {
  if (week >= 22 && week <= 30) return lat >= 55 && lon >= -10 && lon <= 40;
  if (week <= 6 || week >= 42) return lat >= 0 && lat <= 15 && lon <= 10;
  return false;
}

GeoPredict _fake() =>
    ({
      required double latitude,
      required double longitude,
      required int week,
    }) async => {
      _species: _migrantPresence(latitude, longitude, week) ? 0.4 : 0.0,
    };

Future<SeasonPresence> _presence() => computeSeasonPresence(
  scientificName: _species,
  predict: _fake(),
  cells: landCells(_outline()),
  pause: Duration.zero,
);

Widget _app(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
  home: Builder(
    builder:
        (context) => Scaffold(
          backgroundColor: BirdyColors.of(context).background,
          body: Padding(
            padding: const EdgeInsets.all(BirdySpace.l),
            child: SingleChildScrollView(child: child),
          ),
        ),
  ),
);

Future<void> _pumpBlock(
  WidgetTester tester, {
  required SeasonPresence presence,
  double width = 412,
  double scale = 1,
  bool dark = false,
  int month = 7,
  NestingPeriod? nesting,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      WorldMapBlock(
        outline: _outline(),
        presence: presence,
        currentMonth: month,
        user: (latitude: 48.85, longitude: 2.35),
        nesting: nesting,
      ),
      dark: dark,
      scale: scale,
    ),
  );
  await tester.pump();
}

void main() {
  late SeasonPresence presence;

  setUpAll(() async {
    await loadAppFonts(icons: true);
    presence = await _presence();
  });

  group('season chips', () {
    testWidgets('current season is chosen, ink, and a tap changes it', (
      tester,
    ) async {
      await _pumpBlock(tester, presence: presence, month: 7);
      List<BirdyFilterChip> chips() =>
          tester
              .widgetList<BirdyFilterChip>(find.byType(BirdyFilterChip))
              .toList();
      expect(chips().map((c) => c.label), [
        'Hiver',
        'Printemps',
        'Été',
        'Automne',
      ]);
      expect(chips().map((c) => c.selected), [false, false, true, false]);
      expect(chips().every((c) => c.selectedColors != null), isTrue);

      await tester.tap(find.text('Hiver'));
      await tester.pump();
      expect(chips().map((c) => c.selected), [true, false, false, false]);
      final painter =
          tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((p) => p.painter)
              .whereType<WorldMapPainter>()
              .single;
      expect(painter.season, Season.winter);
    });

    testWidgets('the legend and a live label follow the season', (
      tester,
    ) async {
      await _pumpBlock(
        tester,
        presence: presence,
        nesting: const NestingPeriod(4, 7),
      );
      expect(find.textContaining('Été : nord de l'), findsWidgets);
      expect(find.textContaining('Afrique de l'), findsWidgets);
      expect(find.textContaining('km'), findsWidgets);
      expect(find.text('Nidification : avril à juillet'), findsOneWidget);
      expect(find.text('Estimation du géomodèle BirdNET'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Carte du monde, Été : ')),
        findsOneWidget,
      );
      await tester.tap(find.text('Automne'));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'^Carte du monde, Automne : ')),
        findsOneWidget,
      );
    });
  });

  group('section', () {
    testWidgets('hidden when the geo-model is not available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            worldMapPredictProvider.overrideWith((ref) async => null),
            worldMapUserPositionProvider.overrideWith((ref) async => null),
          ],
          child: _app(
            const WorldMapSection(scientificName: _species, currentMonth: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapBlock), findsNothing);
      expect(find.text('Dans le monde'), findsNothing);
    });

    testWidgets('skeleton first, then the block', (tester) async {
      final outline = _outline();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            landOutlineProvider.overrideWith((ref) async => outline),
            worldMapPredictProvider.overrideWith((ref) async => _fake()),
            worldMapUserPositionProvider.overrideWith(
              (ref) async => (latitude: 48.85, longitude: 2.35),
            ),
          ],
          child: _app(
            const WorldMapSection(scientificName: _species, currentMonth: 7),
          ),
        ),
      );
      expect(find.text('Dans le monde'), findsOneWidget, reason: 'skeleton');
      expect(find.byType(WorldMapBlock), findsNothing);
      // The provider pauses between batches: advance the fake clock.
      for (var i = 0; i < 400; i++) {
        if (find.byType(WorldMapBlock).evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapBlock), findsOneWidget);
    });
  });

  group('layout', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at ${width.toInt()} dp, text x$scale', (
          tester,
        ) async {
          await _pumpBlock(
            tester,
            presence: presence,
            width: width,
            scale: scale,
            nesting: const NestingPeriod(4, 7),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            _app(WorldMapBlock.skeleton(tester.element(find.byType(Scaffold)))),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('contrast of the cells (3:1, WCAG 1.4.11)', () {
    for (final bird in BirdyBird.values) {
      for (final brightness in Brightness.values) {
        test('${bird.name} ${brightness.name}', () {
          final c = BirdyColors.forBird(bird, brightness);
          final colors = WorldMapColors.of(c);
          final over = {
            'ocean': colors.ocean,
            'land': colors.land,
            'block': c.surface1,
          };
          for (final MapEntry(:key, :value) in over.entries) {
            expect(
              contrastRatio(colors.present, value),
              greaterThanOrEqualTo(3),
              reason: 'present on $key',
            );
            expect(
              contrastRatio(colors.user, value),
              greaterThanOrEqualTo(3),
              reason: 'user dot on $key',
            );
          }
        });
      }
    }
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'golden $mode',
      (tester) async {
        await _pumpBlock(tester, presence: presence, dark: dark);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('world_map_block_$mode.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isWindows,
    );
  }
}
