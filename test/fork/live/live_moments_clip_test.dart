import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/live/live_moments.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/replay/replay_button.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 9, 27, 7, 30);

class _FakeController implements LiveController {
  _FakeController(this.session);

  @override
  final LiveSession session;

  @override
  final ValueNotifier<String?> replayingClip = ValueNotifier(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LiveTableEntry _entry(String name, double score, {bool singing = false}) {
  final record = DetectionRecord(
    scientificName: name,
    commonName: name,
    confidence: score,
    timestamp: _t0,
  );
  return LiveTableEntry(
    scientificName: name,
    commonName: name,
    sessionCount: 1,
    total: 1,
    lastHeard: _t0,
    record: record,
    singing: singing,
  );
}

/// Hoopoe is rare here, the rest plausible.
GeoPresence? _presence(String name) =>
    GeoPresence(unexpected: name == 'Upupa epops');

void main() {
  late SharedPreferences prefs;
  late _FakeController controller;

  Widget app(
    String name, {
    required bool pending,
    Map<String, String> clips = const {},
    bool reduced = false,
    bool singing = false,
    bool paused = true,
  }) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      taxonomyServiceProvider.overrideWith((ref) async => TaxonomyService()),
    ],
    child: MaterialApp(
      theme: BirdyTheme.dark(),
      locale: const Locale('fr'),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LiveMoments(
          entries: [_entry(name, 0.95, singing: singing)],
          controller: controller,
          presenceOf: _presence,
          presenceScoreOf: (_) => 0.02,
          clips: clips,
          clipsPending: pending,
          paused: paused,
          verifiedBefore: () async => const {},
        ),
      ),
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    controller = _FakeController(
      LiveSession(
        id: 's',
        startTime: _t0,
        settings: const SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 30,
          inferenceRate: 1.5,
          speciesFilterMode: 'geoMerge',
        ),
        detections: const [],
      ),
    );
  });

  Future<void> open(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  final pendingSlot = find.byKey(const ValueKey('clip-slot-pending'));
  final readySlot = find.byKey(const ValueKey('clip-slot-ready'));

  for (final reduced in [false, true]) {
    for (final (kind, name) in [
      ('first encounter', 'Dendrocopos major'),
      ('rare bird', 'Upupa epops'),
    ]) {
      testWidgets(
        '$kind: the play button is there at once and does not move '
        '(reduced motion: $reduced)',
        (tester) async {
          await open(tester, app(name, pending: true, reduced: reduced));
          // Present from the first frame, disabled, no live button yet.
          expect(pendingSlot, findsOneWidget);
          expect(readySlot, findsNothing);
          expect(find.byType(ReplayButton), findsNothing);
          final before = tester.getRect(pendingSlot);
          final anchor =
              kind == 'rare bird'
                  ? find.text("C'est bien lui ?")
                  : find.byType(FilledButton).first;
          final anchorBefore = tester.getRect(anchor);

          await tester.pumpWidget(
            app(
              name,
              pending: true,
              reduced: reduced,
              clips: {name: '/tmp/clip.wav'},
            ),
          );
          // Mid-fade, then done.
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(ReplayButton), findsOneWidget);
          expect(readySlot, findsOneWidget);
          expect(pendingSlot, findsNothing);
          expect(tester.getRect(readySlot), before);
          expect(
            tester.getRect(anchor),
            anchorBefore,
          );
        },
      );
    }
  }

  testWidgets('the wait is bounded: the slot leaves once the clip is not coming', (
    tester,
  ) async {
    await open(tester, app('Dendrocopos major', pending: true));
    // The spinner state, not tappable, with the right label.
    expect(pendingSlot, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(ReliabilityConfig.clipWaitGrace);
    await tester.pump(const Duration(milliseconds: 600));
    expect(pendingSlot, findsNothing);
    expect(find.byType(ReplayButton), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('while the species sings the wait goes on', (tester) async {
    await open(tester, app('Dendrocopos major', pending: true, singing: true));
    await tester.pump(ReliabilityConfig.clipWaitGrace * 2);
    await tester.pump(const Duration(milliseconds: 600));
    expect(pendingSlot, findsOneWidget);
    // It stops singing: the grace starts, then the slot goes.
    await tester.pumpWidget(app('Dendrocopos major', pending: true));
    await tester.pump(ReliabilityConfig.clipWaitGrace);
    await tester.pump(const Duration(milliseconds: 600));
    expect(pendingSlot, findsNothing);
  });

  testWidgets('reduced motion: the slot leaves at once', (tester) async {
    await open(tester, app('Dendrocopos major', pending: true, reduced: true));
    await tester.pump(ReliabilityConfig.clipWaitGrace);
    await tester.pump();
    expect(pendingSlot, findsNothing);
  });

  testWidgets('no clip recording: no slot at all', (tester) async {
    await open(tester, app('Dendrocopos major', pending: false));
    expect(pendingSlot, findsNothing);
    expect(find.byType(ReplayButton), findsNothing);
  });
}
