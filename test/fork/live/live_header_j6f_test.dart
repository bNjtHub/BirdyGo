import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_buttons.dart';
import 'package:birdnet_live/fork/listening_mode/continuous_noise_reducer.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode_sheet.dart';
import 'package:birdnet_live/fork/live/listening_options.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/fork/live/live_header.dart';
import 'package:birdnet_live/fork/live/live_listening_layout.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/reliability/levels_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences _prefs;

Widget _app(Widget child, {double textScale = 1, bool scaffold = true}) =>
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
      child: MaterialApp(
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
      ),
    );

const _place = 'Le jardin, Beaulieu-sur-Brenne, Indre-et-Loire, France';

Widget _header({
  ListeningMode? mode = ListeningMode.normal,
  bool tiles = true,
  String status = 'En écoute',
  VoidCallback? onOptions,
}) => LiveHeader(
  statusText: status,
  live: true,
  stats: const LiveStats(species: 5, contacts: 12),
  elapsed: () => const Duration(minutes: 3),
  expanded: false,
  showTiles: tiles,
  place: _place,
  listeningMode: mode,
  onOptions: onOptions ?? () {},
  onBack: () {},
);

Widget _layout({
  VoidCallback? onHelp,
  VoidCallback? onSettings,
  ListeningMode? mode = ListeningMode.normal,
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
  listeningMode: mode,
  moment: moment,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => ForkNoiseReductionHook.setEnabled(false));

  group('LiveHeader (J6f)', () {
    testWidgets('one options button, neutral icon and plain status in Normal', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(_app(_header(onOptions: () => taps++)));
      await tester.pump(const Duration(milliseconds: 300));
      // Back and options, nothing else: no « i », no pill, no menu.
      expect(find.byType(BirdyIconButton), findsNWidgets(2));
      expect(find.byType(ListeningOptionsButton), findsOneWidget);
      expect(find.byIcon(AppIcons.infoOutline), findsNothing);
      expect(find.byIcon(AppIcons.moreVert), findsNothing);
      expect(find.byIcon(AppIcons.tuneRounded), findsOneWidget);
      expect(find.text('En écoute'), findsOneWidget);
      expect(
        find.bySemanticsLabel("Options d'écoute, mode Normal"),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(ListeningOptionsButton)).height,
        greaterThanOrEqualTo(BirdySizes.target),
      );
      await tester.tap(find.byType(ListeningOptionsButton));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('another mode follows the status and gives its icon', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(_header(mode: ListeningMode.wind)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('En écoute · Vent'), findsOneWidget);
      expect(find.byIcon(AppIcons.listeningWind), findsOneWidget);
      expect(
        find.bySemanticsLabel("Options d'écoute, mode Vent"),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('sliders moved by hand read « Personnalisé »', (tester) async {
      await tester.pumpWidget(_app(_header(mode: null)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('En écoute · Personnalisé'), findsOneWidget);
      expect(find.byTooltip("Options d'écoute, mode Personnalisé"), findsOne);
    });

    for (final tiles in [true, false]) {
      testWidgets('fits 320 dp at 130 % (tiles: $tiles)', (tester) async {
        await tester.pumpWidget(
          _app(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: _header(mode: ListeningMode.boost, tiles: tiles),
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
        final status = tester.widget<Text>(find.text('En écoute · Boost'));
        expect(status.maxLines, 1);
        expect(status.overflow, TextOverflow.ellipsis);
        // The status and place take all the width left by the two buttons.
        final options = tester.getTopLeft(find.byType(ListeningOptionsButton));
        final placeRight = tester.getTopRight(find.text(_place)).dx;
        expect(options.dx - placeRight, lessThanOrEqualTo(BirdySpace.s + 1));
      });
    }
  });

  group('LiveListeningLayout (J6f)', () {
    testWidgets('no overflow in landscape at 130 %', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          _layout(mode: ListeningMode.wind),
          scaffold: false,
          textScale: 1.3,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('En écoute · Vent'), findsOneWidget);
      expect(find.byType(ListeningOptionsButton), findsOneWidget);
    });

    testWidgets('the options sheet holds modes, levels, help and settings', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var help = 0;
      var settings = 0;
      await tester.pumpWidget(
        _app(
          _layout(onHelp: () => help++, onSettings: () => settings++),
          scaffold: false,
        ),
      );
      Future<void> open() async {
        await tester.tap(find.byType(ListeningOptionsButton));
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.byType(ListeningOptionsSheet), findsOneWidget);
      expect(find.byType(ListeningModeSection), findsOneWidget);
      expect(find.text("Conditions d'écoute"), findsOneWidget);
      expect(find.byKey(const ValueKey('listening-mode-wind')), findsOneWidget);
      for (final key in ['levels', 'help', 'settings']) {
        expect(find.byKey(ValueKey('listening-options-$key')), findsOneWidget);
      }

      // Levels open on top; going back returns to the options.
      await tester.ensureVisible(find.text("À quel point l'app est sûre"));
      await tester.tap(find.text("À quel point l'app est sûre"));
      await tester.pumpAndSettle();
      expect(find.byType(LevelsSheet), findsOneWidget);
      expect(find.text('Rare ici · à confirmer'), findsOneWidget);
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(LevelsSheet), findsNothing);
      expect(find.byType(ListeningOptionsSheet), findsOneWidget);

      await tester.ensureVisible(find.text('Aide du mode En direct'));
      await tester.tap(find.text('Aide du mode En direct'));
      await tester.pumpAndSettle();
      expect(help, 1);
      expect(find.byType(ListeningOptionsSheet), findsNothing);

      await open();
      await tester.ensureVisible(find.text('Paramètres'));
      await tester.tap(find.text('Paramètres'));
      await tester.pumpAndSettle();
      expect(settings, 1);
      expect(find.byType(ListeningOptionsSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('moment screens keep the header and its options button', (
      tester,
    ) async {
      for (final size in const [Size(400, 900), Size(900, 420)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            _layout(
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
        await tester.tap(find.byType(ListeningOptionsButton));
        await tester.pumpAndSettle();
        expect(find.byType(ListeningOptionsSheet), findsOneWidget);
        Navigator.of(tester.element(find.byType(ListeningOptionsSheet))).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  });
}
