import 'dart:math';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/data/observation_index.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/game/fine_ear.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_screen.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_widgets.dart';
import 'package:birdnet_live/fork/game/quiz_sfx.dart';
import 'package:birdnet_live/fork/species_page/species_clip_player.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The default test font has other metrics: whether the intro fits without
/// scrolling only means something with the real bundled fonts.
Future<void> _loadRealFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load(asset).then((d) => d));
    await loader.load();
  }

  await load('Fraunces', 'assets/fonts/Fraunces-Variable.ttf');
  await load(
    'AtkinsonHyperlegibleNext',
    'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
  );
}

class _FakePlayer implements SpeciesClipPlayer {
  final ValueNotifier<String?> _playing = ValueNotifier(null);

  @override
  ValueListenable<String?> get playing => _playing;

  @override
  Future<void> play(String clipPath) async => _playing.value = clipPath;

  @override
  Future<void> stop() async => _playing.value = null;
}

class _FakeSfx implements QuizSfxPlayer {
  @override
  Future<void> play(QuizSound sound) async {}

  @override
  Future<void> dispose() async {}
}

IndexedDetection _clip(String name) => IndexedDetection(
  key: name,
  sessionId: 's',
  position: 0,
  scientificName: name,
  commonName: 'Common $name',
  start: DateTime(2026, 9, 20, 7),
  end: null,
  confidence: .95,
  reviewStatus: ReviewStatus.unreviewed,
  latitude: null,
  longitude: null,
  clipPath: '/clips/$name.wav',
);

void main() {
  testWidgets('the intro fits a 390 × 844 phone without scrolling', (
    tester,
  ) async {
    await _loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fineEarStoreProvider.overrideWithValue(FineEarStore(prefs)),
          speciesClipPlayerProvider.overrideWithValue(_FakePlayer()),
          quizSfxPlayerProvider.overrideWithValue(_FakeSfx()),
          effectiveSpeciesLocaleProvider.overrideWith((ref) => 'fr'),
          taxonomyServiceProvider.overrideWith((ref) async => TaxonomyService()),
        ],
        child: MaterialApp(
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FineEarQuizScreen(
            random: Random(3),
            loadClips:
                () async => {
                  for (var i = 0; i < 4; i++) 'Species $i': _clip('Species $i'),
                },
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text("C'est parti !"), findsOneWidget);
    expect(tester.takeException(), isNull);

    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroll.position.maxScrollExtent, 0);
    // The illustrated zone is the token's height.
    expect(
      tester.getSize(find.byType(QuizWell).first).height,
      BirdySizes.quizIntroHero,
    );
    // Back arrow on the intro, no cross.
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.byTooltip('Quitter le quiz'), findsNothing);
  });
}
