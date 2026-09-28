import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/listening_mode/continuous_noise_reducer.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode.dart';
import 'package:birdnet_live/fork/live/listening_options.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/fork/live/live_listening_layout.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => ForkNoiseReductionHook.setEnabled(false));

  Future<ProviderContainer> pump(WidgetTester tester, Widget body) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BirdyTheme.dark(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  test('icon: neutral for Normal, the mode icon otherwise', () {
    expect(listeningOptionsIcon(ListeningMode.normal), AppIcons.tuneRounded);
    expect(listeningOptionsIcon(ListeningMode.wind), AppIcons.listeningWind);
    expect(listeningOptionsIcon(ListeningMode.boost), AppIcons.listeningBoost);
    expect(listeningOptionsIcon(null), listeningModeIcon(null));
  });

  testWidgets('without Ville, the sheet offers three modes', (tester) async {
    await pump(
      tester,
      ListeningOptionsSheet(
        onHelp: () {},
        onSettings: () {},
        cityEnabled: false,
      ),
    );
    for (final m in ['normal', 'wind', 'boost']) {
      expect(find.byKey(ValueKey('listening-mode-$m')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('listening-mode-city')), findsNothing);
    expect(find.text("À quel point l'app est sûre"), findsOneWidget);
    expect(find.text('Aide du mode En direct'), findsOneWidget);
    expect(find.text('Paramètres'), findsOneWidget);
  });

  testWidgets('choosing Vent applies it, confirms, and shows in the status', (
    tester,
  ) async {
    final container = await pump(
      tester,
      Consumer(
        builder:
            (context, ref, _) => LiveListeningLayout(
              statusText: 'En écoute',
              live: true,
              capturing: false,
              elapsed: () => Duration.zero,
              entries: const [],
              spans: const [],
              displaySeconds: 10,
              spectrogramBuilder: (_) => const SizedBox.expand(),
              phase: LiveControlPhase.active,
              onStart: () {},
              onStop: () {},
              onTogglePause: () {},
              onBack: () {},
              onSettings: () {},
              onHelp: () {},
              listeningMode: ref.watch(activeListeningModeProvider),
            ),
      ),
    );
    expect(find.text('En écoute'), findsOneWidget);

    await tester.tap(find.byTooltip("Options d'écoute, mode Normal"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('listening-mode-wind')));
    await tester.pumpAndSettle();

    expect(container.read(listeningModeProvider), ListeningMode.wind);
    expect(
      container.read(highPassFilterProvider),
      ListeningMode.wind.preset.highPassHz,
    );
    expect(find.byType(ListeningOptionsSheet), findsNothing);
    expect(find.text('Mode Vent activé'), findsOneWidget);
    expect(find.text('En écoute · Vent'), findsOneWidget);
    expect(find.byTooltip("Options d'écoute, mode Vent"), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListeningOptionsButton),
        matching: find.byIcon(AppIcons.listeningWind),
      ),
      findsOneWidget,
    );
  });
}
