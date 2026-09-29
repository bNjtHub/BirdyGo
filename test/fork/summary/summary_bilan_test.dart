import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/summary/listening_summary.dart';
import 'package:birdnet_live/fork/summary/listening_summary_view.dart';
import 'package:birdnet_live/fork/summary/summary_actions_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'summary_fixture.dart';

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  theme: BirdyTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder:
      (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
  home: home,
);

void main() {
  group('actions sheet', () {
    final calls = <String>[];
    setUp(calls.clear);

    Future<void> open(WidgetTester tester, {bool isRecording = false}) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () => showSummaryActionsSheet(
                          context,
                          isRecording: isRecording,
                          onSend: () => calls.add('send'),
                          onAddObservation: () => calls.add('add'),
                          onDetails: () => calls.add('details'),
                          onMarkRecording: (r) => calls.add('mark:$r'),
                        ),
                    child: const Text('open'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('has the four rows of the mockup', (tester) async {
      await open(tester);
      expect(find.text('Autres actions'), findsOneWidget);
      for (final title in [
        'Envoyer à Faune-France',
        'Ajouter un oiseau observé',
        "Détail de l'écoute",
        "C'était un enregistrement",
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(
        find.text('Fiche prête pour chaque observation confirmée'),
        findsOneWidget,
      );
      expect(find.text('Vu mais pas entendu'), findsOneWidget);
      expect(find.text('Chaque détection, minute par minute'), findsOneWidget);
      expect(find.text('Ne compte pas dans tes statistiques'), findsOneWidget);
    });

    for (final (title, expected) in [
      ('Envoyer à Faune-France', 'send'),
      ('Ajouter un oiseau observé', 'add'),
      ("Détail de l'écoute", 'details'),
      ("C'était un enregistrement", 'mark:true'),
    ]) {
      testWidgets('« $title » closes the sheet and runs its action', (
        tester,
      ) async {
        await open(tester);
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(calls, [expected]);
        expect(find.text('Autres actions'), findsNothing);
      });
    }

    testWidgets('a recording offers to undo the mark', (tester) async {
      await open(tester, isRecording: true);
      await tester.tap(find.text("Non, c'étaient de vrais oiseaux"));
      await tester.pumpAndSettle();
      expect(calls, ['mark:false']);
    });

    testWidgets('a null callback hides its row', (tester) async {
      await tester.pumpWidget(
        _app(const Scaffold(body: SummaryActionsSheet(onDetails: null))),
      );
      expect(find.text("Détail de l'écoute"), findsNothing);
      expect(
        hasSummaryActions(onDetails: null, onMarkRecording: null),
        isFalse,
      );
    });
  });

  group('hero and actions', () {
    Future<void> pump(
      WidgetTester tester,
      ListeningSummary summary, {
      Size size = const Size(320, 640),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ListeningSummaryView(
            summary: summary,
            nameOf: (s) => s.commonName,
            onDone: () {},
            onCheck: (_) {},
            onDetails: () {},
            onAddObservation: () {},
            onMarkRecording: (_) {},
            onSendToFauneFrance: () {},
          ),
          textScale: textScale,
        ),
      );
      await tester.pumpAndSettle();
    }

    ListeningSummary long(Duration duration) {
      final json = morningSession().toJson();
      final start = DateTime.parse(json['startTime'] as String);
      json['endTime'] = start.add(duration).toIso8601String();
      return ListeningSummary.of(
        LiveSession.fromJson(json),
        verifiedBefore: verifiedBeforeMorning,
        presence: morningPresence,
      );
    }

    for (final duration in [
      const Duration(minutes: 36),
      const Duration(hours: 12, minutes: 34),
    ]) {
      testWidgets(
        'hero fits at 320 dp, 130 % text, ${duration.inMinutes} min',
        (tester) async {
          await pump(tester, long(duration), textScale: 1.3);
          expect(tester.takeException(), isNull);
          expect(find.text('Belle matinée !'), findsOneWidget);
          expect(find.text('durée'), findsOneWidget);
        },
      );
    }

    testWidgets('one primary button, then « Autres actions »', (tester) async {
      await pump(tester, long(const Duration(minutes: 36)));
      await tester.scrollUntilVisible(
        find.text('Autres actions'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Vérifier 3 détections'), findsOneWidget);
      final more = find.ancestor(
        of: find.text('Autres actions'),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.getSize(more).height, greaterThanOrEqualTo(56));
    });
  });
}
