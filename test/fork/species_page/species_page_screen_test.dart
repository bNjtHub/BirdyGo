import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/explore/widgets/species_info_overlay.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/lpo/lpo_send_screen.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/clip_play_button.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/fork/ranking/activity_bars.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/species_page/species_clip_player.dart';
import 'package:birdnet_live/fork/species_page/species_page_loader.dart';
import 'package:birdnet_live/fork/species_page/species_page_model.dart';
import 'package:birdnet_live/fork/species_page/species_page_screen.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/species_description_service.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../summary/summary_fixture.dart';

const _robin = 'Erithacus rubecula';

class _FakeLoader implements SpeciesPageLoader {
  _FakeLoader({required this.recordValue, this.year});

  final SpeciesRecord recordValue;
  final YearPresence? year;
  bool unexpected = false;
  String? lpoSession;
  final favoriteCalls = <(String, bool)>[];

  @override
  Future<SpeciesRecord> record(String scientificName) async => recordValue;

  @override
  Future<YearPresence?> presence(String scientificName) async => year;

  @override
  Future<bool> unexpectedNow(
    String scientificName, {
    required DateTime now,
  }) async => unexpected;

  @override
  Future<String?> lastConfirmedSession(String scientificName) async =>
      lpoSession;

  @override
  Future<void> setFavorite(String key, {required bool favorite}) async =>
      favoriteCalls.add((key, favorite));
}

/// Serves one session by id.
class _OneSessionRepository extends SessionRepository {
  _OneSessionRepository(this.session);

  final LiveSession session;

  @override
  Future<LiveSession?> load(String id) async =>
      id == session.id ? session : null;
}

class _FakePlayer implements SpeciesClipPlayer {
  final _playing = ValueNotifier<String?>(null);
  final played = <String>[];

  @override
  ValueListenable<String?> get playing => _playing;

  @override
  Future<void> play(String clipPath) async {
    played.add(clipPath);
    _playing.value = clipPath;
  }

  @override
  Future<void> stop() async => _playing.value = null;
}

/// Index that never opens and never notifies.
class _QuietIndex extends ObservationIndexService {
  _QuietIndex(SharedPreferences prefs)
    : super(repository: SessionRepository(), prefs: prefs);

  @override
  Future<ObservationIndex> ensureReady() =>
      Completer<ObservationIndex>().future;
}

class _FakeDescriptions extends SpeciesDescriptionService {
  @override
  Future<String?> getDescription(String scientificName, String locale) async =>
      'Description upstream.';
}

IndexedDetection _clip(String key, double score) => IndexedDetection(
  key: key,
  sessionId: 's',
  position: 0,
  scientificName: _robin,
  commonName: 'Rougegorge familier',
  start: DateTime.now().subtract(const Duration(hours: 1)),
  end: null,
  confidence: score,
  reviewStatus: ReviewStatus.unreviewed,
  latitude: 46.7,
  longitude: 1.2,
  clipPath: '/clips/$key.wav',
);

