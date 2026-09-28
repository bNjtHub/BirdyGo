import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/listening_mode/continuous_noise_reducer.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode.dart';
import 'package:birdnet_live/fork/live/listening_mode_pill.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
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

  testWidgets('the pill opens the sheet and shows the chosen mode', (
    tester,
  ) async {
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
          home: const Scaffold(body: Center(child: LiveListeningModePill())),
        ),
      ),
    );
    expect(find.text('Normal'), findsOneWidget);

    await tester.tap(find.byType(LiveListeningModePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vent'));
    await tester.pumpAndSettle();

    expect(container.read(listeningModeProvider), ListeningMode.wind);
    expect(
      container.read(highPassFilterProvider),
      ListeningMode.wind.preset.highPassHz,
    );
    expect(find.widgetWithText(LiveListeningModePill, 'Vent'), findsOneWidget);
  });
}
