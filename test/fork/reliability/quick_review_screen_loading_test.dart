/// Loading skeleton of the quick review (J6f skeletons): the queue's
/// length and the first card wait on `_load()` (the index plus its
/// review queue), which resolves after the first frame; the top bar and
/// the card's own rect must not move once it lands.
library;

import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/fork/reliability/review_writer.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/fonts.dart';

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

  @override
  Future<List<IndexedDetection>> reviewQueue({
    int limit = 50,
    Set<String>? onlyKeys,
  }) async => queue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `ensureReady()` resolves only once told to: the screen's `_load()`
/// awaits it before the queue and its first card can settle.
class _DelayedIndexService extends ObservationIndexService {
  _DelayedIndexService(SharedPreferences prefs, this._index)
    : super(repository: SessionRepository(), prefs: prefs);

  final _FakeIndex _index;
  final _gate = Completer<void>();

  void resolve() => _gate.complete();

  @override
  Future<ObservationIndex> ensureReady() async {
    await _gate.future;
    return _index;
  }
}

class _Writer implements ReviewWriter {
  @override
  Future<bool> setStatus(IndexedDetection d, ReviewStatus status) async => true;

  @override
  Future<void> skip(IndexedDetection d) async {}
}

class _Geo implements GeoPresenceService {
  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async => null;
}

void main() {
  setUpAll(loadAppFonts);

  late SharedPreferences prefs;
  late _DelayedIndexService service;

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final index = _FakeIndex([
      _detection('a', 'Upupa epops', 0.9),
      _detection('b', 'Erithacus rubecula', 0.4),
    ]);
    service = _DelayedIndexService(prefs, index);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          observationIndexServiceProvider.overrideWith((ref) => service),
          reviewWriterProvider.overrideWithValue(_Writer()),
          geoPresenceServiceProvider.overrideWithValue(_Geo()),
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
          home: const QuickReviewScreen(),
        ),
      ),
    );
  }

  testWidgets('light, 100 %: the top bar keeps its height as the queue lands', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    final bar = tester.getRect(find.text('Revue rapide'));
    service.resolve();
    await tester.pumpAndSettle();
    final loaded = tester.getRect(find.text('Revue rapide'));
    // Top, left and line count (height) never move; the real progress text
    // ("1 sur 2") is not exactly as wide as the skeleton's placeholder
    // digits, so the title's own measured width can settle by a few
    // pixels without the row itself resizing.
    expect(loaded.topLeft, bar.topLeft, reason: 'title top-left');
    expect(loaded.height, bar.height, reason: 'title stays on one line');
    expect((loaded.width - bar.width).abs(), lessThan(8));
    expect(find.text('1 sur 2'), findsOneWidget);
  });

  testWidgets('dark, 130 %: the top bar keeps its height as the queue lands', (
    tester,
  ) async {
    await pump(tester, dark: true, textScale: 1.3);
    await tester.pump();
    final bar = tester.getRect(find.text('Revue rapide'));
    service.resolve();
    await tester.pumpAndSettle();
    final loaded = tester.getRect(find.text('Revue rapide'));
    expect(loaded.topLeft, bar.topLeft, reason: 'title top-left');
    expect(loaded.height, bar.height, reason: 'title keeps its line count');
    expect((loaded.width - bar.width).abs(), lessThan(8));
    expect(find.text('1 sur 2'), findsOneWidget);
  });

  testWidgets('reduced motion: nothing animates while loading', (tester) async {
    await pump(tester, reducedMotion: true);
    await tester.pump();
    final before = tester.getRect(
      find.byKey(const ValueKey('quick-review-loading')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey('quick-review-loading'))),
        before,
      );
    }
    service.resolve();
    await tester.pumpAndSettle();
    expect(find.text('Upupa epops'), findsWidgets);
  });

  testWidgets(
    'the first card is a static placeholder, excluded from semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('quick-review-loading')),
        findsOneWidget,
      );
      final data = tester.getSemantics(find.byType(QuickReviewScreen));
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
      service.resolve();
      await tester.pumpAndSettle();
      handle.dispose();
    },
  );
}
