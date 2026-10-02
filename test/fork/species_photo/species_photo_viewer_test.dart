import 'dart:convert';
import 'dart:io' show Platform;

import 'package:birdnet_live/fork/species_photo/photo_credit.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_viewer.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

/// A 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

final _photos = [
  ViewerPhoto(
    MemoryImage(_png),
    const PhotoCredit(
      author: 'Ann',
      license: 'cc-by',
      source: 'iNaturalist',
      pageUrl: 'https://www.inaturalist.org/photos/1',
    ),
  ),
  ViewerPhoto(
    MemoryImage(_png),
    const PhotoCredit(author: 'Bob', license: 'cc0', source: 'iNaturalist'),
  ),
  ViewerPhoto(MemoryImage(_png), const PhotoCredit(author: 'Cy')),
];

Future<void> _open(
  WidgetTester tester, {
  int page = 0,
  bool reduced = false,
  List<ViewerPhoto>? photos,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed:
                        () => showSpeciesPhotoViewer(
                          context,
                          photos: photos ?? _photos,
                          initialPage: page,
                          heroTag: 'hero',
                        ),
                    child: const Text('open'),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder get _viewer => find.byType(SpeciesPhotoViewer);

TransformationController _tc(WidgetTester tester) =>
    tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
        .transformationController!;

Future<void> _doubleTap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the page asked, credit and dots shown', (tester) async {
    await _open(tester, page: 1);
    expect(find.bySemanticsLabel('Photo 2 sur 3'), findsOneWidget);
    expect(find.text('Bob · CC0 1.0 · iNaturalist'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('photo-dot-$i')), findsOneWidget);
    }
  });

  testWidgets('one photo: no dots', (tester) async {
    await _open(tester, photos: [_photos.first]);
    expect(find.byKey(const ValueKey('photo-dot-0')), findsNothing);
    expect(find.text('Ann · CC BY · iNaturalist'), findsOneWidget);
  });

  testWidgets('swipe changes page and credit', (tester) async {
    await _open(tester);
    expect(find.text('Ann · CC BY · iNaturalist'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Bob · CC0 1.0 · iNaturalist'), findsOneWidget);
  });

  testWidgets('zoomed: horizontal drag pans, page does not change', (
    tester,
  ) async {
    await _open(tester);
    final center = tester.getCenter(find.byType(PageView));
    await _doubleTap(tester, center + const Offset(100, 50));
    expect(_tc(tester).value.getMaxScaleOnAxis(), closeTo(2, 0.01));

    await tester.fling(find.byType(PageView), const Offset(-100, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Ann · CC BY · iNaturalist'), findsOneWidget);
    expect(find.text('Bob · CC0 1.0 · iNaturalist'), findsNothing);
    expect(_tc(tester).value.getMaxScaleOnAxis(), closeTo(2, 0.01));

    // Double tap again: back to 1x, and swiping works again.
    await _doubleTap(tester, center);
    expect(_tc(tester).value.getMaxScaleOnAxis(), closeTo(1, 0.01));
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Bob · CC0 1.0 · iNaturalist'), findsOneWidget);
  });

  testWidgets('drag down closes; a short drag springs back', (tester) async {
    await _open(tester);
    await tester.drag(find.byType(PageView), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(_viewer, findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(_viewer, findsNothing);
  });

  testWidgets('close button closes', (tester) async {
    await _open(tester);
    expect(find.byTooltip('Fermer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewer-close')));
    await tester.pumpAndSettle();
    expect(_viewer, findsNothing);
  });

  testWidgets('reduced motion: no follow, no animation, still closes', (
    tester,
  ) async {
    await _open(tester, reduced: true);
    // The photo does not follow the finger.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 10));
    }
    await tester.pump();
    final transform = tester.widget<Transform>(
      find
          .ancestor(of: find.byType(PageView), matching: find.byType(Transform))
          .first,
    );
    expect(transform.transform.getTranslation().y, 0);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, 10));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_viewer, findsNothing);

    await _open(tester, reduced: true);
    final c = tester.getCenter(find.byType(PageView));
    await tester.tapAt(c);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(c);
    await tester.pump(); // no animation: the zoom is immediate
    expect(_tc(tester).value.getMaxScaleOnAxis(), closeTo(2, 0.01));
    await tester.pumpAndSettle();
  });

  testWidgets('credit without a page opens the credit sheet', (tester) async {
    await _open(tester, page: 2);
    await tester.tap(find.byKey(const ValueKey('viewer-credit')));
    await tester.pumpAndSettle();
    expect(find.text('Photo : Cy'), findsOneWidget);
  });

  testWidgets(
    'golden: the viewer',
    (tester) async {
      await loadAppFonts(icons: true);
      tester.view.physicalSize = const Size(412, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const image = AssetImage('assets/images/dummy_species.png');
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
      });
      await _open(
        tester,
        page: 1,
        photos: [
          ViewerPhoto(image, _photos[0].credit),
          ViewerPhoto(image, _photos[1].credit),
          ViewerPhoto(image, _photos[2].credit),
        ],
      );
      await tester.runAsync(() async {
        await precacheImage(image, tester.element(_viewer));
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('species_photo_viewer.png'),
      );
    },
    tags: ['golden'],
    skip: !Platform.isWindows,
  );
}
