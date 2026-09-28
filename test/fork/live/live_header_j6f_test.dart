import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/live/listening_mode_pill.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/fork/live/live_header.dart';
import 'package:birdnet_live/fork/live/live_listening_layout.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/reliability/levels_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {double textScale = 1, bool scaffold = true}) =>
    MaterialApp(
      theme: BirdyTheme.dark(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder:
          (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
      home: scaffold ? Scaffold(body: child) : child,
    );

const _place = 'Le jardin, Beaulieu-sur-Brenne, Indre-et-Loire, France';

void main() {
  group('ListeningModePill', () {
    testWidgets('shows the mode, no chevron without a callback', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const Center(child: ListeningModePill(label: 'Normal'))),
      );
      expect(find.text('Normal'), findsOneWidget);
      expect(find.byIcon(AppIcons.expandMore), findsNothing);
      expect(
        tester.getSize(find.byType(ListeningModePill)).height,
        greaterThanOrEqualTo(BirdySizes.target),
      );
      expect(
        find.bySemanticsLabel("Conditions d'écoute : Normal"),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('with a callback: chevron and tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Center(
            child: ListeningModePill(label: 'Vent', onPressed: () => taps++),
          ),
        ),
      );
      expect(find.byIcon(AppIcons.expandMore), findsOneWidget);
      await tester.tap(find.text('Vent'));
      expect(taps, 1);
    });
  });

  group('LiveHeader (J6f)', () {
    for (final tiles in [true, false]) {
      testWidgets('place and pill fit 360 dp at 130 % (tiles: $tiles)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: LiveHeader(
                  statusText: 'En écoute',
                  live: true,
                  stats: const LiveStats(species: 5, contacts: 12),
                  elapsed: () => const Duration(minutes: 3),
                  expanded: false,
                  showTiles: tiles,
                  place: _place,
                  modeChip: const ListeningModePill(label: 'Normal'),
                  onLevelsInfo: () {},
                  onBack: () {},
                ),
              ),
            ),
            textScale: 1.3,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final place = tester.widget<Text>(find.text(_place));
        expect(place.maxLines, 1);
        expect(place.overflow, TextOverflow.ellipsis);
        expect(find.text('Normal'), findsOneWidget);
        // The menu is gone: help and settings live in the « i » sheet.
        expect(find.byIcon(AppIcons.moreVert), findsNothing);
      });
    }
  });

  group('LiveListeningLayout (J6f)', () {
    Widget layout({
      VoidCallback? onHelp,
      VoidCallback? onSettings,
      VoidCallback? onMode,
      Widget? moment,
    }) => LiveListeningLayout(
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
      onSettings: onSettings ?? () {},
      onHelp: onHelp ?? () {},
      place: _place,
      modeChip: ListeningModePill(label: 'Normal', onPressed: onMode),
      moment: moment,
    );

    testWidgets('help and settings stay reachable from the « i » sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var help = 0;
      var settings = 0;
      await tester.pumpWidget(
        _app(
          layout(onHelp: () => help++, onSettings: () => settings++),
          scaffold: false,
        ),
      );
      await tester.tap(find.byTooltip('Niveaux, aide et réglages'));
      await tester.pumpAndSettle();
      expect(find.byType(LevelsSheet), findsOneWidget);
      await tester.ensureVisible(find.text('Aide du mode En direct'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aide du mode En direct'));
      await tester.pumpAndSettle();
      expect(help, 1);
      expect(find.byType(LevelsSheet), findsNothing);

      await tester.tap(find.byTooltip('Niveaux, aide et réglages'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Paramètres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paramètres'));
      await tester.pumpAndSettle();
      expect(settings, 1);
      expect(find.byType(LevelsSheet), findsNothing);
    });

    testWidgets('moment screens keep the header and its pill', (tester) async {
      var modes = 0;
      for (final size in const [Size(400, 900), Size(900, 420)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            layout(
              onMode: () => modes++,
              moment: const ColoredBox(
                color: Colors.black,
                child: Center(child: Text('Première fois')),
              ),
            ),
            scaffold: false,
          ),
        );
        await tester.pump();
        expect(find.text('Première fois'), findsOneWidget);
        expect(find.text(_place).hitTestable(), findsOneWidget);
        await tester.tap(find.text('Normal'));
      }
      expect(modes, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('contrast (AA)', () {
    for (final c in const [BirdyColors.dark, BirdyColors.light]) {
      test('mode pill (${c.brightness.name})', () {
        final fill = Color.alphaBlend(c.tonal, c.background);
        expect(contrastRatio(c.text1, fill), greaterThanOrEqualTo(4.5));
        // Icon: non-text contrast.
        expect(contrastRatio(c.accentText, fill), greaterThanOrEqualTo(3));
        expect(contrastRatio(c.text2, fill), greaterThanOrEqualTo(3));
      });
    }
  });
}
