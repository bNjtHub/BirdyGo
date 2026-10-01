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
import 'package:birdnet_live/fork/world_map/gbif_cache.dart';
import 'package:birdnet_live/fork/world_map/gbif_map.dart';
import 'package:birdnet_live/fork/world_map/gbif_service.dart';
import 'package:birdnet_live/fork/world_map/land_outline.dart';
import 'package:birdnet_live/fork/world_map/season_presence.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_block.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:birdnet_live/fork/world_map/world_map_painter.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/world_map/world_map_section.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fonts.dart';

const _species = 'Hirundo rustica';

/// The faintest GBIF level is a density cue on top of a cell that is already
/// drawn: it only has to stay clearly visible. The two stronger levels and the
/// geo-model cells keep 3:1 (WCAG 1.4.11).
const double _faintestMinContrast = 1.5;

/// A synthetic GBIF map: a migrant seen in the north in summer (stronger
/// towards the south of the band) and in the tropics in winter.
SeasonPresence _gbifPresence() {
  final grid = GbifGrid.forZone();
  final levels = {
    for (final s in Season.values) s: Uint8List(grid.cellCount),
  };
  for (var cell = 0; cell < grid.cellCount; cell++) {
    final c = grid.centerOf(cell);
    if (c.latitude >= 50 && c.latitude <= 68 && c.longitude >= -10 && c.longitude <= 40) {
      levels[Season.summer]![cell] = c.latitude < 56 ? 3 : (c.latitude < 62 ? 2 : 1);
    }
    if (c.latitude >= 0 && c.latitude <= 15 && c.longitude >= -15 && c.longitude <= 10) {
      levels[Season.winter]![cell] = 3;
    }
  }
  return GbifSpeciesMap(
    taxonKey: 1,
    fetchedAt: DateTime(2026),
    cols: grid.cols,
    rows: grid.rows,
    levels: [for (final s in Season.values) levels[s]!],
  ).toPresence(grid);
}

/// A service that answers from memory (no disk, no network).
class _FakeGbif extends GbifMapService {
  _FakeGbif(this._result)
    : super(
        client: MockClient((_) async => throw StateError('no network')),
        cache: GbifMapCache(directory: () async => throw StateError('no disk')),
      );

  final Future<GbifSpeciesMap> Function() _result;

  @override
  Future<GbifSpeciesMap> load(String scientificName) => _result();
}

