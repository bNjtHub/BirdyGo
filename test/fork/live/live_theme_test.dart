import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/live/listening_options.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/fork/live/live_listening_layout.dart';
import 'package:birdnet_live/fork/live/live_spectrogram_panel.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 9, 26, 7, 0);

LiveTableEntry _entry() => LiveTableEntry(
  scientificName: 'Merle',
  commonName: 'Merle noir',
  sessionCount: 1,
  total: 11,
  lastHeard: _t0,
  record: DetectionRecord(
    scientificName: 'Merle',
    commonName: 'Merle noir',
    confidence: 0.9,
    timestamp: _t0,
  ),
  singing: false,
);

Widget _live({required bool light}) => MaterialApp(
  theme: BirdyTheme.dark(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ListeningTheme(
    light: light,
    child: Builder(
      builder:
          (_) => Scaffold(
            body: LiveListeningLayout(
              statusText: 'En écoute',
              live: true,
              capturing: false,
              elapsed: () => Duration.zero,
              entries: [_entry()],
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
            ),
          ),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  // The live logo loops while listening: no pumpAndSettle.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ButtonStyle? _stopStyle(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('Arrêter'),
            matching: find.byType(FilledButton),
          ),
        )
        .style;

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('light listening screen', () {
    testWidgets('dark by default: ink page, Brume « Arrêter »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_live(light: false));
      await _settle(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == BirdyColors.dark.background,
        ),
        findsWidgets,
      );
      expect(_stopStyle(tester)?.backgroundColor?.resolve({}), BirdyBrand.mist);
      expect(_stopStyle(tester)?.foregroundColor?.resolve({}), BirdyBrand.ink);
    });

    testWidgets('light: Brume page, ink « Arrêter » with Brume text', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_live(light: true));
      await _settle(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == BirdyColors.light.background,
        ),
        findsWidgets,
      );
      expect(_stopStyle(tester)?.backgroundColor?.resolve({}), BirdyBrand.ink);
      expect(_stopStyle(tester)?.foregroundColor?.resolve({}), BirdyBrand.mist);
    });

    testWidgets('the spectrogram panel stays dark in both themes', (
      tester,
    ) async {
      _phone(tester);
      for (final light in [false, true]) {
        await tester.pumpWidget(_live(light: light));
        await _settle(tester);
        final inside = tester.element(
          find
              .descendant(
                of: find.byType(LiveSpectrogramPanel),
                matching: find.byType(ClipRect),
              )
              .first,
        );
        expect(BirdyColors.of(inside).isDark, isTrue, reason: 'light=$light');
      }
    });
  });

  group('options sheet switch', () {
    testWidgets('« Écran clair » is bound to liveThemeProvider', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      _phone(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: BirdyTheme.dark(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListeningOptionsSheet(onHelp: () {}, onSettings: () {}),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Écran clair'), findsOneWidget);
      expect(container.read(liveThemeProvider), LiveTheme.dark);
      await tester.tap(find.byKey(const ValueKey('listening-options-light')));
      await tester.pump();
      expect(container.read(liveThemeProvider), LiveTheme.light);
      expect(prefs.getString(kLiveThemePref), 'light');
    });
  });
}
