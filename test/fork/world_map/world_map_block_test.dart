/// `WorldMapBlock` and `WorldMapSection` (J7): the four colors and their key,
/// the summary, taps on a region, bundled GBIF range or geo-model data, no
/// overflow, contrast of the four colors, goldens (Windows only, like the
/// other fork goldens; regenerate with
/// `flutter test --update-goldens test/fork/world_map`).
library;

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/fork/world_map/range_class.dart';
import 'package:birdnet_live/fork/world_map/range_frame.dart';
import 'package:birdnet_live/fork/world_map/season_presence.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_block.dart';
import 'package:birdnet_live/fork/world_map/world_map_data.dart';
import 'package:birdnet_live/fork/world_map/world_map_painter.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/world_map/world_map_section.dart';
import 'package:birdnet_live/fork/world_map/world_ranges.dart';
import 'package:birdnet_live/fork/world_map/world_regions.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import 'world_map_test_data.dart';

const _species = 'Apus apus';

/// CIE76 distance between two colors: how different they look.
double _deltaE(Color a, Color b) {
  List<double> lab(Color c) {
    double lin(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final r = lin(c.r), g = lin(c.g), bl = lin(c.b);
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * bl) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * bl;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * bl) / 1.08883;
    double f(double t) =>
        t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
    return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
  }

  final p = lab(a), q = lab(b);
  return math.sqrt(
    math.pow(p[0] - q[0], 2) + math.pow(p[1] - q[1], 2) + math.pow(p[2] - q[2], 2),
  );
}

/// The four colors told apart by hue: at least this far apart (CIE76).
const double _minDeltaE = 30;

bool _swallowPresence(double lat, double lon, int week) {
  if (week >= 22 && week <= 30) return lat >= 55 && lon >= -10 && lon <= 40;
  if (week <= 6 || week >= 42) return lat >= 0 && lat <= 15 && lon <= 10;
  return false;
}

GeoPredict _fakeGeo() =>
    ({
      required double latitude,
      required double longitude,
      required int week,
    }) async => {_species: _swallowPresence(latitude, longitude, week) ? 0.4 : 0.0};

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

