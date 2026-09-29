import 'package:birdnet_live/features/about/about_screen.dart';
import 'package:birdnet_live/features/explore/explore_screen.dart';
import 'package:birdnet_live/features/file_analysis/file_analysis_screen.dart';
import 'package:birdnet_live/features/history/session_library_screen.dart';
import 'package:birdnet_live/features/home/help_screen.dart';
import 'package:birdnet_live/features/point_count/point_count_setup_screen.dart';
import 'package:birdnet_live/features/settings/settings_screen.dart';
import 'package:birdnet_live/features/survey/survey_setup_screen.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/quiz_sfx.dart';
import 'package:birdnet_live/fork/garden/garden_count_screen.dart';
import 'package:birdnet_live/fork/home/more_sheet.dart';
import 'package:birdnet_live/fork/map/contact_map_screen.dart';
import 'package:birdnet_live/fork/map/sensitive_species.dart';
import 'package:birdnet_live/fork/ranking/ranking_screen.dart';
import 'package:birdnet_live/fork/reliability/quick_review_screen.dart';
import 'package:birdnet_live/fork/settings/simple_settings_screen.dart';
import 'package:birdnet_live/fork/sound_library/sound_library_screen.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<_Pushes> pump(
    WidgetTester tester, {
    required Widget home,
    bool dark = false,
    double textScale = 1.0,
    Size size = const Size(390, 844),
    bool reduced = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final pushes = _Pushes();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [pushes],
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
    return pushes;
  }

  Widget host() => Consumer(
    builder:
        (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => showMoreSheet(context, ref),
            child: const Text('open'),
          ),
        ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  /// The screen the last push would show (not built: real services needed).
  Future<Widget> pushed(WidgetTester tester, _Pushes pushes) async {
    final route = pushes.routes.last as MaterialPageRoute<void>;
    final screen = route.builder(tester.element(find.byType(Scaffold).first));
    await tester.pumpWidget(const SizedBox());
    return screen;
  }

  group('Plus sheet', () {
    testWidgets('shows the everyday tiles and a collapsed advanced section', (
      tester,
    ) async {
      await pump(tester, home: host());
      await openSheet(tester);
      expect(find.text(fr.forkMoreTitle), findsOneWidget);
      for (final label in [
        fr.forkRanking,
        fr.forkMap,
        fr.forkQuickReview,
        fr.forkSoundLibrary,
        fr.forkGardenTitle,
        fr.exploreMode,
        fr.sessionLibraryTitle,
        fr.helpTitle,
      ]) {
        await scrollTo(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await scrollTo(tester, find.text(fr.forkMoreAdvancedTools));
      expect(find.text(fr.forkSettingsTitle), findsOneWidget);
      expect(find.text(fr.about), findsOneWidget);
      // Collapsed: the field modes are not there yet.
      expect(find.text(fr.pointCountMode), findsNothing);
      expect(find.text(fr.aruMode), findsNothing);
      await scrollTo(
        tester,
        find.byKey(const ValueKey('more-advanced-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('more-advanced-toggle')));
      await tester.pumpAndSettle();
      for (final label in [
        fr.pointCountMode,
        fr.surveyMode,
        fr.aruMode,
        fr.fileAnalysisMode,
      ]) {
        await scrollTo(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    for (final (label, type) in <(String, Type)>[
      (fr.forkRanking, RankingScreen),
      (fr.forkMap, ContactMapScreen),
      (fr.forkQuickReview, QuickReviewScreen),
      (fr.forkSoundLibrary, SoundLibraryScreen),
      (fr.forkGardenTitle, GardenCountScreen),
      (fr.exploreMode, ExploreScreen),
      (fr.sessionLibraryTitle, SessionLibraryScreen),
      (fr.helpTitle, HelpScreen),
    ]) {
      testWidgets('tile $label opens $type', (tester) async {
        final pushes = await pump(tester, home: host());
        await openSheet(tester);
        await scrollTo(tester, find.text(label));
        await tester.tap(find.text(label));
        expect((await pushed(tester, pushes)).runtimeType, type);
      });
    }

    for (final (label, type) in <(String, Type)>[
      (fr.pointCountMode, PointCountSetupScreen),
      (fr.surveyMode, SurveySetupScreen),
      (fr.fileAnalysisMode, FileAnalysisScreen),
    ]) {
      testWidgets('advanced $label opens $type', (tester) async {
        final pushes = await pump(tester, home: host());
        await openSheet(tester);
        await scrollTo(tester, find.byKey(const ValueKey('more-advanced')));
        await tester.tap(find.byKey(const ValueKey('more-advanced-toggle')));
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text(label));
        await tester.tap(find.text(label));
        expect((await pushed(tester, pushes)).runtimeType, type);
      });
    }

    testWidgets('Reglages opens the simple settings', (tester) async {
      final pushes = await pump(tester, home: host());
      await openSheet(tester);
      await scrollTo(tester, find.byKey(const ValueKey('more-settings')));
      await tester.tap(find.byKey(const ValueKey('more-settings')));
      expect((await pushed(tester, pushes)).runtimeType, SimpleSettingsScreen);
    });

    testWidgets('A propos opens the about screen', (tester) async {
      final pushes = await pump(tester, home: host());
      await openSheet(tester);
      await scrollTo(tester, find.byKey(const ValueKey('more-about')));
      await tester.tap(find.byKey(const ValueKey('more-about')));
      expect((await pushed(tester, pushes)).runtimeType, AboutScreen);
    });

    for (final (name, dark, scale, size, reduced) in [
      ('small phone, 130 %', false, 1.3, const Size(320, 568), false),
      ('dark, 130 %, reduced motion', true, 1.3, const Size(360, 740), true),
      ('tablet', true, 1.0, const Size(1024, 1366), false),
    ]) {
      testWidgets('lays out without overflow: $name', (tester) async {
        await pump(
          tester,
          home: host(),
          dark: dark,
          textScale: scale,
          size: size,
          reduced: reduced,
        );
        await openSheet(tester);
        await scrollTo(
          tester,
          find.byKey(const ValueKey('more-advanced-toggle')),
        );
        await tester.tap(find.byKey(const ValueKey('more-advanced-toggle')));
        await tester.pumpAndSettle();
        await scrollTo(tester, find.byKey(const ValueKey('more-about')));
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const ValueKey('more-settings'))).height,
          greaterThanOrEqualTo(48),
        );
        final tile = find.byKey(ValueKey('more-tile-${fr.forkRanking}'));
        await scrollTo(tester, tile);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
      });
    }
  });

  group('simple settings', () {
    testWidgets('switches write the shared preferences', (tester) async {
      await pump(tester, home: const SimpleSettingsScreen());
      expect(find.text(fr.forkSettingsTitle), findsOneWidget);

      // Quiz sounds: on by default.
      expect(container.read(quizSoundOnProvider), isTrue);
      await tester.tap(find.byKey(const ValueKey('settings-quiz-sound')));
      await tester.pump();
      expect(prefs.getBool(kQuizSoundPref), isFalse);
      expect(container.read(quizSoundOnProvider), isFalse);

      // Online photos: off by default.
      await tester.tap(find.byKey(const ValueKey('settings-online-photos')));
      await tester.pump();
      expect(prefs.getBool(kOnlinePhotosPref), isTrue);

      // Blur sensitive species: on by default.
      await tester.tap(find.byKey(const ValueKey('settings-blur-sensitive')));
      await tester.pump();
      expect(prefs.getBool(kBlurSensitiveExportPref), isFalse);
    });

    testWidgets('theme chips write themeModeProvider', (tester) async {
      await pump(tester, home: const SimpleSettingsScreen());
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await tester.tap(find.byKey(const ValueKey('theme-light')));
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('language rows write the locale providers', (tester) async {
      await pump(tester, home: const SimpleSettingsScreen());
      await tester.tap(find.byKey(const ValueKey('settings-app-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(container.read(localeProvider), const Locale('en'));

      await tester.tap(find.byKey(const ValueKey('settings-species-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.settingsSpeciesLanguageFollowApp).last);
      await tester.pumpAndSettle();
      expect(container.read(speciesLanguageProvider), 'app');
    });

    testWidgets('Reglages avances opens the upstream settings', (tester) async {
      final pushes = await pump(tester, home: const SimpleSettingsScreen());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-advanced')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(fr.forkSettingsAdvancedWarning), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('settings-advanced')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-advanced')));
      expect((await pushed(tester, pushes)).runtimeType, SettingsScreen);
    });

    for (final (name, dark, scale, size) in [
      ('small phone, 130 %', false, 1.3, const Size(320, 568)),
      ('dark, 130 %', true, 1.3, const Size(360, 740)),
    ]) {
      testWidgets('lays out without overflow: $name', (tester) async {
        await pump(
          tester,
          home: const SimpleSettingsScreen(),
          dark: dark,
          textScale: scale,
          size: size,
        );
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('settings-quiz-sound')))
              .height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  });
}