Future<SharedPreferences> _prefs({required bool consent}) async {
  SharedPreferences.setMockInitialValues({
    if (consent) 'privacy_allow_map': true,
  });
  return SharedPreferences.getInstance();
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
  VoidCallback? onGbifTap,
  VoidCallback? onLicenseTap,
  VoidCallback? onOnlineHintTap,
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
        onGbifTap: onGbifTap,
        onLicenseTap: onLicenseTap,
        onOnlineHintTap: onOnlineHintTap,
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
    Future<void> pumpSection(
      WidgetTester tester, {
      required bool consent,
      GeoPredict? predict,
      GbifMapService? gbif,
    }) async {
      final prefs = await _prefs(consent: consent);
      final outline = _outline();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            landOutlineProvider.overrideWith((ref) async => outline),
            worldMapPredictProvider.overrideWith((ref) async => predict),
            if (gbif != null) gbifMapServiceProvider.overrideWithValue(gbif),
            worldMapUserPositionProvider.overrideWith(
              (ref) async => (latitude: 48.85, longitude: 2.35),
            ),
          ],
          child: _app(
            const WorldMapSection(scientificName: _species, currentMonth: 7),
          ),
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

    testWidgets('hidden when the geo-model is not available', (tester) async {
      await pumpSection(tester, consent: false);
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapBlock), findsNothing);
      expect(find.text('Dans le monde'), findsNothing);
    });

    test('the page shows the block only when there is a map to draw', () async {
      Future<ProviderContainer> container({GeoPredict? predict}) async {
        final prefs = await _prefs(consent: false);
        final outline = _outline();
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            landOutlineProvider.overrideWith((ref) async => outline),
            worldMapPredictProvider.overrideWith((ref) async => predict),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      final none = await container();
      final sub1 = none.listen(worldMapVisibleProvider(_species), (_, _) {});
      expect(sub1.read(), isTrue, reason: 'loading: the skeleton is shown');
      await none.read(worldMapDataProvider(_species).future);
      expect(sub1.read(), isFalse, reason: 'no geo-model: no block, no gap');

      final some = await container(predict: _fake());
      final sub2 = some.listen(worldMapVisibleProvider(_species), (_, _) {});
      await some.read(worldMapDataProvider(_species).future);
      expect(sub2.read(), isTrue);
    });

    testWidgets('no consent: geo-model map, a hint, never a request', (
      tester,
    ) async {
      var asked = false;
      await pumpSection(
        tester,
        consent: false,
        predict: _fake(),
        gbif: _FakeGbif(() async {
          asked = true;
          return GbifSpeciesMap(
            taxonKey: 1,
            fetchedAt: DateTime(2026),
            cols: 0,
            rows: 0,
            levels: const [],
          );
        }),
      );
      expect(find.text('Dans le monde'), findsOneWidget, reason: 'skeleton');
      expect(find.byType(WorldMapBlock), findsNothing);
      await settle(tester);
      expect(find.byType(WorldMapBlock), findsOneWidget);
      expect(find.text('Estimation du géomodèle BirdNET'), findsOneWidget);
      expect(
        find.text('Carte précise : activez la carte en ligne'),
        findsOneWidget,
      );
      expect(asked, isFalse);
    });

    testWidgets('consent and GBIF answering: GBIF map and its credit', (
      tester,
    ) async {
      final grid = GbifGrid.forZone();
      await pumpSection(
        tester,
        consent: true,
        predict: _fake(),
        gbif: _FakeGbif(
          () async => GbifSpeciesMap(
            taxonKey: 1,
            fetchedAt: DateTime(2026),
            cols: grid.cols,
            rows: grid.rows,
            levels: [
              for (final _ in Season.values)
                Uint8List(grid.cellCount)..fillRange(5000, 5400, 2),
            ],
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Observations GBIF.org'), findsOneWidget);
      expect(find.text('CC BY 4.0'), findsOneWidget);
      expect(find.text('Estimation du géomodèle BirdNET'), findsNothing);
      expect(find.text('Carte précise : activez la carte en ligne'), findsNothing);
    });

    testWidgets('consent but GBIF fails: geo-model map, no hint', (
      tester,
    ) async {
      await pumpSection(
        tester,
        consent: true,
        predict: _fake(),
        gbif: _FakeGbif(() async => throw GbifUnavailable('offline')),
      );
      await settle(tester);
      expect(find.text('Estimation du géomodèle BirdNET'), findsOneWidget);
      expect(find.text('Carte précise : activez la carte en ligne'), findsNothing);
      expect(find.textContaining('GBIF'), findsNothing);
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

    testWidgets('credit with two links, key and legend', (tester) async {
      var gbifTaps = 0;
      var licenseTaps = 0;
      await _pumpBlock(
        tester,
        presence: gbif,
        source: WorldMapSource.gbif,
        nesting: const NestingPeriod(4, 7),
        onGbifTap: () => gbifTaps++,
        onLicenseTap: () => licenseTaps++,
      );
      expect(find.text('Observations GBIF.org'), findsOneWidget);
      expect(find.text('CC BY 4.0'), findsOneWidget);
      expect(find.text('Estimation du géomodèle BirdNET'), findsNothing);
      expect(find.text('Observé (plus foncé : plus souvent)'), findsOneWidget);
      expect(find.textContaining('Été : '), findsWidgets);
      expect(find.textContaining('km'), findsWidgets);
      expect(find.text('Nidification : avril à juillet'), findsOneWidget);
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

    testWidgets('a southern species is told in months, not seasons', (
      tester,
    ) async {
      final cells = [
        (latitude: -25.0, longitude: 25.0),
        (latitude: -5.0, longitude: 35.0),
      ];
      final south = SeasonPresence(
        cells,
        {
          for (final s in Season.values)
            s: [s == Season.summer, s == Season.winter],
        },
      );
      await _pumpBlock(tester, presence: south);
      expect(
        find.textContaining('juin à août : sud de l'),
        findsWidgets,
      );
      expect(find.textContaining('décembre à février : '), findsWidgets);
      expect(find.textContaining('Été : '), findsNothing);
    });

    testWidgets('the geo-model hint opens the setting', (tester) async {
      var taps = 0;
      await _pumpBlock(
        tester,
        presence: presence,
        onOnlineHintTap: () => taps++,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('world-map-online-hint')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('world-map-online-hint')));
      expect(taps, 1);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('world-map-online-hint')))
            .height,
        greaterThanOrEqualTo(BirdySizes.target),
      );
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
            onGbifTap: () {},
            onLicenseTap: () {},
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
            onGbifTap: () {},
            onLicenseTap: () {},
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
