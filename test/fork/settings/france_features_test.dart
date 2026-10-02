import 'package:birdnet_live/fork/home/more_sheet.dart';
import 'package:birdnet_live/fork/lpo/lpo_send_button.dart';
import 'package:birdnet_live/fork/lpo/species_lpo_entry.dart';
import 'package:birdnet_live/fork/notifications/species_notifier.dart';
import 'package:birdnet_live/fork/settings/france_features.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('franceFeaturesRule', () {
    test('fr_FR is visible', () {
      expect(franceFeaturesRule(deviceCountry: 'FR', uiLanguage: 'fr'), isTrue);
    });
    test('en_US is hidden', () {
      expect(
        franceFeaturesRule(deviceCountry: 'US', uiLanguage: 'en'),
        isFalse,
      );
    });
    test('French UI with US region is visible', () {
      expect(franceFeaturesRule(deviceCountry: 'US', uiLanguage: 'fr'), isTrue);
    });
    test('English UI with FR region is visible', () {
      expect(franceFeaturesRule(deviceCountry: 'FR', uiLanguage: 'en'), isTrue);
    });
  });

  test('provider combines region and UI language', () {
    for (final (region, lang, expected) in [
      (true, 'en', true),
      (false, 'fr', true),
      (false, 'en', false),
    ]) {
      final c = ProviderContainer(
        overrides: [deviceRegionIsFranceProvider.overrideWithValue(region)],
      );
      addTearDown(c.dispose);
      expect(c.read(franceFeaturesProvider(lang)), expected);
    }
  });

  Future<void> pump(WidgetTester tester, Widget child, String lang) async {
    tester.view.physicalSize = const Size(780, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceRegionIsFranceProvider.overrideWithValue(false)],
        child: MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (lang, visible) in [('en', false), ('fr', true)]) {
    testWidgets('More sheet garden entry, $lang UI: $visible', (tester) async {
      await pump(
        tester,
        MoreSheet(onOpen: (_) {}, aruScreen: () => const SizedBox()),
        lang,
      );
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(
        find.text(l10n.forkGardenTitle),
        visible ? findsOneWidget : findsNothing,
      );
    });

    testWidgets('species page LPO entry, $lang UI: $visible', (tester) async {
      await pump(tester, SpeciesLpoEntry(onSend: () {}), lang);
      expect(
        find.byKey(const ValueKey('fiche-lpo-send')),
        visible ? findsOneWidget : findsNothing,
      );
    });

    testWidgets('Bilan LPO button, $lang UI: $visible', (tester) async {
      final session = LiveSession.fromJson({
        'id': 's',
        'startTime': DateTime.utc(2026, 9, 26, 5).toIso8601String(),
        'detections': <Map<String, dynamic>>[],
      });
      await pump(tester, LpoSendButton(session: session), lang);
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(
        find.text(l10n.forkLpoSendButton),
        visible ? findsOneWidget : findsNothing,
      );
    });
  }

  group('notificationTime', () {
    final t = DateTime(2026, 9, 26, 19, 41);
    test('French keeps H:mm', () {
      expect(notificationTime(t, 'fr', alwaysUse24Hour: false), '19:41');
    });
    test('English uses 12 h unless the platform asks for 24 h', () {
      expect(notificationTime(t, 'en', alwaysUse24Hour: false), contains('PM'));
      expect(notificationTime(t, 'en', alwaysUse24Hour: true), '19:41');
    });
  });
}
