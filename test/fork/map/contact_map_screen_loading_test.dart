/// Loading skeleton of the carte (J6f skeletons): the header caption
/// (« période · lieux ») waits on `_load()` (the index plus `mapPoints`),
/// which resolves after the first frame. Nothing else on this screen is in
/// scope here (fork/PLAN.md J6f skeletons b).
library;

import 'dart:async';

import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _loadRealFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load(asset).then((d) => d));
    await loader.load();
  }

  await load('Fraunces', 'assets/fonts/Fraunces-Variable.ttf');
  await load(
    'AtkinsonHyperlegibleNext',
    'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
  );
}

void main() {
  sqfliteFfiInit();
  setUpAll(_loadRealFonts);

  Future<void> pump(
    WidgetTester tester,
    Completer<ObservationIndex> gate, {
    bool dark = false,
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      kObservationIndexFilledVersion: ObservationIndex.schemaVersion,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = ObservationIndexService(
      repository: SessionRepository(),
      prefs: prefs,
      openIndex: () => gate.future,
    );
    tester.view.physicalSize = const Size(390, 844) * 2;
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
              (context, app) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reducedMotion,
                ),
                child: app!,
              ),
          home: const ContactMapScreen(),
        ),
      ),
    );
  }

  Future<void> resolveWith(
    WidgetTester tester,
    Completer<ObservationIndex> gate,
  ) async {
    final index = await tester.runAsync(() async {
      final index = await ObservationIndex.open(
        databaseFactoryFfi,
        inMemoryDatabasePath,
      );
      return index;
    });
    gate.complete(index);
    addTearDown(() => tester.runAsync(index!.close));
  }

  Future<void> expectStableLayout(WidgetTester tester) async {
    final gate = Completer<ObservationIndex>();
    await pump(tester, gate);
    await tester.pump();
    final header = tester.getRect(find.byKey(const ValueKey('map-header')));

    await resolveWith(tester, gate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getRect(find.byKey(const ValueKey('map-header'))),
      header,
      reason: 'header',
    );
    expect(find.textContaining('lieu'), findsOneWidget);
  }

  testWidgets('light, 100 %: no layout shift as the map data lands', (
    tester,
  ) async {
    await expectStableLayout(tester);
  });

  testWidgets('dark, 130 %: no layout shift as the map data lands', (
    tester,
  ) async {
    final gate = Completer<ObservationIndex>();
    await pump(tester, gate, dark: true, textScale: 1.3);
    await tester.pump();
    final header = tester.getRect(find.byKey(const ValueKey('map-header')));

    await resolveWith(tester, gate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getRect(find.byKey(const ValueKey('map-header'))),
      header,
      reason: 'header',
    );
    expect(find.textContaining('lieu'), findsOneWidget);
  });

  testWidgets('reduced motion: nothing animates while loading', (
    tester,
  ) async {
    final gate = Completer<ObservationIndex>();
    await pump(tester, gate, reducedMotion: true);
    await tester.pump();
    final before = tester.getRect(
      find.byKey(const ValueKey('map-header')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey('map-header'))),
        before,
      );
    }
    await resolveWith(tester, gate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('lieu'), findsOneWidget);
  });

  testWidgets('the caption skeleton is excluded from semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final gate = Completer<ObservationIndex>();
    await pump(tester, gate);
    await tester.pump();

    final data = tester.getSemantics(find.byType(ContactMapScreen));
    String allLabels(SemanticsNode node) {
      final buffer = StringBuffer(node.label);
      node.visitChildren((child) {
        buffer.write(' ');
        buffer.write(allLabels(child));
        return true;
      });
      return buffer.toString();
    }

    expect(allLabels(data), isNot(contains('00000000')));
    await resolveWith(tester, gate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    handle.dispose();
  });
}
