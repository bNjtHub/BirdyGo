import 'package:birdnet_live/fork/background/background_tip.dart';
import 'package:birdnet_live/fork/background/live_background.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/foreground_service_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    for (final o in ForegroundServiceOwner.values) {
      ForegroundServiceGuard.release(o);
    }
  });

  group('foreground service guard', () {
    test('Live and Survey never own the service together', () {
      expect(
        ForegroundServiceGuard.tryClaim(ForegroundServiceOwner.live),
        isTrue,
      );
      expect(
        ForegroundServiceGuard.tryClaim(ForegroundServiceOwner.survey),
        isFalse,
      );
      ForegroundServiceGuard.release(ForegroundServiceOwner.live);
      expect(
        ForegroundServiceGuard.tryClaim(ForegroundServiceOwner.survey),
        isTrue,
      );
      expect(
        ForegroundServiceGuard.tryClaim(ForegroundServiceOwner.live),
        isFalse,
      );
    });
  });

  group('AndroidLiveBackground', () {
    test('does nothing off Android and claims nothing', () async {
      final background = AndroidLiveBackground();
      expect(await background.start(), isFalse);
      expect(background.isRunning, isFalse);
      expect(ForegroundServiceGuard.owner, isNull);
      await background.stop();
      expect(ForegroundServiceGuard.owner, isNull);
    });

    test('its service id differs from Survey and ARU', () {
      expect(kLiveForegroundServiceId, isNot(anyOf(256, 512)));
    });
  });

  group('background tip', () {
    Future<SharedPreferences> prefs([Map<String, Object> v = const {}]) {
      SharedPreferences.setMockInitialValues(v);
      return SharedPreferences.getInstance();
    }

    Future<void> pump(
      WidgetTester tester,
      SharedPreferences p, {
      required bool android,
      String locale = 'fr',
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(p)],
          child: MaterialApp(
            theme: BirdyTheme.dark(),
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder:
                  (context, ref, _) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => showBackgroundTipOnce(
                            context,
                            ref,
                            android: android,
                          ),
                      child: const Text('start'),
                    ),
                  ),
            ),
          ),
        ),
      );
    }

    testWidgets('shown once, at the first listening', (tester) async {
      final p = await prefs();
      await pump(tester, p, android: true);
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundTipSheet), findsOneWidget);
      expect(find.text('Écouter écran éteint'), findsOneWidget);
      expect(find.textContaining('sans restriction de batterie'), findsOne);
      expect(p.getBool(kBackgroundTipShownKey), isTrue);

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundTipSheet), findsNothing);
    });

    testWidgets('never off Android', (tester) async {
      final p = await prefs();
      await pump(tester, p, android: false);
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundTipSheet), findsNothing);
      expect(p.getBool(kBackgroundTipShownKey), isNull);
    });

    testWidgets('English', (tester) async {
      final p = await prefs();
      await pump(tester, p, android: true, locale: 'en');
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text('Listen with the screen off'), findsOneWidget);
      expect(find.text('Open the settings'), findsOneWidget);
    });
  });
}
