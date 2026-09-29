/// Profil/Quiz style of the contact map (J6g-f): markers on tokens in the
/// dark theme, sheet rows and their navigation, the loading skeleton and a
/// small phone at 130 % in the dark theme.
library;

import 'dart:async';

import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/fork/map/contact_map_sheets.dart';
import 'package:birdnet_live/fork/map/map_loading.dart';
import 'package:birdnet_live/fork/map/map_markers.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _app(Widget home, {bool dark = false, double textScale = 1}) {
  return ProviderScope(
    child: MaterialApp(
      theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: Scaffold(body: Center(child: home)),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester, String key) =>
    tester.widget<Container>(find.byKey(ValueKey(key))).decoration!
        as BoxDecoration;

void main() {
  sqfliteFfiInit();

  group('markers on tokens', () {
    for (final dark in [false, true]) {
      testWidgets('species marker, ${dark ? 'dark' : 'light'} theme', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            const SpeciesMarkerView(image: null, count: 12, selected: false),
            dark: dark,
          ),
        );
        final c = dark ? BirdyColors.dark : BirdyColors.light;
        final disc = _decoration(tester, 'map-marker-disc');
        expect(disc.color, BirdyMapStyle.disc);
        expect(disc.boxShadow!.first.color, c.accent);
        expect(disc.boxShadow!.first.spreadRadius, BirdyMapStyle.markerRing);
        expect(disc.boxShadow!.last.color, BirdyMapStyle.shadow);
        expect(
          _decoration(tester, 'map-marker-badge').color,
          BirdyMapStyle.badge,
        );
        final label = tester.widget<Text>(find.text('12'));
        expect(label.style!.color, BirdyMapStyle.onBadge);
        expect(label.style!.fontSize, 13, reason: 'on the type scale');
        expect(
          contrastRatio(BirdyMapStyle.badge, BirdyMapStyle.onBadge),
          greaterThan(7),
        );
      });
    }

    testWidgets('a selected spot rings the marker in Loriot (dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SpeciesMarkerView(image: null, count: 3, selected: true),
          dark: true,
        ),
      );
      expect(
        _decoration(tester, 'map-marker-disc').boxShadow!.first.color,
        BirdyColors.dark.oriole,
      );
    });

    testWidgets('cluster bubble in the dark theme uses tokens only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const ClusterBubbleView(species: 7, unit: 'espèces'), dark: true),
      );
      final bubble = _decoration(tester, 'map-cluster-disc');
      expect(bubble.color, BirdyColors.dark.accent);
      final border = bubble.border! as Border;
      expect(border.top.color, BirdyMapStyle.disc);
      expect(border.top.width, BirdyMapStyle.clusterBorder);
      final unit = tester.widget<Text>(find.text('espèces'));
      expect(unit.style!.color, BirdyMapStyle.onCluster);
      expect(unit.style!.fontSize, BirdyMapStyle.clusterLabelSize);
      expect(BirdyMapStyle.clusterLabelSize, 13);
      expect(
        contrastRatio(BirdyColors.dark.accent, BirdyMapStyle.onCluster),
        greaterThan(4.5),
      );
    });
  });

  group('sheet rows', () {
    testWidgets('a species row is 60 dp tall and taps through', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 320,
            child: MapSpeciesRow(
              scientificName: 'Erithacus rubecula',
              name: 'Rougegorge familier',
              count: 44,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(MapSpeciesRow));
      expect(size.height, greaterThanOrEqualTo(60));
      expect(find.text('Erithacus rubecula'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-avatar-ring')), findsOneWidget);
      await tester.tap(find.text('Rougegorge familier'));
      expect(taps, 1);
    });

    testWidgets('the species picker returns the tapped species', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      SpeciesChoice? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: BirdyTheme.light(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        result = await showSpeciesPicker(
                          context,
                          tallies: [
                            SpeciesTally(
                              scientificName: 'Turdus merula',
                              commonName: 'Merle noir',
                              contacts: 35,
                              days: 3,
                              first: DateTime(2026, 9, 1),
                              last: DateTime(2026, 9, 20),
                            ),
                          ],
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Toutes les espèces'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      await tester.tap(find.text('Merle noir'));
      await tester.pumpAndSettle();
      expect(result?.scientificName, 'Turdus merula');
      expect(result?.commonName, 'Merle noir');
    });

    testWidgets('the choice sheet has 60 dp rows and returns the option', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: BirdyTheme.light(),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showChoiceSheet<String>(
                        context,
                        title: 'Période',
                        options: const ['a', 'b'],
                        selected: 'a',
                        label: (o) => 'Option $o',
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Période'), findsOneWidget);
      final rowBox = tester.getSize(
        find
            .ancestor(
              of: find.text('Option b'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(rowBox.height, greaterThanOrEqualTo(BirdySizes.rowCompact));
      await tester.tap(find.text('Option b'));
      await tester.pumpAndSettle();
      expect(result, 'b');
    });
  });

  group('loading skeleton', () {
    Future<Completer<ObservationIndex>> pumpLoading(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      bool dark = false,
      double textScale = 1,
    }) async {
      SharedPreferences.setMockInitialValues({
        kObservationIndexFilledVersion: ObservationIndex.schemaVersion,
      });
      final prefs = await SharedPreferences.getInstance();
      final gate = Completer<ObservationIndex>();
      final service = ObservationIndexService(
        repository: SessionRepository(),
        prefs: prefs,
        openIndex: () => gate.future,
      );
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            observationIndexServiceProvider.overrideWith((ref) => service),
          ],
          child: MaterialApp(
            theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
            home: const ContactMapScreen(),
          ),
        ),
      );
      await tester.pump();
      return gate;
    }

    testWidgets('a sheet-shaped skeleton replaces the spinner', (tester) async {
      await pumpLoading(tester);
      expect(
        find.byKey(const ValueKey('map-loading-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(MapLoadingSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the skeleton is announced once', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLoading(tester);
      expect(find.bySemanticsLabel('Chargement de la carte'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('320 dp, 130 %, dark: the skeleton lays out', (tester) async {
      await pumpLoading(
        tester,
        size: const Size(320, 568),
        dark: true,
        textScale: 1.3,
      );
      final error = tester.takeException();
      expect(error is FlutterError ? error.toStringDeep() : null, isNull);
      expect(
        find.byKey(const ValueKey('map-loading-skeleton')),
        findsOneWidget,
      );
    });
  });

  group('small phone', () {
    testWidgets('320 dp, 130 %, dark: markers and sheet rows lay out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SpeciesMarkerView(image: null, count: 128, selected: false),
              const ClusterBubbleView(species: 99, unit: 'espèces'),
              Padding(
                padding: const EdgeInsets.all(16),
                child: MapSpeciesRow(
                  scientificName: 'Phylloscopus collybita',
                  name: 'Pouillot véloce à nom très très long',
                  count: 1234,
                  onTap: () {},
                ),
              ),
            ],
          ),
          dark: true,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1234'), findsOneWidget);
    });
  });
}