void main() {
  late WorldRegions regions;
  late Map<String, RangeClass> classes;

  setUpAll(() async {
    await loadAppFonts(icons: true);
    regions = realRegions();
    classes = fixtureClasses(regions, _species);
  });

  Future<void> pumpBlock(
    WidgetTester tester, {
    double width = 412,
    double scale = 1,
    bool dark = false,
    Map<String, RangeClass>? classesOverride,
    NestingPeriod? nesting,
    WorldMapSource source = WorldMapSource.gbif,
    int? generation = 20261001,
    VoidCallback? onGbifTap,
    VoidCallback? onLicenseTap,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        WorldMapBlock(
          regions: regions,
          classes: classesOverride ?? classes,
          user: (latitude: 48.85, longitude: 2.35),
          nesting: nesting,
          source: source,
          generation: generation,
          onGbifTap: onGbifTap,
          onLicenseTap: onLicenseTap,
        ),
        dark: dark,
        scale: scale,
      ),
    );
    // The scene is built in a task after the first frame, then cross-fades in.
    await tester.pump();
    await tester.pump();
    // The static layer is rasterized on the engine's thread: real async.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  group('the block', () {
    testWidgets('four colors in the key, a summary, the credit', (
      tester,
    ) async {
      var gbifTaps = 0;
      var licenseTaps = 0;
      await pumpBlock(
        tester,
        nesting: const NestingPeriod(4, 7),
        onGbifTap: () => gbifTaps++,
        onLicenseTap: () => licenseTaps++,
      );
      for (final label in ['Nidification', 'Hivernage', "Toute l'année", 'De passage']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final c in RangeClass.values) {
        expect(find.byKey(ValueKey('world-map-key-${c.name}')), findsOneWidget);
      }
      expect(find.text('Toi'), findsOneWidget);
      expect(find.textContaining('Nidification : '), findsNWidgets(2), reason: 'summary and nesting months');
      expect(find.textContaining('Hivernage : '), findsOneWidget);
      expect(find.textContaining('km'), findsOneWidget);
      expect(find.text('Nidification : avril à juillet'), findsOneWidget);
      expect(find.text('Observations GBIF.org (2026)'), findsOneWidget);
      expect(find.text('CC BY 4.0'), findsOneWidget);
      expect(find.text('Estimation du géomodèle BirdNET'), findsNothing);
      for (final key in ['world-map-source', 'world-map-license']) {
        final target = tester.getSize(find.byKey(ValueKey(key)));
        expect(target.height, greaterThanOrEqualTo(BirdySizes.target));
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey(key)));
      }
      expect(gbifTaps, 1);
      expect(licenseTaps, 1);
    });

    testWidgets('the semantics sum the map up in words', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBlock(tester);
      expect(
        find.bySemanticsLabel(RegExp('Carte du monde de la répartition.*Nidification')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a tap on a region names it and its class, a second one clears', (
      tester,
    ) async {
      await pumpBlock(tester);
      final canvas = find.byKey(const ValueKey('world-map-canvas'));
      final size = tester.getSize(canvas);
      final origin = tester.getTopLeft(canvas);
      final projection = MapProjection(frameOf(regions, classes), size);
      final paris = projection.project(48.85, 2.35);
      await tester.tapAt(origin + paris);
      await tester.pump();
      expect(find.text('Paris : Nidification'), findsOneWidget);
      await tester.tapAt(origin + paris);
      await tester.pump();
      expect(find.byKey(const ValueKey('world-map-selected')), findsNothing);
      // The sea selects nothing.
      await tester.tapAt(origin + projection.project(35, -20));
      await tester.pump();
      expect(find.byKey(const ValueKey('world-map-selected')), findsNothing);
    });

    testWidgets('an empty range says so, without a distance', (tester) async {
      await pumpBlock(tester, classesOverride: const {});
      expect(find.text('Aucune présence estimée dans la zone affichée'), findsOneWidget);
    });

    testWidgets('the geo-model mention, no GBIF credit', (tester) async {
      await pumpBlock(tester, source: WorldMapSource.geomodel);
      expect(find.text('Estimation du géomodèle BirdNET'), findsOneWidget);
      expect(find.textContaining('GBIF'), findsNothing);
    });

    testWidgets('without a generation date the credit has no year', (
      tester,
    ) async {
      await pumpBlock(tester, generation: null);
      expect(find.text('Observations GBIF.org'), findsOneWidget);
    });

    test('the painter repaints only for what changed', () {
      final colors = WorldMapColors.of(BirdyColors.light);
      WorldMapPainter painter({String? selected, Map<String, RangeClass>? c}) =>
          WorldMapPainter(
            regions: regions,
            classes: c ?? classes,
            frame: kWorldFrame,
            colors: colors,
            selected: selected,
          );
      final base = painter();
      expect(painter().shouldRepaint(base), isFalse);
      expect(painter(selected: 'x').shouldRepaint(base), isTrue);
      expect(painter(c: const {}).shouldRepaint(base), isTrue);
    });
  });

  group('layout', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at ${width.toInt()} dp, text x$scale', (
          tester,
        ) async {
          await pumpBlock(
            tester,
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

  group('section', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      WorldRanges? ranges,
      GeoPredict? predict,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            worldRegionsProvider.overrideWith((ref) async => regions),
            landCellsProvider.overrideWith((ref) async => landCells(regions)),
            worldRangesProvider.overrideWith((ref) async => ranges),
            worldMapPredictProvider.overrideWith((ref) async => predict),
            worldMapUserPositionProvider.overrideWith(
              (ref) async => (latitude: 48.85, longitude: 2.35),
            ),
          ],
          child: _app(const WorldMapSection(scientificName: _species)),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      // The geo-model provider pauses between batches: advance the fake clock.
      for (var i = 0; i < 400; i++) {
        if (find.byType(WorldMapBlock).evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
    }

    testWidgets('hidden when there is no range and no geo-model', (tester) async {
      await pumpSection(tester);
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapBlock), findsNothing);
      expect(find.text('Dans le monde'), findsNothing);
    });

    testWidgets('a bundled range: the map at once, its credit, no geo-model', (
      tester,
    ) async {
      await pumpSection(tester, ranges: fixtureRanges(regions));
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapBlock), findsOneWidget);
      expect(find.text('Observations GBIF.org (2026)'), findsOneWidget);
      expect(find.text('Estimation du géomodèle BirdNET'), findsNothing);
      expect(find.textContaining('Hivernage : '), findsOneWidget);
    });

    testWidgets('a species missing from the ranges: the geo-model map', (
      tester,
    ) async {
      await pumpSection(
        tester,
        ranges: WorldRanges.parse(writeRanges({'Other species': {}})),
        predict: _fakeGeo(),
      );
      await settle(tester);
      expect(find.byType(WorldMapBlock), findsOneWidget);
      expect(find.text('Estimation du géomodèle BirdNET'), findsOneWidget);
      expect(find.textContaining('GBIF'), findsNothing);
      expect(find.textContaining('Nidification : '), findsOneWidget);
    });

    testWidgets('no ranges asset: the geo-model map', (tester) async {
      await pumpSection(tester, predict: _fakeGeo());
      await settle(tester);
      expect(find.text('Estimation du géomodèle BirdNET'), findsOneWidget);
    });

    test('the page shows the block only when there is a map to draw', () async {
      ProviderContainer container({GeoPredict? predict, WorldRanges? ranges}) {
        final c = ProviderContainer(
          overrides: [
            worldRegionsProvider.overrideWith((ref) async => regions),
            landCellsProvider.overrideWith((ref) async => landCells(regions)),
            worldRangesProvider.overrideWith((ref) async => ranges),
            worldMapPredictProvider.overrideWith((ref) async => predict),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      final none = container();
      final sub1 = none.listen(worldMapVisibleProvider(_species), (_, _) {});
      expect(sub1.read(), isTrue, reason: 'loading: the skeleton is shown');
      await none.read(worldMapDataProvider(_species).future);
      expect(sub1.read(), isFalse, reason: 'no data: no block, no gap');

      final some = container(predict: _fakeGeo());
      final sub2 = some.listen(worldMapVisibleProvider(_species), (_, _) {});
      await some.read(worldMapDataProvider(_species).future);
      expect(sub2.read(), isTrue);

      final ranged = container(ranges: fixtureRanges(regions));
      final sub3 = ranged.listen(worldMapVisibleProvider(_species), (_, _) {});
      await ranged.read(worldMapDataProvider(_species).future);
      expect(sub3.read(), isTrue);
    });
  });

  group('contrast of the four colors', () {
    for (final bird in BirdyBird.values) {
      for (final brightness in Brightness.values) {
        test('${bird.name} ${brightness.name}: 3:1 on the map, told apart', () {
          final c = BirdyColors.forBird(bird, brightness);
          final colors = WorldMapColors.of(c);
          final over = {
            'ocean': colors.ocean,
            'land': colors.land,
            'block': c.surface1,
          };
          for (final MapEntry(key: cls, value: color) in colors.classes.entries) {
            for (final MapEntry(:key, :value) in over.entries) {
              expect(
                contrastRatio(color, value),
                greaterThanOrEqualTo(3),
                reason: '${cls.name} on $key',
              );
            }
          }
          for (final MapEntry(:key, :value) in over.entries) {
            expect(
              contrastRatio(colors.user, value),
              greaterThanOrEqualTo(3),
              reason: 'user dot on $key',
            );
          }
          // Two colors cannot all differ by 3:1 in luminance (there are four);
          // they differ in hue.
          final list = colors.classes.entries.toList();
          for (var i = 0; i < list.length; i++) {
            for (var j = i + 1; j < list.length; j++) {
              expect(
                _deltaE(list[i].value, list[j].value),
                greaterThanOrEqualTo(_minDeltaE),
                reason: '${list[i].key.name} / ${list[j].key.name}',
              );
            }
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
        await pumpBlock(
          tester,
          dark: dark,
          onGbifTap: () {},
          onLicenseTap: () {},
          nesting: const NestingPeriod(4, 7),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('world_map_block_$mode.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isWindows,
    );

    testWidgets(
      'golden geo-model $mode',
      (tester) async {
        final cells = landCells(regions);
        final presence = (await tester.runAsync(() => computeSeasonPresence(
          scientificName: _species,
          predict: _fakeGeo(),
          cells: cells,
          pause: Duration.zero,
        )))!;
        await pumpBlock(
          tester,
          dark: dark,
          classesOverride: classesFromPresence(presence, regions),
          source: WorldMapSource.geomodel,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('world_map_block_geomodel_$mode.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isWindows,
    );
  }
}
