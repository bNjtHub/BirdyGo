import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/reliability/quick_review_widgets.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/reliability/review_writer.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

IndexedDetection _detection(String key, String name, double score) =>
    IndexedDetection(
      key: key,
      sessionId: 's',
      position: 0,
      scientificName: name,
      commonName: name,
      start: DateTime.now().subtract(const Duration(hours: 1)),
      end: null,
      confidence: score,
      reviewStatus: ReviewStatus.unreviewed,
      latitude: null,
      longitude: null,
      clipPath: null,
    );

class _FakeIndex implements ObservationIndex {
  _FakeIndex(this.queue);

  final List<IndexedDetection> queue;
  Set<String>? askedKeys;

  @override
  Future<List<IndexedDetection>> reviewQueue({
    int limit = 50,
    Set<String>? onlyKeys,
  }) async {
    askedKeys = onlyKeys;
    return [
      for (final d in queue)
        if (onlyKeys == null || onlyKeys.contains(d.key)) d,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _IndexService extends ObservationIndexService {
  _IndexService(SharedPreferences prefs, this.index)
    : super(repository: SessionRepository(), prefs: prefs);

  final _FakeIndex index;

  @override
  Future<ObservationIndex> ensureReady() async => index;
}

class _Writer implements ReviewWriter {
  final answers = <(String, Object)>[];

  @override
  Future<bool> setStatus(IndexedDetection d, ReviewStatus status) async {
    answers.add((d.key, status));
    return true;
  }

  @override
  Future<void> skip(IndexedDetection d) async => answers.add((d.key, 'skip'));
}

class _Geo implements GeoPresenceService {
  _Geo(this.presence);

  final GeoPresence? presence;

  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async => presence;
}

void main() {
  late SharedPreferences prefs;
  late _Writer writer;
  late _FakeIndex index;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    writer = _Writer();
    index = _FakeIndex([
      _detection('a', 'Upupa epops', 0.9),
      _detection('b', 'Erithacus rubecula', 0.4),
    ]);
  });

  Future<void> pump(
    WidgetTester tester, {
    Set<String>? onlyKeys,
    GeoPresence? presence,
    bool dark = false,
    double textScale = 1,
    bool reduceMotion = false,
    Size size = const Size(390, 844),
    String locale = 'fr',
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith(
            (ref) => _IndexService(prefs, index),
          ),
          reviewWriterProvider.overrideWithValue(writer),
          geoPresenceServiceProvider.overrideWithValue(_Geo(presence)),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reduceMotion,
                ),
                child: child!,
              ),
          home: QuickReviewScreen(onlyKeys: onlyKeys),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the first card, the hints and the three verdicts', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Revue rapide'), findsOneWidget);
    expect(find.text('1 sur 2'), findsOneWidget);
    expect(find.text("Rien de trié pour l'instant."), findsOneWidget);
    expect(find.text('Upupa epops'), findsWidgets);
    expect(find.text('Score 0,90'), findsOneWidget);
    expect(find.text("Pas d'enregistrement pour cette détection."), findsOne);
    // Hints and buttons both name the answers.
    expect(find.text("C'est bien lui"), findsNWidgets(2));
    expect(find.text("Ce n'est pas lui"), findsNWidgets(2));
    expect(find.text('Je ne sais pas'), findsNWidgets(2));
    expect(find.textContaining('est une bonne réponse'), findsOneWidget);
  });

  testWidgets('the card stack is centered between progress and verdicts', (
    tester,
  ) async {
    await pump(tester);
    final progress = tester.getRect(find.byType(ReviewProgress));
    final stack = tester.getRect(find.byType(ReviewCardStack));
    final hints = tester.getRect(find.byType(SwipeHints));
    final above = stack.top - progress.bottom;
    final below = hints.top - BirdySpace.s - stack.bottom;
    expect(above, greaterThan(0));
    expect((above - below).abs(), lessThan(2));
  });

  testWidgets('short screen at 130 % text: no overflow, verdicts reachable', (
    tester,
  ) async {
    await pump(tester, size: const Size(360, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Je ne sais pas'), findsWidgets);
  });

  testWidgets('buttons record the answers and move on', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(InkWell, "C'est bien lui"));
    await tester.pumpAndSettle();
    expect(writer.answers, [('a', ReviewStatus.confirmed)]);
    expect(find.text('2 sur 2'), findsOneWidget);
    expect(find.textContaining('Tu as trié 1 détection.'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Je ne sais pas'));
    await tester.pumpAndSettle();
    expect(writer.answers.last, ('b', 'skip'));
    expect(find.text('Tout est trié, bravo'), findsOneWidget);
    expect(
      find.text(
        "Tu as trié 2 détections. Tes réponses rendent l'app plus fiable.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('swipes: right confirms, left rejects, a short drag springs '
      'back', (tester) async {
    index = _FakeIndex([
      _detection('a', 'Upupa epops', 0.9),
      _detection('b', 'Erithacus rubecula', 0.4),
      _detection('c', 'Turdus merula', 0.7),
    ]);
    await pump(tester);
    final card = find.text('Score 0,90');

    await tester.drag(card, const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(writer.answers, isEmpty);
    expect(find.text('1 sur 3'), findsOneWidget);

    await tester.drag(card, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(writer.answers, [('a', ReviewStatus.confirmed)]);

    await tester.drag(find.text('Score 0,40'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(writer.answers.last, ('b', ReviewStatus.rejected));

    await tester.drag(find.text('Score 0,70'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(writer.answers.last, ('c', 'skip'));
  });

  testWidgets('a short drag goes back to the center', (tester) async {
    await pump(tester);
    final card = find.text('Score 0,90');
    final before = tester.getCenter(card);
    await tester.drag(card, const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getCenter(card).dx, greaterThan(before.dx));
    await tester.pumpAndSettle();
    expect(tester.getCenter(card).dx, closeTo(before.dx, 0.5));
    expect(writer.answers, isEmpty);
  });

  testWidgets('only the keys of the listening summary', (tester) async {
    await pump(tester, onlyKeys: {'b'});
    expect(index.askedKeys, {'b'});
    expect(find.text('1 sur 1'), findsOneWidget);
    expect(find.text('Score 0,40'), findsOneWidget);
  });

  testWidgets('good score but unexpected here: « Rare ici · à confirmer »', (
    tester,
  ) async {
    await pump(tester, presence: const GeoPresence(unexpected: true));
    expect(find.text('Rare ici · à confirmer'), findsOneWidget);
  });

  testWidgets('empty queue', (tester) async {
    index = _FakeIndex([]);
    await pump(tester);
    expect(find.text('Rien à vérifier'), findsOneWidget);
    expect(find.text('Toutes les détections sont triées.'), findsOneWidget);
    expect(find.text("C'est bien lui"), findsNothing);
  });

  testWidgets('reduced motion: the answer still goes through', (tester) async {
    await pump(tester, reduceMotion: true);
    await tester.tap(find.widgetWithText(InkWell, "Ce n'est pas lui"));
    await tester.pumpAndSettle();
    expect(writer.answers, [('a', ReviewStatus.rejected)]);
  });

  testWidgets('English strings', (tester) async {
    await pump(tester, locale: 'en');
    expect(find.text('Nothing sorted yet.'), findsOneWidget);
    expect(find.textContaining('good answer'), findsOneWidget);
  });

  for (final (label, dark, scale, size) in [
    ('light', false, 1.0, const Size(390, 844)),
    ('dark at 130 %', true, 1.3, const Size(390, 844)),
    ('small phone at 130 %', false, 1.3, const Size(320, 640)),
  ]) {
    testWidgets('lays out without overflow: $label', (tester) async {
      await pump(tester, dark: dark, textScale: scale, size: size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'BirdyOverlayHeader shows the back button and the title at 130 % text',
    (tester) async {
      await pump(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.text('Revue rapide'), findsOneWidget);
      expect(find.byTooltip('Fermer'), findsOneWidget);
    },
  );
}
