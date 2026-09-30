/// `WorldMapBlock` and `WorldMapSection` (J7): season chips, legend, hidden
/// without a geo-model, no overflow, contrast of the colored cells, goldens
/// (Windows only, like the other fork goldens; regenerate with
/// `flutter test --update-goldens test/fork/world_map`).
library;

import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_filter_chip.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/fork/world_map/gbif_ranges.dart';
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

/// The faintest GBIF level is a density cue on top of a cell that is already
/// drawn: it only has to stay clearly visible. The two stronger levels and the
/// geo-model cells keep 3:1 (WCAG 1.4.11).
const double _faintestMinContrast = 1.5;

const _meta = GbifMeta(
  demo: false,
  extractedAt: '2026-10-05',
  year: 2026,
  license: 'CC BY 4.0',
  licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
  doi: '10.15468/dl.abcdef',
  doiUrl: 'https://doi.org/10.15468/dl.abcdef',
);

SeasonPresence _gbifPresence() {
  final index = GbifIndex.parse(
    File(WorldMapConfig.gbifAsset).readAsBytesSync(),
  );
  return decodeGbifSpecies(
    GbifDecodeRequest(index.blockOf(_species)!, index.grid),
  );
}

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
  WorldMapSource source = WorldMapSource.geomodel,
  VoidCallback? onSourceTap,
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
        source: source,
        meta: source == WorldMapSource.gbif ? _meta : null,
        onSourceTap: onSourceTap,
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
            gbifIndexProvider.overrideWith((ref) async => null),
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
            gbifIndexProvider.overrideWith((ref) async => null),
            gbifMetaProvider.overrideWith((ref) async => null),
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

  group('GBIF source', () {
    late SeasonPresence gbif;

    setUpAll(() => gbif = _gbifPresence());

    testWidgets('mention, key and legend, with the DOI page one tap away', (
      tester,
    ) async {
      var taps = 0;
      await _pumpBlock(
        tester,
        presence: gbif,
        source: WorldMapSource.gbif,
        nesting: const NestingPeriod(4, 7),
        onSourceTap: () => taps++,
      );
      expect(
        find.text('Observations GBIF (dont eBird), CC BY 4.0 · 2026'),
        findsOneWidget,
      );
      expect(find.text('Estimation du géomodèle BirdNET'), findsNothing);
      expect(find.text('Observé (plus foncé : plus souvent)'), findsOneWidget);
      expect(find.textContaining('Été : '), findsWidgets);
      expect(find.textContaining('km'), findsWidgets);
      expect(find.text('Nidification : avril à juillet'), findsOneWidget);
      final target = tester.getSize(
        find.byKey(const ValueKey('world-map-source')),
      );
      expect(target.height, greaterThanOrEqualTo(BirdySizes.target));
      await tester.ensureVisible(find.byKey(const ValueKey('world-map-source')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('world-map-source')));
      expect(taps, 1);
    });

    testWidgets('the geo-model fallback keeps its own mention', (tester) async {
      await _pumpBlock(tester, presence: presence);
      expect(find.text('Estimation du géomodèle BirdNET'), findsOneWidget);
      expect(find.textContaining('GBIF'), findsNothing);
      expect(find.text('Attendu'), findsOneWidget);
    });

    testWidgets('the painter draws cells at the step of the data', (
      tester,
    ) async {
      const size = Size(900, 1000);
      const lonPx = 900 / 90;
      const latPx = 1000 / 105;
      final c = BirdyColors.forBird(BirdyBird.values.first, Brightness.light);
      final colors = WorldMapColors.of(c);
      Future<ui.Image> paint(SeasonPresence p, Season season) async {
        final recorder = ui.PictureRecorder();
        WorldMapPainter(
          outline: _outline(),
          presence: p,
          season: season,
          colors: colors,
        ).paint(Canvas(recorder), size);
        return recorder.endRecording().toImage(900, 1000);
      }

      Future<Color> pixel(ui.Image img, double lat, double lon) async {
        final bytes = (await img.toByteData())!;
        final x = ((lon - WorldMapConfig.lonMin) * lonPx).floor();
        final y = ((WorldMapConfig.latMax - lat) * latPx).floor();
        final o = (y * 900 + x) * 4;
        return Color.fromARGB(
          bytes.getUint8(o + 3),
          bytes.getUint8(o),
          bytes.getUint8(o + 1),
          bytes.getUint8(o + 2),
        );
      }

      await tester.runAsync(() async {
        // GBIF: the demo migrant is at the strongest level all over the north
        // in summer (several neighbouring 1 degree cells).
        final img = await paint(gbif, Season.summer);
        expect(await pixel(img, 55.5, 10.5), colors.levels[2]);
        expect(await pixel(img, 55.5, 12.5), colors.levels[2]);
        expect(await pixel(img, 55.5, 10.5), isNot(colors.ocean));
        // Geo-model: one cell is 5 degrees wide and tall.
        final geo = SeasonPresence(
          [(latitude: 52.5, longitude: 12.5)],
          {
            for (final s in Season.values) s: [s == Season.summer],
          },
        );
        final big = await paint(geo, Season.summer);
        expect(await pixel(big, 52.5, 12.5), colors.levels[2]);
        expect(await pixel(big, 54.0, 14.0), colors.levels[2]);
        expect(await pixel(big, 55.5, 12.5), isNot(colors.levels[2]));
        // A single 1 degree GBIF cell does not reach 2 degrees away.
        final one = SeasonPresence(
          [(latitude: 52.5, longitude: 12.5)],
          {
            for (final s in Season.values) s: [s == Season.summer],
          },
          step: 1,
          levels: {
            for (final s in Season.values) s: [3],
          },
        );
        final small = await paint(one, Season.summer);
        expect(await pixel(small, 52.5, 12.5), colors.levels[2]);
        expect(await pixel(small, 52.5, 14.5), isNot(colors.levels[2]));
        expect(await pixel(small, 54.5, 12.5), isNot(colors.levels[2]));
      });
    });

    testWidgets('intensity is the same tint at growing opacity', (
      tester,
    ) async {
      final c = BirdyColors.forBird(BirdyBird.values.first, Brightness.dark);
      final colors = WorldMapColors.of(c);
      expect(colors.levels.length, WorldMapConfig.gbifLevels);
      expect(colors.levels.last, colors.present);
      expect(
        contrastRatio(colors.levels[0], colors.land),
        lessThan(contrastRatio(colors.levels[1], colors.land)),
      );
      expect(
        contrastRatio(colors.levels[1], colors.land),
        lessThan(contrastRatio(colors.levels[2], colors.land)),
      );
    });

    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at ${width.toInt()} dp, text x$scale', (
          tester,
        ) async {
          await _pumpBlock(
            tester,
            presence: gbif,
            width: width,
            scale: scale,
            source: WorldMapSource.gbif,
            nesting: const NestingPeriod(4, 7),
            onSourceTap: () {},
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'golden gbif $mode',
        (tester) async {
          await _pumpBlock(
            tester,
            presence: gbif,
            dark: dark,
            source: WorldMapSource.gbif,
            onSourceTap: () {},
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('world_map_block_gbif_$mode.png'),
          );
        },
        tags: ['golden'],
        skip: !Platform.isWindows,
      );
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
            for (final (i, level) in colors.levels.indexed) {
              expect(
                contrastRatio(level, value),
                greaterThanOrEqualTo(i == 0 ? _faintestMinContrast : 3),
                reason: 'GBIF level ${i + 1} on $key',
              );
            }
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
