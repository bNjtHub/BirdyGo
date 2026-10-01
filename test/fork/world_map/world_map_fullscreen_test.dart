/// Full-screen world map (J7): the expand button, the page (legend, credit),
/// pinch / double tap, the re-render at the end of a gesture, taps under
/// zoom, goldens (Windows only, like the other fork goldens; regenerate with
/// `flutter test --update-goldens test/fork/world_map/world_map_fullscreen_test.dart`).
library;

import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/world_map/range_class.dart';
import 'package:birdnet_live/fork/world_map/range_frame.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:birdnet_live/fork/world_map/world_map_data.dart';
import 'package:birdnet_live/fork/world_map/world_map_fullscreen.dart';
import 'package:birdnet_live/fork/world_map/world_map_painter.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/world_map/world_map_section.dart';
import 'package:birdnet_live/fork/world_map/world_map_viewport.dart';
import 'package:birdnet_live/fork/world_map/world_regions.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import 'world_map_test_data.dart';

const _species = 'Apus apus';

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late WorldRegions regions;
  late Map<String, RangeClass> classes;

  setUpAll(() async {
    await loadAppFonts(icons: true);
    regions = realRegions();
    classes = fixtureClasses(regions, _species);
  });

  /// Windows rendered by the page, in order (its own raster calls).
  final frames = <MapFrame>[];

  Future<ui.Image> recordingRenderer(
    WorldMapScene scene,
    WorldMapColors colors,
    Size size,
    double ratio,
  ) {
    frames.add(scene.frame);
    return renderStaticLayer(scene, colors, size, ratio);
  }

  Widget page({bool dark = false}) => _app(
    WorldMapFullscreen(
      speciesName: 'Martinet noir',
      regions: regions,
      classes: classes,
      user: (latitude: 48.85, longitude: 2.35),
      source: WorldMapSource.gbif,
      generation: 20261001,
      onGbifTap: () {},
      onLicenseTap: () {},
      renderer: recordingRenderer,
    ),
    dark: dark,
  );

  /// Lets the scheduled task run and the engine rasterize (real async).
  Future<void> settleRaster(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpPage(WidgetTester tester, {bool dark = false}) async {
    frames.clear();
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(dark: dark));
    await settleRaster(tester);
  }

  final canvas = find.byKey(const ValueKey('world-map-fullscreen-canvas'));

  group('the button', () {
    testWidgets('the inline map opens the full-screen page', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            worldRegionsProvider.overrideWith((ref) async => regions),
            landCellsProvider.overrideWith((ref) async => landCells(regions)),
            worldRangesProvider.overrideWith(
              (ref) async => fixtureRanges(regions),
            ),
            worldMapPredictProvider.overrideWith((ref) async => null),
            worldMapUserPositionProvider.overrideWith((ref) async => null),
          ],
          child: _app(
            const Scaffold(
              body: SingleChildScrollView(
                child: WorldMapSection(
                  scientificName: _species,
                  speciesName: 'Martinet noir',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('world-map-expand'));
      expect(button, findsOneWidget);
      expect(
        tester.getSize(button).shortestSide,
        greaterThanOrEqualTo(48),
        reason: 'touch target',
      );
      expect(find.byType(WorldMapFullscreen), findsNothing);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WorldMapFullscreen), findsOneWidget);
      expect(find.text('Martinet noir'), findsOneWidget);
      // Close brings the species page back.
      await tester.tap(find.byKey(const ValueKey('world-map-close')));
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapFullscreen), findsNothing);
    });
  });

  group('the page', () {
    testWidgets('the legend and the credit are shown, with a semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      for (final label in [
        'Nidification',
        'Hivernage',
        "Toute l'année",
        'De passage',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Toi'), findsOneWidget);
      expect(find.textContaining('Nidification : '), findsOneWidget);
      expect(find.text('Observations GBIF.org (2026)'), findsOneWidget);
      expect(find.text('CC BY 4.0'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('Carte du monde de la répartition.*Nidification'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
      'a pinch moves the map, the layer is rendered again at its end',
      (tester) async {
        await pumpPage(tester);
        expect(frames, hasLength(1), reason: 'the first render');
        final home = frames.single;
        final c = tester.getCenter(canvas);
        final a = await tester.startGesture(
          c - const Offset(20, 0),
          pointer: 1,
        );
        final b = await tester.startGesture(
          c + const Offset(20, 0),
          pointer: 2,
        );
        await a.moveBy(const Offset(-60, 0));
        await b.moveBy(const Offset(60, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(frames, hasLength(1), reason: 'nothing is rendered mid-gesture');
        await a.up();
        await b.up();
        await settleRaster(tester);
        expect(frames, hasLength(2), reason: 'rendered once the fingers lift');
        final zoomed = frames.last;
        expect(
          zoomed.lon1 - zoomed.lon0,
          lessThan((home.lon1 - home.lon0) * 0.8),
        );
        expect(zoomed.lat1 - zoomed.lat0, lessThan(home.lat1 - home.lat0));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a double tap zooms in, and resets at the maximum', (
      tester,
    ) async {
      await pumpPage(tester);
      final home = frames.single;
      final at = tester.getCenter(canvas);
      Future<void> doubleTap() async {
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(at);
        await settleRaster(tester);
      }

      double span(MapFrame f) => f.lon1 - f.lon0;
      await doubleTap();
      expect(frames, hasLength(2));
      expect(
        span(frames.last),
        closeTo(span(home) / WorldMapConfig.doubleTapZoom, 1e-6),
      );
      // 2 -> 4 -> 8, then back to the framing.
      await doubleTap();
      await doubleTap();
      expect(
        span(frames.last),
        closeTo(span(home) / WorldMapConfig.maxScale, 1e-6),
      );
      await doubleTap();
      expect(frames.last, home);
    });

    testWidgets('a tap under zoom selects the region under the finger', (
      tester,
    ) async {
      await pumpPage(tester);
      final size = tester.getSize(canvas);
      final origin = tester.getTopLeft(canvas);
      final homeFrame = frames.single;
      // Zoom in around Paris with a double tap.
      final paris =
          origin + MapProjection(homeFrame, size).project(48.85, 2.35);
      await tester.tapAt(paris);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(paris);
      await settleRaster(tester);
      final zoomed = frames.last;
      expect(zoomed, isNot(homeFrame));
      // A point whose region differs between the two projections.
      String? expected;
      Offset? target;
      for (final (lat, lon) in [
        (50.0, 4.0),
        (47.0, 5.0),
        (46.0, 0.0),
        (50.5, 1.8),
        (47.5, -1.5),
        (49.5, 6.0),
      ]) {
        final screen = MapProjection(zoomed, size).project(lat, lon);
        if (screen.dx < 0 ||
            screen.dy < 0 ||
            screen.dx > size.width ||
            screen.dy > size.height) {
          continue;
        }
        final here = regions.regionAt(lon, lat);
        if (here == null || !classes.containsKey(here.id)) continue;
        final naive = MapProjection(homeFrame, size).unproject(screen);
        final wrong = regions.regionAt(naive.longitude, naive.latitude);
        if (wrong?.id == here.id) continue;
        expected = here.name;
        target = origin + screen;
        break;
      }
      expect(target, isNotNull, reason: 'a discriminating point exists');
      await tester.tapAt(target!);
      await tester.pump(const Duration(milliseconds: 400));
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('world-map-selected')),
      );
      expect(text.data, startsWith('$expected : '));
    });

    testWidgets('the screen reader can zoom', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      final home = frames.single;
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Carte du monde de la répartition')),
      );
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp("Carte du monde de la répartition")),
        ui.SemanticsAction.increase,
      );
      await settleRaster(tester);
      expect(frames, hasLength(2));
      expect(
        frames.last.lon1 - frames.last.lon0,
        lessThan(home.lon1 - home.lon0),
      );
      handle.dispose();
    });
  });

  group('the viewport', () {
    const size = Size(400, 800);

    test('zoom 1 frames the home window', () {
      final v = MapViewport.home((lon0: 0, lat0: 40, lon1: 10, lat1: 50), size);
      expect(v.zoom, 1);
      final f = v.frame;
      expect((f.lon0 + f.lon1) / 2, closeTo(5, 1e-9));
      expect((f.lat0 + f.lat1) / 2, closeTo(45, 1e-9));
    });

    test('anchored keeps the point under the finger, and clamps', () {
      final v = MapViewport.home(kWorldFrame, size);
      const finger = Offset(100, 200);
      final geo = MapProjection(v.frame, size).unproject(finger);
      final z = v.anchored(geo, finger, 4);
      final back = MapProjection(
        z.frame,
        size,
      ).project(geo.latitude, geo.longitude);
      expect(back.dx, closeTo(100, 1e-6));
      expect(back.dy, closeTo(200, 1e-6));
      expect(v.anchored(geo, finger, 100).zoom, WorldMapConfig.maxScale);
      expect(v.anchored(geo, finger, 0.1).zoom, WorldMapConfig.minScale);
      // Dragged far away: the window stays inside the map area.
      final far = z.anchored((latitude: 500, longitude: 500), Offset.zero, 4);
      expect(far.frame.lon1, lessThanOrEqualTo(WorldMapConfig.lonMax + 1e-9));
      expect(far.frame.lat1, lessThanOrEqualTo(WorldMapConfig.latMax + 1e-9));
    });
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'golden $mode',
      (tester) async {
        await pumpPage(tester, dark: dark);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('world_map_fullscreen_$mode.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isWindows,
    );
  }
}
