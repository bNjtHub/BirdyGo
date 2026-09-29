import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
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
      expect(moment.rank, 2);
      expect(tracker.verifiedCount, 1);
      tracker.confirmed();
      expect(tracker.verifiedCount, 2);
      // A rare bird too faint for « Probable » stays a plain row.
      expect(
        next(LiveMomentTracker(verifiedBefore: {}), [
          _entry('Upupa epops', 0.3),
        ]),
        isNull,
      );
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

    Future<void> pump(
      WidgetTester tester,
      List<LiveTableEntry> entries, {
      Set<String> verified = const {},
      Size size = const Size(400, 900),
      double textScale = 1,
      bool reduced = false,
      ThemeData? theme,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            taxonomyServiceProvider.overrideWith(
              (ref) async => TaxonomyService(),
            ),
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
              ),
            ),
          ),
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

    testWidgets('first encounter: the bird bursts into confetti, once', (
      tester,
    ) async {
      await pump(tester, [_entry('Dendrocopos major', 0.95)]);
      final particles = tester.widget<ConfettiWidget>(
        find.byType(ConfettiWidget),
      );
      expect(
        particles.confettiController.state,
        ConfettiControllerState.playing,
      );
      expect(particles.shouldLoop, isFalse);
      // From the bird's center.
      final bird = tester.getCenter(
        find.byKey(const ValueKey('first-time-bird')),
      );
      expect(
        (tester.getTopLeft(find.byType(ConfettiWidget)) - bird).distance,
        lessThan(1),
      );
      // One burst: gone long before the card closes by itself.
      await tester.pump(BirdyConfettiMotion.burstLife);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(find.text('Première rencontre !'), findsOneWidget);
    });

    testWidgets('first encounter, reduced motion: no confetti, all shown', (
      tester,
    ) async {
      await pump(tester, [_entry('Dendrocopos major', 0.95)], reduced: true);
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(find.text('Première rencontre !'), findsOneWidget);
      expect(find.text('Oisillon'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ConfettiWidget), findsNothing);
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
