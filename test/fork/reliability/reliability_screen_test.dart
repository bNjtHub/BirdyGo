/// Reliability screen (J6g-d): overlay header, skeleton while the index
/// loads, tinted blocks once it has answered.
library;

import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_headers.dart';
import 'package:birdnet_live/fork/reliability/reliability_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeIndex implements ObservationIndex {
  @override
  Future<Map<String, ({int confirmed, int reviewed})>> precisionByScoreBand({
    required double sureMin,
    required double probableMin,
  }) async => {
    'sure': (confirmed: 11, reviewed: 12),
    'probable': (confirmed: 3, reviewed: 6),
  };

  @override
  Future<
    List<
      ({String scientificName, String commonName, int confirmed, int reviewed})
    >
  >
  precisionBySpecies({required int minReviews}) async => [
    (
      scientificName: 'Parus major',
      commonName: 'Great Tit',
      confirmed: 4,
      reviewed: 5,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GatedService extends ObservationIndexService {
  _GatedService(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  final gate = Completer<void>();

  @override
  Future<ObservationIndex> ensureReady() async {
    await gate.future;
    return _FakeIndex();
  }
}

void main() {
  late _GatedService service;

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = _GatedService(prefs);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          observationIndexServiceProvider.overrideWith((ref) => service),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
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
          home: const ReliabilityScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('header and skeleton while loading, content after', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(BirdyOverlayHeader), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('reliabilitySkeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    service.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reliabilitySkeleton')), findsNothing);
    expect(find.text('92 %'), findsOneWidget);
    expect(find.text('80 %'), findsOneWidget);
  });

  testWidgets('small phone, 130 %, dark: no overflow', (tester) async {
    await pump(tester, dark: true, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    service.gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
