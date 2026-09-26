import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/bilan/bilan_loader.dart';
import 'package:birdnet_live/fork/bilan/bilan_screen.dart';
import 'package:birdnet_live/fork/bilan/bilan_widgets.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bilan_fixture.dart';

/// Loader without index, geo-model nor network.
class _FakeLoader implements BilanLoader {
  _FakeLoader(this.inputsFor, {this.place});

  final BilanInputs Function(LiveSession session) inputsFor;
  final String? place;
  int loads = 0;

  @override
  Future<BilanInputs> load(LiveSession session) async {
    loads++;
    return inputsFor(session);
  }

  @override
  Future<String?> placeName(LiveSession session) async => place;
}

/// Index that never opens: the quick review stays on its spinner.
class _PendingIndex extends ObservationIndexService {
  _PendingIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

BilanInputs _morning(LiveSession session) => BilanInputs(
  session: session,
  presence: morningPresence(),
  heardBefore: heardBeforeMorning(),
);

const _dot = ValueKey('bilan-pending-dot');

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_FakeLoader> pump(
    WidgetTester tester, {
    LiveSession? session,
    BilanInputs Function(LiveSession)? inputs,
    String? place = 'Beaulieu-sur-Brenne',
    bool dark = false,
    double textScale = 1,
    bool reduceMotion = false,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final loader = _FakeLoader(inputs ?? _morning, place: place);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bilanLoaderProvider.overrideWithValue(loader),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith(
            (ref) => _PendingIndex(prefs),
          ),
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
                  disableAnimations: reduceMotion,
                ),
                child: app!,
              ),
          home: BilanScreen(session: session ?? morningSession()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return loader;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('the mockup morning (SPEC 9.8)', (tester) async {
    await pump(tester);

    expect(find.text("Bilan de l'écoute"), findsOneWidget);
    expect(find.byTooltip('Terminer'), findsOneWidget);
    expect(find.byTooltip('Revoir sur la carte'), findsOneWidget);
    expect(find.byTooltip('Partager'), findsOneWidget);
    expect(find.text('Belle matinée !'), findsOneWidget);
    expect(
      find.text('Samedi 26 septembre · 7 h 12 – 7 h 54 · Beaulieu-sur-Brenne'),
      findsOneWidget,
    );
    for (final text in ['13', 'espèces', '52', 'contacts', '42 min', 'durée']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    await scrollTo(tester, find.text('Huppe fasciée'));
    expect(find.text('Une nouvelle, peut-être deux'), findsOneWidget);
    expect(find.text('Première fois'), findsOneWidget);
    expect(find.text('Pic épeiche'), findsOneWidget);
    expect(
      find.text('Entendu pour la première fois, à 7 h 26.'),
      findsOneWidget,
    );
    expect(find.text('Inattendu ici'), findsOneWidget);

    await scrollTo(tester, find.text('Vérifier 3 détections'));
    expect(find.text('Les 13 espèces entendues'), findsOneWidget);
    expect(find.text('×9'), findsOneWidget);
    // Chouette, Martin-pêcheur, Huppe. Only the visible part of the strip
    // is on screen, so look past the viewport.
    expect(find.byKey(_dot, skipOffstage: false), findsNWidgets(3));

    await scrollTo(tester, find.text('Envoyer à Faune-France (LPO)'));
    await scrollTo(tester, find.text("Détail de l'écoute"));

    // The game blocks come with J6e.
    expect(find.textContaining('Sentinelle'), findsNothing);
    expect(find.textContaining('Badge'), findsNothing);
  });

  testWidgets('« Vérifier » opens the quick review on those detections, '
      'then the Bilan reloads', (tester) async {
    final session = morningSession();
    final loader = await pump(tester, session: session);
    expect(loader.loads, 1);

    await scrollTo(tester, find.text('Vérifier 3 détections'));
    await tester.tap(find.text('Vérifier 3 détections'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final review = tester.widget<QuickReviewScreen>(
      find.byType(QuickReviewScreen),
    );
    String key(String name) => detectionKey(
      session.id,
      session.detections.firstWhere((d) => d.scientificName == name),
    );
    expect(review.keys, [key(owl), key(kingfisher), key(hoopoe)]);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(loader.loads, 2);
  });

  testWidgets('nothing new and nothing to check', (tester) async {
    await pump(
      tester,
      inputs: (session) {
        for (final d in session.detections) {
          if ({owl, kingfisher, hoopoe}.contains(d.scientificName)) {
            d.markConfirmed();
          }
        }
        return BilanInputs(
          session: session,
          presence: morningPresence(),
          heardBefore: {woodpecker, hoopoe, ...heardBeforeMorning()},
        );
      },
    );
    await scrollTo(tester, find.text("Détail de l'écoute"));
    expect(find.textContaining('nouvelle'), findsNothing);
    expect(find.textContaining('Vérifier'), findsNothing);
    expect(find.byKey(_dot, skipOffstage: false), findsNothing);
    expect(find.text('Envoyer à Faune-France (LPO)'), findsOneWidget);
  });

  testWidgets('an empty outing invites to listen again', (tester) async {
    await pump(tester, session: morningSession()..detections.clear());
    expect(find.text("Pas d'oiseau cette fois"), findsOneWidget);
    expect(find.textContaining('lever du jour'), findsOneWidget);
    expect(find.text('espèces'), findsNothing);
    expect(find.byType(BilanSpeciesStrip), findsNothing);
    expect(find.text('Envoyer à Faune-France (LPO)'), findsNothing);
  });

  testWidgets('no position: no map button and no place', (tester) async {
    final session =
        morningSession()
          ..latitude = null
          ..longitude = null;
    await pump(tester, session: session, place: null);
    expect(find.byTooltip('Revoir sur la carte'), findsNothing);
    expect(find.text('Samedi 26 septembre · 7 h 12 – 7 h 54'), findsOneWidget);
  });

  for (final (name, dark, textScale, size) in [
    ('dark theme', true, 1.0, const Size(412, 915)),
    ('text at 130 %', false, 1.3, const Size(360, 740)),
    ('landscape at 130 %', true, 1.3, const Size(915, 412)),
    ('tablet', false, 1.0, const Size(1024, 1366)),
  ]) {
    testWidgets('lays out without overflow: $name', (tester) async {
      await pump(
        tester,
        dark: dark,
        textScale: textScale,
        reduceMotion: dark,
        size: size,
      );
      await scrollTo(tester, find.text("Détail de l'écoute"));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ListView)).width,
        lessThanOrEqualTo(600),
      );
    });
  }
}
