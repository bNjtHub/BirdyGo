import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:birdnet_live/fork/settings/simple_settings_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

  testWidgets('submitting the first name shows the toast', (tester) async {
    await pump(tester);
    final field = find.byKey(const ValueKey('settings-first-name'));
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'Léa');
    await tester.pump();
    expect(find.text(fr.forkFirstNameSaved), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text(fr.forkFirstNameSaved), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(AppIcons.checkCircle),
      ),
      findsOneWidget,
    );
  });

  test('toast check icon reaches 3:1 on surface3 in every bird and theme', () {
    for (final b in BirdyBird.values) {
      for (final br in Brightness.values) {
        final c = BirdyColors.forBird(b, br);
        expect(
          contrastRatio(c.sure.foreground, c.surface3),
          greaterThanOrEqualTo(3),
          reason: '$b $br',
        );
      }
    }
  });

  testWidgets('a picker choice shows the toast', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('settings-app-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(
      find.text(fr.forkSettingSaved(fr.settingsAppLanguage, 'English')),
      findsOneWidget,
    );
  });

  testWidgets('a switch gives no toast', (tester) async {
    await pump(tester);
    final row = find.byKey(const ValueKey('settings-live-always-dark'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });
}
