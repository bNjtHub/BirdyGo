import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_buttons.dart';
import 'package:birdnet_live/fork/home/birdygo_logo.dart';
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

Widget _app(
  Widget child, {
  double textScale = 1,
  bool scaffold = true,
  bool reduceMotion = false,
}) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
  child: MaterialApp(
    theme: BirdyTheme.dark(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder:
        (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
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
  LiveControlPhase phase = LiveControlPhase.active,
  VoidCallback? onOptions,
}) => LiveHeader(
  statusText: status,
  phase: phase,
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
  phase: LiveControlPhase.active,
  elapsed: () => Duration.zero,
  entries: const [],
  spans: const [],
  displaySeconds: 10,
  spectrogramBuilder: (_) => const SizedBox.expand(),
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

/// Bounded stand-in for `pumpAndSettle`: while listening, the live logo's
/// level meter loops (J6f, the one animation exception), so a real settle
/// never completes.
Future<void> pumpSettled(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The status line's `Text.rich` (icon + colored mode word), matched by its
/// semantics label rather than its rendered text, which embeds the icon as
/// a placeholder character.
Text statusText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .firstWhere((t) => t.textSpan != null);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => ForkNoiseReductionHook.setEnabled(false));

  group('LiveHeader (J6f)', () {
    testWidgets(
      'one options button, neutral icon, Normal still in the status',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(_app(_header(onOptions: () => taps++)));
        await tester.pump(const Duration(milliseconds: 300));
        // Back and options, nothing else: no « i », no pill, no menu.
        expect(find.byType(BirdyIconButton), findsNWidgets(2));
        expect(find.byType(ListeningOptionsButton), findsOneWidget);
        expect(find.byIcon(AppIcons.infoOutline), findsNothing);
        expect(find.byIcon(AppIcons.moreVert), findsNothing);
        // Options button: neutral tune icon in Normal.
        expect(find.byIcon(AppIcons.tuneRounded), findsOneWidget);
        // Status: always with the mode, even Normal, its icon inline.
        expect(statusText(tester).semanticsLabel, 'En écoute · Normal');
        expect(find.byIcon(AppIcons.listeningNormal), findsOneWidget);
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
      },
    );

    testWidgets('another mode follows the status and gives its icon', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(_header(mode: ListeningMode.wind)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(statusText(tester).semanticsLabel, 'En écoute · Vent');
      // One in the status, one on the options button.
      expect(find.byIcon(AppIcons.listeningWind), findsNWidgets(2));
      expect(
        find.bySemanticsLabel("Options d'écoute, mode Vent"),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('sliders moved by hand read « Personnalisé »', (tester) async {
      await tester.pumpWidget(_app(_header(mode: null)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(statusText(tester).semanticsLabel, 'En écoute · Personnalisé');
      expect(find.byTooltip("Options d'écoute, mode Personnalisé"), findsOne);
      // « Personnalisé » stays neutral: same tune icon as the options
      // button, no mode color of its own.
      expect(find.byIcon(AppIcons.tuneRounded), findsNWidgets(2));
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
        final status = statusText(tester);
        expect(status.semanticsLabel, 'En écoute · Boost');
        expect(status.maxLines, 1);
        expect(status.overflow, TextOverflow.ellipsis);
        // The status and place take all the width left by the two buttons.
        final options = tester.getTopLeft(find.byType(ListeningOptionsButton));
        final placeRight = tester.getTopRight(find.text(_place)).dx;
        expect(options.dx - placeRight, lessThanOrEqualTo(BirdySpace.s + 1));
      });
    }

    testWidgets('logo bars animate only while active', (tester) async {
      Future<BirdyGoLogoPainter> painterOf() async {
        final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        return paint
            .map((p) => p.painter)
            .whereType<BirdyGoLogoPainter>()
            .first;
      }

      await tester.pumpWidget(_app(_header(phase: LiveControlPhase.active)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      var painter = await painterOf();
      expect(painter.level, isNotNull);
      expect(painter.frozenLevel, isNull);

      await tester.pumpWidget(_app(_header(phase: LiveControlPhase.paused)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      painter = await painterOf();
      expect(painter.level, isNull);
      expect(painter.frozenLevel, BirdyGoLogoPainter.pausedBarLevel);

      await tester.pumpWidget(_app(_header(phase: LiveControlPhase.idle)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      painter = await painterOf();
      expect(painter.level, isNull);
      expect(painter.frozenLevel, isNull);
    });

    testWidgets('reduced motion: the logo never animates, even active', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_header(phase: LiveControlPhase.active), reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final painter =
          paint.map((p) => p.painter).whereType<BirdyGoLogoPainter>().first;
      expect(painter.level, isNull);
      expect(painter.frozenLevel, isNull);
    });
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
      expect(statusText(tester).semanticsLabel, 'En écoute · Vent');
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
      // Not pumpAndSettle: the live logo's level meter loops while active
      // (J6f), so a real settle never completes.
      Future<void> open() async {
        await tester.tap(find.byType(ListeningOptionsButton));
        await pumpSettled(tester);
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
      await pumpSettled(tester);
      expect(find.byType(LevelsSheet), findsOneWidget);
      expect(find.text('Rare ici · à confirmer'), findsOneWidget);
      await tester.tapAt(const Offset(200, 20));
      await pumpSettled(tester);
      expect(find.byType(LevelsSheet), findsNothing);
      expect(find.byType(ListeningOptionsSheet), findsOneWidget);

      await tester.ensureVisible(find.text('Aide du mode En direct'));
      await tester.tap(find.text('Aide du mode En direct'));
      await pumpSettled(tester);
      expect(help, 1);
      expect(find.byType(ListeningOptionsSheet), findsNothing);

      await open();
      await tester.ensureVisible(find.text('Paramètres'));
      await tester.tap(find.text('Paramètres'));
      await pumpSettled(tester);
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
        await pumpSettled(tester);
        expect(find.byType(ListeningOptionsSheet), findsOneWidget);
        Navigator.of(tester.element(find.byType(ListeningOptionsSheet))).pop();
        await pumpSettled(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
