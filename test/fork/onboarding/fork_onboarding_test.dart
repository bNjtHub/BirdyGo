import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/onboarding/fork_onboarding_screen.dart';
import 'package:birdnet_live/fork/onboarding/onboarding_permissions.dart';
import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePermissions implements OnboardingPermissions {
  FakePermissions({
    this.mic = OnboardingPermState.unknown,
    this.location = OnboardingPermState.unknown,
    this.micAnswer = OnboardingPermState.granted,
    this.locationAnswer = OnboardingPermState.granted,
  });

  OnboardingPermState mic;
  OnboardingPermState location;
  final OnboardingPermState micAnswer;
  final OnboardingPermState locationAnswer;
  int micRequests = 0;
  int locationRequests = 0;
  int settingsOpened = 0;

  @override
  Future<OnboardingPermState> microphoneState() async => mic;

  @override
  Future<OnboardingPermState> requestMicrophone() async {
    micRequests++;
    return mic = micAnswer;
  }

  @override
  Future<OnboardingPermState> locationState() async => location;

  @override
  Future<OnboardingPermState> requestLocation() async {
    locationRequests++;
    return location = locationAnswer;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// Shows the onboarding until both flags are set, then a stand-in home, like
/// `_AppGate`.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done =
        ref.watch(onboardingCompleteProvider) &&
        ref.watch(termsAcceptedProvider);
    return done ? const Text('HOME') : const ForkOnboardingScreen();
  }
}

