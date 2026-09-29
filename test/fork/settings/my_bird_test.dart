import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_bird_picker.dart';
import 'package:birdnet_live/fork/design/widgets/singing_theme_logo.dart';
import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/fork/settings/simple_settings_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    Map<String, Object> initial = const {},
    bool reduced = true,
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder:
              (context, ref, _) => MaterialApp(
                theme: BirdyTheme.light(bird: ref.watch(birdyBirdProvider)),
                locale: const Locale('fr'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder:
                    (context, app) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(disableAnimations: reduced),
                      child: app!,
                    ),
                home: const SimpleSettingsScreen(),
              ),
        ),
      ),
    );
  }

  final row = find.byKey(const ValueKey('settings-my-bird'));

  testWidgets('the row shows the bird, its logo disc and opens the choice', (
    tester,
  ) async {
    await pump(tester);
    expect(find.descendant(of: row, matching: find.text('Mon oiseau')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Loriot')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.byType(SingingThemeLogo)),
        findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Choisis ton oiseau'), findsOneWidget);
    expect(find.byKey(const ValueKey('step-back')), findsOneWidget);
    // Not the onboarding: no step counter.
    expect(find.byKey(const ValueKey('step-label')), findsNothing);
  });

  testWidgets('a card previews at once, persists, and back keeps the choice', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(row);
    await tester.pumpAndSettle();

    final card = find.text('Martin-pêcheur');
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();
    expect(container.read(birdyBirdProvider), BirdyBird.martin);
    expect(prefs.getString(kBirdyBirdPref), 'martin');
    expect(
      tester
          .widget<BirdyBirdCard>(
            find.byWidgetPredicate(
              (w) => w is BirdyBirdCard && w.bird == BirdyBird.martin,
            ),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('step-back')));
    await tester.pumpAndSettle();
    expect(find.text(fr.forkSettingsTitle), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Martin-pêcheur')),
      findsOneWidget,
    );
  });

  testWidgets('« C\'est mon oiseau ! » goes back to Settings', (tester) async {
    await pump(tester);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('onb-bird-confirm')));
    await tester.tap(find.byKey(const ValueKey('onb-bird-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(fr.forkSettingsTitle), findsOneWidget);
  });

  testWidgets('a saved bird is the one selected on opening', (tester) async {
    await pump(tester, initial: {kBirdyBirdPref: 'etourneau'});
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(container.read(birdyBirdProvider), BirdyBird.etourneau);
    expect(
      tester
          .widget<BirdyBirdCard>(
            find.byWidgetPredicate(
              (w) => w is BirdyBirdCard && w.bird == BirdyBird.etourneau,
            ),
          )
          .selected,
      isTrue,
    );
  });
}
