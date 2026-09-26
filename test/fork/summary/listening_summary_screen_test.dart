import 'package:birdnet_live/features/announcements/geo_commonness_provider.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/summary/listening_summary.dart';
import 'package:birdnet_live/fork/summary/listening_summary_loader.dart';
import 'package:birdnet_live/fork/summary/listening_summary_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'summary_fixture.dart';

void main() {
  // The index part of the loading is tested in listening_summary_test.dart
  // (sqflite runs on real async, which widget tests do not drive).
  Future<void> pump(
    WidgetTester tester,
    Future<ListeningSummary> Function(LiveSession session) loader,
  ) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          listeningSummaryLoaderProvider.overrideWithValue(loader),
          geoCommonnessProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith((ref) async => null),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    // As after « Arrêter »: library, then the summary.
                    onPressed:
                        () =>
                            Navigator.of(context)
                              ..push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => const Scaffold(
                                        body: Text('Bibliothèque'),
                                      ),
                                ),
                              )
                              ..push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => ListeningSummaryScreen(
                                        session: morningSession(),
                                      ),
                                ),
                              ),
                    child: const Text('Accueil'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the loaded summary; « Terminer » goes home', (
    tester,
  ) async {
    await pump(
      tester,
      (session) async => ListeningSummary.of(
        session,
        verifiedBefore: verifiedBeforeMorning,
        presence: morningPresence,
      ),
    );

    expect(find.text('Belle matinée !'), findsOneWidget);
    expect(find.text('Ta 24e espèce, à 07:26.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Envoyer à Faune-France (LPO)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Seuls les oiseaux que tu confirmes partent à la LPO.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Bibliothèque'), findsNothing);
  });

  testWidgets('back also goes home', (tester) async {
    await pump(
      tester,
      (session) async => ListeningSummary.of(session, verifiedBefore: {}),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('without the index, the summary shows no novelty', (
    tester,
  ) async {
    await pump(tester, (session) async => throw StateError('no index'));

    expect(find.text('Belle matinée !'), findsOneWidget);
    expect(find.text('Première fois'), findsNothing);
    expect(find.text('Une nouvelle, peut-être deux'), findsNothing);
  });
}