void main() {
  late SharedPreferences prefs;

  Future<void> pump(
    WidgetTester tester,
    FakePermissions perms, {
    bool dark = false,
    double textScale = 1,
    Size size = const Size(390, 844),
    bool reduced = false,
    String locale = 'fr',
    Widget home = const _Gate(),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          onboardingPermissionsProvider.overrideWithValue(perms),
        ],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, app) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reduced,
                ),
                child: app!,
              ),
          home: home,
        ),
      ),
    );
    await settle(tester, reduced);
  }

  Future<void> swipeLeft(WidgetTester tester, bool reduced) async {
    await tester.drag(
      find.byKey(const ValueKey('onb-pages')),
      const Offset(-300, 0),
    );
    await settle(tester, reduced);
  }

  Future<void> toPermissions(WidgetTester tester, bool reduced) async {
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('onb-next')));
      await settle(tester, reduced);
    }
  }

  testWidgets('story pages, name page, swipe and next', (tester) async {
    await pump(tester, FakePermissions());
    expect(find.textContaining('reconnaît les oiseaux'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);

    await swipeLeft(tester, false);
    expect(find.text('Écoute, découvre, collectionne'), findsOneWidget);
    expect(find.text('Découvre ta fiche'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onb-next')));
    await settle(tester, false);
    expect(find.text('Sûr, Probable, À vérifier'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onb-next')));
    await settle(tester, false);
    expect(find.text("Comment tu t'appelles ?"), findsOneWidget);
    expect(find.byKey(const ValueKey('onb-name-skip')), findsOneWidget);
    // The top « Passer » is hidden here (kept for layout).
    expect(tester.widget<Visibility>(find.ancestor(
      of: find.byKey(const ValueKey('onb-skip')),
      matching: find.byType(Visibility),
    )).visible, isFalse);

    await tester.tap(find.byKey(const ValueKey('onb-name-skip')));
    await settle(tester, false);
    expect(find.text('Deux autorisations, et c\'est parti'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    expect(find.byKey(const ValueKey('onb-finish')), findsOneWidget);
    // « Passer » is hidden (kept for layout) on the last page.
    expect(tester.widget<Visibility>(find.ancestor(
      of: find.byKey(const ValueKey('onb-skip')),
      matching: find.byType(Visibility),
    )).visible, isFalse);
  });

  testWidgets('skip jumps to the permissions page', (tester) async {
    await pump(tester, FakePermissions());
    await tester.tap(find.byKey(const ValueKey('onb-skip')));
    await settle(tester, false);
    expect(find.byKey(const ValueKey('onb-mic')), findsOneWidget);
    expect(find.byKey(const ValueKey('onb-finish')), findsOneWidget);
  });

  testWidgets('English strings', (tester) async {
    await pump(tester, FakePermissions(), locale: 'en');
    expect(find.textContaining('recognizes birds'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('a language without fork strings falls back to English', (
    tester,
  ) async {
    await pump(tester, FakePermissions(), locale: 'de');
    expect(find.textContaining('recognizes birds'), findsOneWidget);
  });

  group('permissions', () {
    testWidgets('allow buttons ask, then show « Autorisé »', (tester) async {
      final perms = FakePermissions();
      await pump(tester, perms, reduced: true);
      await tester.tap(find.byKey(const ValueKey('onb-skip')));
      await settle(tester, true);

      await tester.tap(find.byKey(const ValueKey('onb-mic-allow')));
      await settle(tester, true);
      await tester.tap(find.byKey(const ValueKey('onb-location-allow')));
      await settle(tester, true);

      expect(perms.micRequests, 1);
      expect(perms.locationRequests, 1);
      expect(find.text('Autorisé'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('onb-mic-allow')), findsNothing);
    });

    testWidgets('refused location does not block and offers the settings', (
      tester,
    ) async {
      final perms = FakePermissions(
        mic: OnboardingPermState.granted,
        locationAnswer: OnboardingPermState.refused,
      );
      await pump(tester, perms, reduced: true);
      await tester.tap(find.byKey(const ValueKey('onb-skip')));
      await settle(tester, true);

      await tester.tap(find.byKey(const ValueKey('onb-location-allow')));
      await settle(tester, true);
      expect(find.textContaining('Position refusée'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('onb-location-settings')),
      );
      await tester.tap(find.byKey(const ValueKey('onb-location-settings')));
      expect(perms.settingsOpened, 1);

      // The final button still finishes.
      await tester.ensureVisible(find.byKey(const ValueKey('onb-finish')));
      await tester.tap(find.byKey(const ValueKey('onb-finish')));
      await settle(tester, true);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('location service off is explained, not blocking', (
      tester,
    ) async {
      final perms = FakePermissions(
        mic: OnboardingPermState.granted,
        location: OnboardingPermState.unavailable,
      );
      await pump(tester, perms, reduced: true);
      await tester.tap(find.byKey(const ValueKey('onb-skip')));
      await settle(tester, true);
      expect(find.textContaining('éteinte'), findsOneWidget);
      expect(find.byKey(const ValueKey('onb-location-allow')), findsNothing);
    });

    testWidgets('refused microphone explains it is needed to listen', (
      tester,
    ) async {
      final perms = FakePermissions(micAnswer: OnboardingPermState.refused);
      await pump(tester, perms, reduced: true);
      await tester.tap(find.byKey(const ValueKey('onb-skip')));
      await settle(tester, true);

      // The final button asks for the microphone first and stays here.
      await tester.ensureVisible(find.byKey(const ValueKey('onb-finish')));
      await tester.tap(find.byKey(const ValueKey('onb-finish')));
      await settle(tester, true);
      expect(perms.micRequests, 1);
      expect(find.text('HOME'), findsNothing);
      expect(find.textContaining('BirdyGo en a besoin pour écouter'),
          findsOneWidget);
      expect(find.text('Ouvrir les réglages'), findsOneWidget);
      expect(prefs.getBool('onboarding_complete') ?? false, isFalse);

      // A second tap finishes anyway: nobody is stuck.
      await tester.tap(find.byKey(const ValueKey('onb-finish')));
      await settle(tester, true);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  testWidgets('finishing sets the done flags and shows the home', (
    tester,
  ) async {
    final perms = FakePermissions(
      mic: OnboardingPermState.granted,
      location: OnboardingPermState.granted,
    );
    await pump(tester, perms, reduced: true);
    await toPermissions(tester, true);
    expect(find.text('HOME'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('onb-finish')));
    await tester.tap(find.byKey(const ValueKey('onb-finish')));
    await settle(tester, true);

    expect(find.text('HOME'), findsOneWidget);
    final keys = prefs.getKeys();
    expect(
      keys.where((k) => prefs.getBool(k) == true).length,
      greaterThanOrEqualTo(2),
      reason: 'onboarding and terms flags both set: $keys',
    );
  });

  group('first name step', () {
    Future<void> toName(WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('onb-next')));
        await settle(tester, true);
      }
    }

    testWidgets('Continuer saves the trimmed name and advances', (
      tester,
    ) async {
      await pump(tester, FakePermissions(), reduced: true);
      await toName(tester);
      await tester.enterText(
        find.byKey(const ValueKey('onb-name-field')),
        '  Benjamin ',
      );
      await tester.tap(find.byKey(const ValueKey('onb-next')));
      await settle(tester, true);
      expect(prefs.getString(kFirstNamePref), 'Benjamin');
      expect(find.byKey(const ValueKey('onb-finish')), findsOneWidget);
    });

    testWidgets('name is limited to 24 characters', (tester) async {
      await pump(tester, FakePermissions(), reduced: true);
      await toName(tester);
      await tester.enterText(
        find.byKey(const ValueKey('onb-name-field')),
        'A' * 40,
      );
      await tester.tap(find.byKey(const ValueKey('onb-next')));
      await settle(tester, true);
      expect(prefs.getString(kFirstNamePref), 'A' * 24);
    });

    testWidgets('Passer leaves the name empty and advances', (tester) async {
      await pump(tester, FakePermissions(), reduced: true);
      await toName(tester);
      await tester.enterText(
        find.byKey(const ValueKey('onb-name-field')),
        'Benjamin',
      );
      await tester.tap(find.byKey(const ValueKey('onb-name-skip')));
      await settle(tester, true);
      expect(prefs.getString(kFirstNamePref), isNull);
      expect(find.byKey(const ValueKey('onb-finish')), findsOneWidget);
    });

    testWidgets('no overflow with the keyboard on 360x640', (tester) async {
      await pump(
        tester,
        FakePermissions(),
        size: const Size(360, 640),
        reduced: true,
      );
      await toName(tester);
      await tester.tap(find.byKey(const ValueKey('onb-name-field')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 600); // 300 dp
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('onb-name-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('onb-next')), findsOneWidget);
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets('320 dp, 130 % text, ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        final perms = FakePermissions(
          mic: OnboardingPermState.refused,
          location: OnboardingPermState.refused,
        );
        await pump(
          tester,
          perms,
          dark: dark,
          textScale: 1.3,
          size: const Size(320, 568),
          reduced: true,
        );
        for (var i = 0; i < 4; i++) {
          expect(tester.takeException(), isNull, reason: 'page $i');
          await tester.tap(find.byKey(const ValueKey('onb-next')));
          await settle(tester, true);
        }
        expect(tester.takeException(), isNull, reason: 'permissions page');
        // 48 dp targets.
        final finish = tester.getSize(find.byKey(const ValueKey('onb-finish')));
        expect(finish.height, greaterThanOrEqualTo(72));
        final settings = find.byKey(const ValueKey('onb-mic-settings'));
        await tester.ensureVisible(settings);
        expect(tester.getSize(settings).height, greaterThanOrEqualTo(56));
      });
    }

    testWidgets('page 1 dark, 130 %, animations running', (tester) async {
      await pump(
        tester,
        FakePermissions(),
        dark: true,
        textScale: 1.3,
        size: const Size(320, 568),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('reduced motion', () {
    testWidgets('page 1 has no running animation', (tester) async {
      await pump(tester, FakePermissions(), reduced: true);
      // Would time out if a twinkle, spark or float loop were running.
      await tester.pumpAndSettle();
      expect(find.textContaining('reconnaît les oiseaux'), findsOneWidget);
    });

    testWidgets('normal motion keeps the hero alive (sanity)', (tester) async {
      await pump(tester, FakePermissions());
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  testWidgets('semantics: page dots and steps are labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, FakePermissions(), reduced: true);
    expect(find.bySemanticsLabel('Page 1 sur 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onb-next')));
    await settle(tester, true);
    expect(find.bySemanticsLabel(RegExp('Étape 1. Écoute')), findsOneWidget);
    handle.dispose();
  });
}

Future<void> settle(WidgetTester tester, bool reduced) async {
  if (reduced) {
    await tester.pumpAndSettle();
  } else {
    // Looping decor never settles: advance long enough for a page turn.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
  }
}
