import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/summary/listening_summary.dart';
import 'package:birdnet_live/fork/summary/listening_summary_view.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'summary_fixture.dart';

/// The page's vertical list (the species strip scrolls too).
final Finder _page = find.byType(Scrollable).first;

/// Brings [finder] into the page's view, then taps it.
Future<void> _tapInPage(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _page);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

ListeningSummary _morning() => ListeningSummary.of(
  morningSession(),
  verifiedBefore: verifiedBeforeMorning,
  presence: morningPresence,
);

void main() {
  Set<String>? checked;
  var details = 0;
  var shared = 0;

  setUp(() {
    checked = null;
    details = 0;
    shared = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    ListeningSummary summary, {
    bool dark = false,
    double textScale = 1,
    bool reduceMotion = false,
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
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
        home: ListeningSummaryView(
          summary: summary,
          place: 'Beaulieu-sur-Brenne',
          nameOf: (s) => s.commonName,
          onDone: () {},
          onMap: () {},
          onShare: () => shared++,
          onCheck: (keys) => checked = keys,
          onDetails: () => details++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the morning of the mockup', (tester) async {
    await pump(tester, _morning());

    expect(find.text("Bilan de l'écoute"), findsOneWidget);
    expect(find.text('Belle matinée !'), findsOneWidget);
    expect(
      find.text('Samedi 26 septembre · 07:12 – 07:54 · Beaulieu-sur-Brenne'),
      findsOneWidget,
    );
    expect(find.text('13'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
    expect(find.text('42 min'), findsOneWidget);
    expect(find.text('Une nouvelle, peut-être deux'), findsOneWidget);
    expect(find.text('Première fois'), findsOneWidget);
    expect(find.text('Pic épeiche'), findsOneWidget);
    expect(find.text('Ta 24e espèce, à 07:26.'), findsOneWidget);
    expect(find.text('Huppe fasciée'), findsOneWidget);
    expect(find.text('Inattendu ici'), findsOneWidget);
    expect(find.text('Les 13 espèces entendues'), findsOneWidget);
    expect(find.text('×9'), findsOneWidget);
  });

  testWidgets('« Vérifier 3 détections » opens the three to check', (
    tester,
  ) async {
    final summary = _morning();
    await pump(tester, summary);

    await _tapInPage(tester, find.text('Vérifier 3 détections'));
    expect(checked, summary.keysToCheck);

    await _tapInPage(tester, find.text("Voir le détail de l'écoute"));
    expect(details, 1);
  });

  testWidgets('the Huppe row opens its own check', (tester) async {
    final summary = _morning();
    await pump(tester, summary);

    await tester.tap(find.text('Huppe fasciée'));
    expect(checked, summary.maybeFirsts.single.keysToCheck);
    expect(checked, hasLength(1));
  });

  testWidgets('nothing to check: the details become the main action', (
    tester,
  ) async {
    final session = morningSession();
    for (final d in session.detections) {
      d.markConfirmed();
    }
    await pump(
      tester,
      ListeningSummary.of(session, verifiedBefore: verifiedBeforeMorning),
    );

    expect(find.textContaining('Vérifier'), findsNothing);
    expect(find.text('2 nouvelles espèces'), findsOneWidget);
    await _tapInPage(tester, find.text("Voir le détail de l'écoute"));
    expect(details, 1);
  });

  testWidgets('a quiet listening invites to try again', (tester) async {
    await pump(
      tester,
      ListeningSummary.of(
        LiveSession.fromJson({
          'id': 'quiet',
          'startTime': DateTime(2026, 9, 26, 20).toUtc().toIso8601String(),
          'endTime': DateTime(2026, 9, 26, 20, 10).toUtc().toIso8601String(),
        }),
        verifiedBefore: const {},
      ),
    );

    expect(find.text('Écoute calme'), findsOneWidget);
    expect(find.textContaining('Retente au lever du jour'), findsOneWidget);
    expect(find.byTooltip('Partager'), findsNothing);
    expect(find.text('Première fois'), findsNothing);
  });

  testWidgets('share and map buttons have labels', (tester) async {
    await pump(tester, _morning());

    expect(find.byTooltip('Terminer'), findsOneWidget);
    expect(find.byTooltip('Revoir sur la carte'), findsOneWidget);
    await tester.tap(find.byTooltip('Partager'));
    expect(shared, 1);
  });

  for (final dark in [false, true]) {
    testWidgets('text at 130 % fits (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pump(tester, _morning(), dark: dark, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Vérifier 3 détections'),
        200,
        scrollable: _page,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('landscape keeps a readable column', (tester) async {
    await pump(tester, _morning(), size: const Size(800, 360));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ListView)).width, 560);
  });

  testWidgets('reduced motion shows everything at once', (tester) async {
    await pump(tester, _morning(), reduceMotion: true);
    expect(find.text('Belle matinée !'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