SpeciesRecord _heard() => SpeciesRecord(
  tally: SpeciesTally(
    scientificName: _robin,
    commonName: 'Rougegorge familier',
    contacts: 142,
    days: 38,
    first: DateTime(2026, 3, 1),
    last: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  confirmed: 37,
  reviewed: 38,
  verified: true,
  clips: [_clip('a', 0.97), _clip('b', 0.95)],
  clipCount: 9,
  favorites: const {'a'},
  hours: [for (var h = 0; h < 24; h++) h == 7 ? 10 : h % 3],
  spots: const [(latitude: 46.7, longitude: 1.2)],
);

final _sheet = SpeciesSheet.fromJson({
  'name': 'Rougegorge familier',
  'summary': 'Le petit oiseau à la gorge orange des jardins.',
  'size': '14 cm, à peu près comme un moineau.',
  'migration': 'La plupart restent toute l’année.',
  'anecdote': 'Il chante parfois la nuit.',
});

void main() {
  late SharedPreferences prefs;
  late _FakeLoader loader;
  late _FakePlayer player;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    loader = _FakeLoader(
      recordValue: _heard(),
      year: YearPresence.fromWeeks(List.filled(48, 0.5)),
    );
    player = _FakePlayer();
  });

  Future<void> pump(
    WidgetTester tester, {
    Widget? home,
    bool dark = false,
    double textScale = 1,
    Size size = const Size(390, 844),
    SpeciesSheets? sheets,
    LiveState liveState = LiveState.ready,
    SessionRepository? lpoRepository,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // No geo-model in these tests: the world map block stays hidden.
          worldMapPredictProvider.overrideWith((ref) async => null),
          worldRangesProvider.overrideWith((ref) async => null),
          taxonomyServiceProvider.overrideWith(
            (ref) async =>
                TaxonomyService()..loadFromCsv(
                  'scientific_name,common_name\n'
                  '$_robin,Rougegorge familier',
                ),
          ),
          effectiveSpeciesLocaleProvider.overrideWithValue('fr'),
          speciesSheetsProvider.overrideWith(
            (ref) async => sheets ?? SpeciesSheets({_robin: _sheet}),
          ),
          speciesDescriptionServiceProvider.overrideWithValue(
            _FakeDescriptions(),
          ),
          speciesPageLoaderProvider.overrideWithValue(loader),
          if (lpoRepository != null)
            sessionRepositoryProvider.overrideWithValue(lpoRepository),
          speciesClipPlayerProvider.overrideWithValue(player),
          speciesMiniMapTilesProvider.overrideWithValue(null),
          observationIndexServiceProvider.overrideWith(
            (ref) => _QuietIndex(prefs),
          ),
          liveStateProvider.overrideWith((ref) => liveState),
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
                ).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reduceMotion,
                ),
                child: child!,
              ),
          home:
              home ??
              const SpeciesPage(
                scientificName: _robin,
                commonName: 'Rougegorge familier',
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the page: contacts, here and now, sounds, sheet', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Rougegorge familier'), findsOneWidget);
    expect(find.text(_robin), findsOneWidget);
    expect(
      find.textContaining('Entendu 142 fois sur 38 jours'),
      findsOneWidget,
    );
    expect(find.text('37 bonnes sur 38 vérifiées'), findsOneWidget);
    expect(find.text('Ici en ce moment'), findsOneWidget);
    expect(find.text("Présent toute l'année."), findsOneWidget);
    expect(find.text('Mes sons'), findsOneWidget);
    expect(find.text('Voir les 9 enregistrements'), findsOneWidget);
    expect(find.text(_sheet.sections[SheetSection.summary]!), findsOneWidget);
    expect(find.text('Activité par heure'), findsOneWidget);
    // J6f-b fix: hour labels every 6 h, and the peak hour named below the
    // chart (hour 7 has the tally's only busy value).
    expect(find.text('0 h'), findsOneWidget);
    expect(find.text('6 h'), findsOneWidget);
    expect(find.text('12 h'), findsOneWidget);
    expect(find.text('18 h'), findsOneWidget);
    expect(find.text('Surtout vers 7 h'), findsOneWidget);
    expect(find.text('Voir sur la carte'), findsOneWidget);
    // J6f-b fix: the label is short enough to stay on one line.
    expect(find.text('En savoir plus'), findsOneWidget);
    expect(find.text('En savoir plus sur cette espèce'), findsNothing);
    expect(find.textContaining('Garde le son pour toi'), findsOneWidget);
    // The upstream description gives way to the AI sheet.
    expect(find.text('Description upstream.'), findsNothing);

    // First chip selected; another chip shows its paragraph.
    expect(find.text(_sheet.sections[SheetSection.size]!), findsOneWidget);
    await tester.ensureVisible(find.text('Migration'));
    await tester.tap(find.text('Migration'));
    await tester.pumpAndSettle();
    expect(find.text(_sheet.sections[SheetSection.migration]!), findsOneWidget);
    expect(find.text(_sheet.sections[SheetSection.size]!), findsNothing);
  });

  testWidgets('unexpected here: the page explains « Rare ici »', (
    tester,
  ) async {
    const explanation =
        'Le chant ressemble bien. C\'est le lieu ou la saison qui surprend : '
        'réécoute-le pour confirmer.';
    await pump(tester);
    expect(find.text(explanation), findsNothing);

    loader.unexpected = true;
    await pump(tester, home: const SizedBox());
    await pump(tester);
    expect(find.text(explanation), findsOneWidget);
  });

  testWidgets('sounds come right after the counters, before here and now '
      '(J7)', (tester) async {
    await pump(tester);
    final heard = tester.getTopLeft(find.byKey(const ValueKey('fiche-heard')));
    final sounds = tester.getTopLeft(
      find.byKey(const ValueKey('fiche-sounds')),
    );
    final here = tester.getTopLeft(find.text('Ici en ce moment'));
    expect(heard.dy, lessThan(sounds.dy));
    expect(sounds.dy, lessThan(here.dy));
    // The best recording leads with the big play button.
    final featured = find.descendant(
      of: find.byKey(const ValueKey('fiche-sounds-featured')),
      matching: find.byType(ClipPlayButton),
    );
    expect(tester.widget<ClipPlayButton>(featured).size, BirdySizes.mainAction);
  });

  testWidgets(
    'tapping an hour bar shows its own hour and count (J6f-b fix)',
    (tester) async {
      await pump(tester);
      expect(find.text('Surtout vers 7 h'), findsOneWidget);

      // The seasons chart (« Ici en ce moment ») also uses `ActivityBars`
      // now (J6f-b fix): the hour chart is the last one on the page.
      final hourChart = find.byType(ActivityBars).last;
      await tester.ensureVisible(hourChart);
      final rect = tester.getRect(hourChart);
      final slot = rect.width / 24;
      // Hour 4 has a single contact: distinct from the busy hour 7.
      await tester.tapAt(Offset(rect.left + slot * 4.5, rect.top + 5));
      await tester.pump();

      expect(find.text('Surtout vers 7 h'), findsNothing);
      expect(find.text('4 h — 1 contact'), findsOneWidget);
    },
  );

  testWidgets(
    'the seasons chart: peak caption, tap detail, current month marked '
    '(J6f-b fix)',
    (tester) async {
      // May (index 4) at its top, March (index 2) at half of it: a clear
      // peak and a distinct value to tap.
      final weeks = [
        for (var w = 0; w < 48; w++)
          switch (w ~/ 4) {
            4 => 1.0,
            2 => 0.5,
            _ => 0.0,
          },
      ];
      loader = _FakeLoader(
        recordValue: _heard(),
        year: YearPresence.fromWeeks(weeks),
      );
      await pump(tester);

      expect(find.text('Surtout en mai'), findsOneWidget);
      final seasons = find.byType(ActivityBars).first;
      final chart = tester.widget<ActivityBars>(seasons);
      // All 12 initials at 100 % text, the current month marked.
      expect(chart.labels.length, 12);
      expect(chart.highlightIndex, DateTime.now().month - 1);

      // The page is taller since J6h: bring the chart on screen first.
      await tester.ensureVisible(seasons);
      await tester.pump();
      final rect = tester.getRect(seasons);
      final slot = rect.width / 12;
      await tester.tapAt(Offset(rect.left + slot * 2.5, rect.top + 5));
      await tester.pump();

      expect(find.text('Surtout en mai'), findsNothing);
      expect(find.text('Mars — 50 % du pic'), findsOneWidget);
    },
  );

  testWidgets(
    'the seasons chart: quarterly labels at 130 % text (J6f-b fix)',
    (tester) async {
      await pump(tester, textScale: 1.3);
      final chart = tester.widget<ActivityBars>(
        find.byType(ActivityBars).first,
      );
      expect(chart.labels.length, 4);
    },
  );

  testWidgets(
    '« Voir sur la carte » opens the contact map filtered on the species',
    (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.text('Voir sur la carte'));
      await tester.tap(find.text('Voir sur la carte'));
      // Not pumpAndSettle: the map screen it opens keeps timers running
      // (tile loading, location) that never quiesce on their own.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final map = tester.widget<ContactMapScreen>(
        find.byType(ContactMapScreen),
      );
      expect(map.initialSpecies?.scientificName, _robin);
      expect(map.initialSpecies?.commonName, 'Rougegorge familier');
      // The species chip shows its name, not "Toutes les espèces".
      expect(find.text('Rougegorge familier'), findsWidgets);
      expect(find.text('Toutes les espèces'), findsNothing);
    },
  );

  testWidgets('play a recording and change a favorite', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byTooltip('Réécouter').first);
    await tester.tap(find.byTooltip('Réécouter').first);
    await tester.pump();
    expect(player.played, ['/clips/a.wav']);
    expect(find.byTooltip('Arrêter'), findsOneWidget);

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    expect(loader.favoriteCalls, [('b', true)]);
  });

  testWidgets('never heard, no sheet: invitation and upstream description', (
    tester,
  ) async {
    loader = _FakeLoader(recordValue: SpeciesRecord.empty);
    await pump(tester, sheets: SpeciesSheets.empty);
    expect(find.text("Tu ne l'as pas encore entendu."), findsOneWidget);
    expect(find.text('Description upstream.'), findsOneWidget);
    expect(find.text('Mes sons'), findsNothing);
    expect(find.text('Ici en ce moment'), findsNothing);
    expect(find.text('Activité par heure'), findsNothing);
  });

  testWidgets(
    'the tinted header shows the back button and the title at 130 % text',
    (tester) async {
      await pump(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
      // J6f: the mockup keeps the back button over the photo (unlike the
      // other overlays' `BirdyOverlayHeader`), so it carries the system
      // tooltip too.
      expect(find.byTooltip('Retour'), findsOneWidget);
      expect(find.text('Rougegorge familier'), findsOneWidget);
    },
  );

  for (final (label, dark, scale, size) in [
    ('dark', true, 1.0, const Size(390, 844)),
    ('large text', false, 1.3, const Size(360, 780)),
    ('landscape', false, 1.0, const Size(844, 390)),
    ('tablet', true, 1.3, const Size(1024, 1366)),
  ]) {
    testWidgets('lays out without overflow: $label', (tester) async {
      await pump(tester, dark: dark, textScale: scale, size: size);
      expect(tester.takeException(), isNull);
    });
  }

  Widget opener(void Function(BuildContext, WidgetRef) open) => Consumer(
    builder:
        (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => open(context, ref),
            child: const Text('open'),
          ),
        ),
  );

  testWidgets('the upstream overlay opens the page', (tester) async {
    await pump(
      tester,
      home: opener(
        (context, ref) => SpeciesInfoOverlay.show(
          context,
          ref,
          scientificName: _robin,
          commonName: 'Rougegorge familier',
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesPage), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('Retour'), findsOneWidget);
  });

  testWidgets('while listening, a sheet over the listening screen', (
    tester,
  ) async {
    await pump(
      tester,
      liveState: LiveState.active,
      home: opener(
        (context, ref) => showSpeciesPage(
          context,
          ref,
          scientificName: _robin,
          commonName: 'Rougegorge familier',
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(SpeciesPage), findsOneWidget);
    // Same close gesture as the full page, in the back arrow's place
    // (J6g-e): a close X and a visible grab handle, no back arrow.
    expect(find.byTooltip('Retour'), findsNothing);
    expect(find.byTooltip('Fermer'), findsOneWidget);
    expect(find.byKey(const ValueKey('fiche-grab-handle')), findsOneWidget);
    final full = tester.getTopLeft(find.byTooltip('Fermer'));

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(SpeciesPage), findsNothing);
    expect(full.dx, lessThan(40));
  });

  testWidgets('the sheet close button is a 48 dp target', (tester) async {
    await pump(
      tester,
      liveState: LiveState.active,
      home: opener(
        (context, ref) => showSpeciesPage(
          context,
          ref,
          scientificName: _robin,
          commonName: 'Rougegorge familier',
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byTooltip('Fermer'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the full page keeps its back arrow, no grab handle', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.byKey(const ValueKey('fiche-grab-handle')), findsNothing);
  });

  testWidgets('no Faune-France entry without a confirmed sighting', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('fiche-lpo-send')), findsNothing);
  });

  testWidgets('the Faune-France entry opens the send screen', (tester) async {
    final session =
        morningSession()
          ..detections.clear()
          ..detections.addAll([
            for (final name in [_robin, 'Turdus merula'])
              DetectionRecord(
                scientificName: name,
                commonName: name,
                confidence: 0.9,
                timestamp: DateTime(2026, 5, 1, 7, 10),
                latitude: 46.7,
                longitude: 1.2,
                reviewStatus: ReviewStatus.confirmed,
              ),
          ]);
    loader.lpoSession = session.id;
    await pump(tester, lpoRepository: _OneSessionRepository(session));
    final button = find.byKey(const ValueKey('fiche-lpo-send'));
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    final screen = tester.widget<LpoSendScreen>(find.byType(LpoSendScreen));
    // Only this species goes to the send screen.
    expect(screen.detections, hasLength(1));
    expect(screen.detections!.single.scientificName, _robin);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'LPO entry at 320 dp, 130 % text: no overflow, 48 dp target '
      '(${dark ? 'dark' : 'light'})',
      (tester) async {
        loader.lpoSession = 'sess-1';
        await pump(
          tester,
          dark: dark,
          textScale: 1.3,
          size: const Size(320, 640),
        );
        final button = find.byKey(const ValueKey('fiche-lpo-send'));
        await tester.scrollUntilVisible(
          button,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        final size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      },
    );
  }

  testWidgets('reduced motion: the sheet closes with the X, no animation', (
    tester,
  ) async {
    Widget home() => opener(
      (context, ref) => showSpeciesPage(
        context,
        ref,
        scientificName: _robin,
        commonName: 'Rougegorge familier',
      ),
    );
    await pump(
      tester,
      liveState: LiveState.active,
      home: home(),
      reduceMotion: true,
      size: const Size(320, 640),
      textScale: 1.3,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('fiche-grab-handle')), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesPage), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
