import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_block.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_listening_logo.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_sparkles.dart';
import 'package:birdnet_live/fork/live/live_moments.dart';
import 'package:birdnet_live/fork/live/live_moments_model.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 9, 27, 7, 30);

DetectionRecord _record(String name, double score) => DetectionRecord(
  scientificName: name,
  commonName: name,
  confidence: score,
  timestamp: _t0,
);

LiveTableEntry _entry(String name, double score, {DetectionRecord? record}) =>
    LiveTableEntry(
      scientificName: name,
      commonName: name,
      sessionCount: 1,
      total: 1,
      lastHeard: _t0,
      record: record ?? _record(name, score),
      singing: false,
    );

/// Hoopoe is rare here, the rest plausible.
GeoPresence? _presence(String name) =>
    GeoPresence(unexpected: name == 'Upupa epops');

class _FakeController implements LiveController {
  _FakeController(this.session);

  @override
  final LiveSession session;

  @override
  final ValueNotifier<String?> replayingClip = ValueNotifier(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LiveMomentTracker', () {
    LiveMoment? next(LiveMomentTracker t, List<LiveTableEntry> entries) =>
        t.next(entries, presenceOf: _presence, isBird: (_) => true);

    test('first Sûr contact of a never-verified bird, once', () {
      final tracker = LiveMomentTracker(verifiedBefore: {'Turdus merula'});
      final moment = next(tracker, [
        _entry('Turdus merula', 0.95),
        _entry('Dendrocopos major', 0.92),
      ]);
      expect(moment!.kind, LiveMomentKind.firstTime);
      expect(moment.entry.scientificName, 'Dendrocopos major');
      tracker.shown(moment);
      expect(moment.rank, 2);
      expect(next(tracker, [_entry('Dendrocopos major', 0.97)]), isNull);
    });

    test('Probable is not a first time (yet)', () {
      final tracker = LiveMomentTracker(verifiedBefore: {});
      expect(next(tracker, [_entry('Dendrocopos major', 0.6)]), isNull);
      expect(
        next(tracker, [_entry('Dendrocopos major', 0.9)])!.kind,
        LiveMomentKind.firstTime,
      );
    });

    test('a rare bird asks before any party', () {
      final tracker = LiveMomentTracker(verifiedBefore: {'Turdus merula'});
      final moment = next(tracker, [_entry('Upupa epops', 0.93)]);
      expect(moment!.kind, LiveMomentKind.rare);
      expect(moment.rank, 0);
      expect(tracker.verifiedCount, 1);
      tracker.confirmed(moment);
      expect(moment.rank, 2);
      expect(tracker.verifiedCount, 2);
      // A rare bird too faint for « Probable » stays a plain row.
      expect(
        next(LiveMomentTracker(verifiedBefore: {}), [
          _entry('Upupa epops', 0.3),
        ]),
        isNull,
      );
    });

    test('nextAll gives every new moment, ranks fixed in hearing order', () {
      final tracker = LiveMomentTracker(verifiedBefore: {'Turdus merula'});
      final all = tracker.nextAll(
        [
          _entry('Turdus merula', 0.95),
          _entry('Dendrocopos major', 0.92),
          _entry('Parus major', 0.9),
          _entry('Upupa epops', 0.93),
          _entry('Erithacus rubecula', 0.6),
        ],
        presenceOf: _presence,
        isBird: (_) => true,
      );
      expect(all.map((m) => m.entry.scientificName), [
        'Dendrocopos major',
        'Parus major',
        'Upupa epops',
      ]);
      expect(all.map((m) => m.kind), [
        LiveMomentKind.firstTime,
        LiveMomentKind.firstTime,
        LiveMomentKind.rare,
      ]);
      // Ranks are given when a card is shown, not when it is created.
      expect(all.map((m) => m.rank), [0, 0, 0]);
      expect(tracker.verifiedCount, 1);
      // Each species comes once.
      expect(
        tracker.nextAll(
          [_entry('Dendrocopos major', 0.99)],
          presenceOf: _presence,
          isBird: (_) => true,
        ),
        isEmpty,
      );
    });

    group('ranks follow the order species are added', () {
      List<LiveMoment> all(LiveMomentTracker t, List<LiveTableEntry> e) =>
          t.nextAll(e, presenceOf: _presence, isBird: (_) => true);
      final base = {'A1', 'A2', 'A3'};

      test('a series of 3 shown in turn: 4th, 5th, 6th', () {
        final t = LiveMomentTracker(verifiedBefore: base);
        final m = all(t, [
          _entry('B1', 0.95),
          _entry('B2', 0.95),
          _entry('B3', 0.95),
        ]);
        for (final x in m) {
          t.shown(x);
        }
        expect(m.map((x) => x.rank), [4, 5, 6]);
      });

      test('series of 3 then a confirmed rare: next rank', () {
        final t = LiveMomentTracker(verifiedBefore: base);
        final m = all(t, [
          _entry('B1', 0.95),
          _entry('B2', 0.95),
          _entry('B3', 0.95),
        ]);
        m.forEach(t.shown);
        final rare = all(t, [_entry('Upupa epops', 0.93)]).single;
        t.confirmed(rare);
        expect(rare.rank, 7);
        expect(t.verifiedCount, 7);
      });

      test('rare confirmed while firsts are queued: no duplicate rank', () {
        final t = LiveMomentTracker(verifiedBefore: base);
        final m = all(t, [
          _entry('B1', 0.95),
          _entry('B2', 0.95),
          _entry('Upupa epops', 0.93),
        ]);
        final firsts = m.where((x) => x.kind == LiveMomentKind.firstTime);
        final rare = m.singleWhere((x) => x.kind == LiveMomentKind.rare);
        // The first card is shown, the rare bird interrupts it.
        t.shown(firsts.first);
        t.released(firsts.first);
        t.confirmed(rare);
        for (final x in firsts) {
          t.shown(x);
        }
        final ranks = [rare.rank, ...firsts.map((x) => x.rank)];
        expect(ranks, [4, 5, 6]);
        expect(ranks.toSet().length, 3);
      });

      test('a declined rare bird consumes no rank', () {
        final t = LiveMomentTracker(verifiedBefore: base);
        final m = all(t, [_entry('Upupa epops', 0.93), _entry('B1', 0.95)]);
        final rare = m.singleWhere((x) => x.kind == LiveMomentKind.rare);
        final first = m.singleWhere((x) => x.kind == LiveMomentKind.firstTime);
        t.shown(rare);
        t.shown(first);
        expect(rare.rank, 0);
        expect(first.rank, 4);
        expect(t.verifiedCount, 4);
      });
    });

    test('non-birds and already verified species never trigger', () {
      final tracker = LiveMomentTracker(verifiedBefore: {'Turdus merula'});
      expect(
        tracker.next(
          [_entry('Turdus merula', 0.99), _entry('Canis lupus', 0.99)],
          presenceOf: _presence,
          isBird: (name) => name != 'Canis lupus',
        ),
        isNull,
      );
    });
  });

  group('LiveMoments', () {
    late LiveSession session;
    late _FakeController controller;

    late SharedPreferences prefs;

    Widget app(
      List<LiveTableEntry> entries, {
      Set<String> verified = const {},
      double textScale = 1,
      bool reduced = false,
      bool paused = false,
      ThemeData? theme,
    }) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        taxonomyServiceProvider.overrideWith((ref) async => TaxonomyService()),
      ],
      child: MaterialApp(
        theme: theme ?? BirdyTheme.dark(),
        locale: const Locale('fr'),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: reduced,
              ),
              child: child!,
            ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LiveMoments(
            entries: entries,
            controller: controller,
            presenceOf: _presence,
            presenceScoreOf: (_) => 0.02,
            clips: const {},
            verifiedBefore: () async => verified,
            paused: paused,
          ),
        ),
      ),
    );

    Future<void> pump(
      WidgetTester tester,
      List<LiveTableEntry> entries, {
      Set<String> verified = const {},
      Size size = const Size(400, 900),
      double textScale = 1,
      bool reduced = false,
      bool paused = false,
      ThemeData? theme,
    }) async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          entries,
          verified: verified,
          textScale: textScale,
          reduced: reduced,
          paused: paused,
          theme: theme,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    setUp(() {
      session = LiveSession(
        id: 's',
        startTime: _t0,
        settings: const SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 30,
          inferenceRate: 1.5,
          speciesFilterMode: 'geoMerge',
        ),
        detections: [
          _record('Upupa epops', 0.93),
          _record('Upupa epops', 0.7),
          _record('Turdus merula', 0.9),
        ],
      );
      controller = _FakeController(session);
    });

    testWidgets('first encounter card, closes by itself', (tester) async {
      await pump(tester, [_entry('Dendrocopos major', 0.95)]);
      expect(find.text('Première rencontre !'), findsOneWidget);
      expect(find.text('Ajouté à ton carnet · 1re espèce'), findsOneWidget);
      expect(find.text('Oisillon'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Première rencontre !'), findsNothing);
    });

    testWidgets('first encounter: two confetti salves from the bird, once', (
      tester,
    ) async {
      await pump(tester, [_entry('Dendrocopos major', 0.95)]);
      final salves = tester.widgetList<ConfettiWidget>(
        find.byType(ConfettiWidget),
      );
      expect(salves, hasLength(2));
      expect(salves.map((w) => w.numberOfParticles), [22, 14]);
      // The first leaves at once, the second a little later.
      expect(
        salves.first.confettiController.state,
        ConfettiControllerState.playing,
      );
      expect(salves.every((w) => !w.shouldLoop), isTrue);
      // From the bird's center.
      final bird = tester.getCenter(
        find.byKey(const ValueKey('first-time-bird')),
      );
      for (final salve in find.byType(ConfettiWidget).evaluate()) {
        expect(
          (tester.getTopLeft(find.byWidget(salve.widget)) - bird).distance,
          lessThan(1),
        );
      }
      // Four sparkles pop around it.
      expect(
        find.descendant(
          of: find.byType(BirdySparkles),
          matching: find.byType(Icon),
        ),
        findsNWidgets(4),
      );
      // One burst: gone long before the card closes by itself.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BirdySparkles),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      expect(find.text('Première rencontre !'), findsOneWidget);
    });

    testWidgets('first encounter, reduced motion: no confetti, all shown', (
      tester,
    ) async {
      await pump(tester, [_entry('Dendrocopos major', 0.95)], reduced: true);
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BirdySparkles),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      expect(find.text('Première rencontre !'), findsOneWidget);
      expect(find.text('Oisillon'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ConfettiWidget), findsNothing);
    });

    testWidgets('countdown, reduced motion: the bar steps with the text', (
      tester,
    ) async {
      await pump(tester, [_entry('Dendrocopos major', 0.95)], reduced: true);
      expect(find.text('Se referme seul dans 6 s'), findsOneWidget);
      expect(
        tester.widget<BirdyProgressBar>(find.byType(BirdyProgressBar)).value,
        1,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Se referme seul dans 5 s'), findsOneWidget);
      expect(
        tester.widget<BirdyProgressBar>(find.byType(BirdyProgressBar)).value,
        closeTo(5 / 6, 1e-9),
      );
      expect(find.text('Première rencontre !'), findsOneWidget);
    });

    for (final (label, size, dark) in [
      ('portrait 320 × 640, light', const Size(320, 640), false),
      ('landscape 800 × 360, dark', const Size(800, 360), true),
    ]) {
      testWidgets('first encounter at 130 % text, $label: no overflow', (
        tester,
      ) async {
        await pump(
          tester,
          [_entry('Dendrocopos major', 0.95)],
          size: size,
          textScale: 1.3,
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text("Continuer l'écoute"));
        await tester.pump(const Duration(milliseconds: 100));
        final button = tester.getRect(
          find.widgetWithText(FilledButton, "Continuer l'écoute"),
        );
        expect(button.height, greaterThanOrEqualTo(48));
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      });
    }

    final birds = [
      _entry('Dendrocopos major', 0.95),
      _entry('Parus major', 0.94),
      _entry('Erithacus rubecula', 0.93),
    ];
    final verified24 = {for (var i = 0; i < 24; i++) 'Species $i'};

    Future<void> tapPrimary(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.widgetWithText(FilledButton, label));
      await tester.tap(find.widgetWithText(FilledButton, label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets(
      'series of 3: ranks, « 1 sur 3 », then the last one continues',
      (tester) async {
        await pump(tester, birds, verified: verified24);
        expect(find.text('1 sur 3 nouvelles'), findsOneWidget);
        expect(find.text('Ajouté à ton carnet · 25e espèce'), findsOneWidget);
        expect(find.text('Espèce suivante'), findsOneWidget);
        expect(find.text("Continuer l'écoute"), findsNothing);
        expect(find.text('Suivante dans 6 s'), findsOneWidget);

        await tapPrimary(tester, 'Espèce suivante');
        expect(find.text('2 sur 3 nouvelles'), findsOneWidget);
        expect(find.text('Ajouté à ton carnet · 26e espèce'), findsOneWidget);

        await tapPrimary(tester, 'Espèce suivante');
        expect(find.text('3 sur 3 nouvelles'), findsOneWidget);
        expect(find.text('Ajouté à ton carnet · 27e espèce'), findsOneWidget);
        expect(find.text('Espèce suivante'), findsNothing);
        expect(find.text('Se referme seul dans 6 s'), findsOneWidget);

        await tapPrimary(tester, "Continuer l'écoute");
        expect(find.text('Première rencontre !'), findsNothing);
      },
    );

    testWidgets('the series moves on by itself after the countdown', (
      tester,
    ) async {
      await pump(tester, birds.take(2).toList(), verified: verified24);
      expect(find.text('1 sur 2 nouvelles'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('2 sur 2 nouvelles'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Première rencontre !'), findsNothing);
    });

    testWidgets('a bird heard while a card is open joins the series', (
      tester,
    ) async {
      await pump(tester, [birds[0]], verified: verified24);
      expect(find.textContaining('nouvelles'), findsNothing);
      expect(find.text("Continuer l'écoute"), findsOneWidget);
      await tester.pumpWidget(app([birds[0], birds[1]], verified: verified24));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1 sur 2 nouvelles'), findsOneWidget);
      expect(find.text('Espèce suivante'), findsOneWidget);
      await tapPrimary(tester, 'Espèce suivante');
      expect(find.text('2 sur 2 nouvelles'), findsOneWidget);
      expect(find.text('Ajouté à ton carnet · 26e espèce'), findsOneWidget);
    });

    testWidgets('a rare bird jumps ahead, the series goes on after it', (
      tester,
    ) async {
      await pump(tester, birds.take(2).toList(), verified: verified24);
      expect(find.text('1 sur 2 nouvelles'), findsOneWidget);
      await tester.pumpWidget(
        app([
          ...birds.take(2),
          _entry('Upupa epops', 0.93),
        ], verified: verified24),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Première rencontre !'), findsNothing);
      expect(
        find.text('Écoute-le encore avant de fêter : c\'est bien lui ?'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text("Ce n'est pas lui"));
      await tester.tap(find.text("Ce n'est pas lui"));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 600));
      // The interrupted bird comes back first, still 1 of 2.
      expect(find.text('1 sur 2 nouvelles'), findsOneWidget);
      expect(find.text('Ajouté à ton carnet · 25e espèce'), findsOneWidget);
    });

    testWidgets('pause freezes the countdown and says so, resume goes on', (
      tester,
    ) async {
      await pump(tester, [birds[0]], verified: verified24);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Se referme seul dans 4 s'), findsOneWidget);
      expect(find.textContaining('en pause'), findsNothing);
      await tester.pumpWidget(
        app([birds[0]], verified: verified24, paused: true),
      );
      await tester.pump();
      expect(find.text('Se referme seul dans 4 s · en pause'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Se referme seul dans 4 s · en pause'), findsOneWidget);
      expect(find.text('Première rencontre !'), findsOneWidget);
      // The card's logo holds still while paused.
      final logo = tester.widget<BirdyListeningLogo>(
        find.byType(BirdyListeningLogo),
      );
      expect(logo.frozen, isTrue);
      expect(logo.running, isFalse);

      await tester.pumpWidget(app([birds[0]], verified: verified24));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Se referme seul dans 2 s'), findsOneWidget);
      expect(
        tester
            .widget<BirdyListeningLogo>(find.byType(BirdyListeningLogo))
            .running,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Première rencontre !'), findsNothing);
    });

    testWidgets('back from the background: the series shows at once', (
      tester,
    ) async {
      await pump(tester, const [], verified: verified24);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpWidget(app(birds, verified: verified24));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Nothing pops up over a screen nobody looks at.
      expect(find.text('Première rencontre !'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('1 sur 3 nouvelles'), findsOneWidget);
      expect(find.text('Ajouté à ton carnet · 25e espèce'), findsOneWidget);
    });

    testWidgets('rare bird: « C\'est bien lui » confirms, then the party', (
      tester,
    ) async {
      await pump(tester, [_entry('Upupa epops', 0.93)], verified: {'A b'});
      expect(
        find.text('Écoute-le encore avant de fêter : c\'est bien lui ?'),
        findsOneWidget,
      );
      expect(
        find.text('Présence estimée ici cette semaine : 2 sur 100.'),
        findsOneWidget,
      );
      expect(find.text('Oiseau rare confirmé !'), findsNothing);
      await tester.tap(find.text("C'est bien lui"));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Oiseau rare confirmé !'), findsOneWidget);
      expect(find.text('+1 espèce rare'), findsOneWidget);
      expect(
        session.detections
            .where((d) => d.scientificName == 'Upupa epops')
            .every((d) => d.reviewStatus == ReviewStatus.confirmed),
        isTrue,
      );
      expect(session.detections.last.reviewStatus, ReviewStatus.unreviewed);
    });

    testWidgets('rare bird: « Ce n\'est pas lui » rejects it, quietly', (
      tester,
    ) async {
      await pump(tester, [_entry('Upupa epops', 0.93)]);
      await tester.ensureVisible(find.text("Ce n'est pas lui"));
      await tester.tap(find.text("Ce n'est pas lui"));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text("C'est noté. Il ne comptera pas, merci."),
        findsOneWidget,
      );
      expect(
        session.detections
            .where((d) => d.scientificName == 'Upupa epops')
            .every((d) => d.reviewStatus == ReviewStatus.rejected),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(find.text("C'est noté. Il ne comptera pas, merci."), findsNothing);
    });

    testWidgets('nothing new: no card, taps go through', (tester) async {
      await pump(
        tester,
        [_entry('Turdus merula', 0.95)],
        verified: {'Turdus merula'},
      );
      expect(
        find.descendant(
          of: find.byType(LiveMoments),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });
  });
}
