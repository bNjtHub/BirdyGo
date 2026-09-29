import 'package:birdnet_live/fork/design/birdy_theme.dart';
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

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
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
        child: MaterialApp(
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SimpleSettingsScreen(),
        ),
      ),
    );
  }

  final nameField = find.byKey(const ValueKey('settings-first-name'));

  group('Reglages J6h', () {
    testWidgets('block titles and the first name note are shown', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(fr.forkSettingsYou), findsOneWidget);
      expect(find.text(fr.forkSettingsLanguages), findsOneWidget);
      expect(find.text(fr.settingsTheme), findsOneWidget);
      expect(find.text(fr.forkFirstNameNote), findsOneWidget);
    });

    testWidgets('first name is saved trimmed and cleared when emptied', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(nameField, '  Léa ');
      await tester.pump();
      expect(container.read(firstNameProvider), 'Léa');
      expect(prefs.getString(kFirstNamePref), 'Léa');

      await tester.enterText(nameField, '');
      await tester.pump();
      expect(container.read(firstNameProvider), isNull);
      expect(prefs.getString(kFirstNamePref), isNull);
    });

    testWidgets('first name is cut at 24 characters', (tester) async {
      await pump(tester);
      await tester.enterText(nameField, 'A' * 40);
      await tester.pump();
      expect(container.read(firstNameProvider)!.length, kFirstNameMaxLength);
    });

    testWidgets('theme Auto sets the system mode', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await tester.tap(find.byKey(const ValueKey('theme-system')));
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    testWidgets('the three theme options sit on one row', (tester) async {
      await pump(tester);
      final tops = [
        for (final k in ['theme-light', 'theme-dark', 'theme-system'])
          tester.getTopLeft(find.byKey(ValueKey(k))).dy,
      ];
      expect(tops.toSet().length, 1);
      expect(find.text(fr.forkThemeAuto), findsOneWidget);
    });

    testWidgets('live theme chips write liveThemeProvider', (tester) async {
      await pump(tester);
      expect(container.read(liveThemeProvider), LiveTheme.dark);
      final light = find.byKey(const ValueKey('live-theme-light'));
      await tester.ensureVisible(light);
      await tester.pumpAndSettle();
      await tester.tap(light);
      await tester.pump();
      expect(container.read(liveThemeProvider), LiveTheme.light);
      final dark = find.byKey(const ValueKey('live-theme-dark'));
      await tester.ensureVisible(dark);
      await tester.pumpAndSettle();
      await tester.tap(dark);
      await tester.pump();
      expect(container.read(liveThemeProvider), LiveTheme.dark);
      expect(find.text(fr.forkLiveThemeCaption), findsOneWidget);
    });
  });
}
