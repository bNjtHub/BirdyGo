import 'dart:async';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/explore/widgets/species_info_overlay.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/data/observation_index_service.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
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

const _robin = 'Erithacus rubecula';

class _FakeLoader implements SpeciesPageLoader {
  _FakeLoader({required this.recordValue, this.year});

  final SpeciesRecord recordValue;
  final YearPresence? year;
  bool unexpected = false;
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
  Future<void> setFavorite(String key, {required bool favorite}) async =>
      favoriteCalls.add((key, favorite));
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
          effectiveSpeciesLocaleProvider.overrideWithValue('fr'),
          speciesSheetsProvider.overrideWith(
            (ref) async => sheets ?? SpeciesSheets({_robin: _sheet}),
          ),
          speciesDescriptionServiceProvider.overrideWithValue(
            _FakeDescriptions(),
          ),
          speciesPageLoaderProvider.overrideWithValue(loader),
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
                ).copyWith(textScaler: TextScaler.linear(textScale)),
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
    expect(find.text('Voir sur la carte'), findsOneWidget);
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
    expect(find.byTooltip('Retour'), findsNothing);
  });
}
