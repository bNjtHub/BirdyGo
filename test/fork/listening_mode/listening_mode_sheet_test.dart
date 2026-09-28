import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/listening_mode/continuous_noise_reducer.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode_config.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode_sheet.dart';
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

  Future<ProviderContainer> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
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
          home: Scaffold(body: home),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('lists the four modes with Normal marked', (tester) async {
    await pump(tester, ListeningModeSheet(onSelected: (_) {}));
    expect(find.text("Conditions d'écoute"), findsOneWidget);
    expect(
      find.text(
        "Change à tout moment : l'écoute continue, "
        "l'analyse s'adapte tout de suite.",
      ),
      findsOneWidget,
    );
    for (final label in ['Normal', 'Vent', 'Boost']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.text('Ville'),
      kCityModeEnabled ? findsOneWidget : findsNothing,
    );
    final check = find.byIcon(AppIcons.listeningSelected);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(
        of: check,
        matching: find.byKey(const ValueKey('listening-mode-normal')),
      ),
      findsOneWidget,
    );
    final normal = tester.getSize(
      find.byKey(const ValueKey('listening-mode-normal')),
    );
    expect(normal.height, greaterThanOrEqualTo(48));
  });

  testWidgets('hides Ville when the flag is off', (tester) async {
    await pump(
      tester,
      ListeningModeSheet(onSelected: (_) {}, cityEnabled: false),
    );
    expect(find.text('Ville'), findsNothing);
    expect(find.byKey(const ValueKey('listening-mode-city')), findsNothing);
    expect(find.text('Vent'), findsOneWidget);
  });

  testWidgets('picking Vent applies it and confirms', (tester) async {
    final container = await pump(
      tester,
      Consumer(
        builder:
            (context, ref, _) => TextButton(
              onPressed: () => showListeningModeSheet(context, ref),
              child: const Text('open'),
            ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('listening-mode-wind')));
    await tester.pumpAndSettle();

    expect(container.read(listeningModeProvider), ListeningMode.wind);
    expect(container.read(highPassFilterProvider), kWindHighPassHz);
    expect(find.text('Mode Vent activé'), findsOneWidget);
    expect(find.byType(ListeningModeSheet), findsNothing);
  });
}
