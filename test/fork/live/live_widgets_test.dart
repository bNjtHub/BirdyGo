import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/animated_count.dart';
import 'package:birdnet_live/fork/design/widgets/entrance.dart';
import 'package:birdnet_live/fork/live/detection_marks.dart';
import 'package:birdnet_live/fork/live/flip_move.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/fork/live/live_header.dart';
import 'package:birdnet_live/fork/live/live_listening_layout.dart';
import 'package:birdnet_live/fork/live/live_spectrogram_panel.dart';
import 'package:birdnet_live/fork/live/live_table.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  double textScale = 1,
  bool reduceMotion = false,
  bool scaffold = true,
}) => MaterialApp(
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
);

final _t0 = DateTime(2026, 9, 26, 7, 0);

LiveTableEntry _entry(
  String name,
  int second, {
  int count = 1,
  bool singing = false,
  String? common,
}) => LiveTableEntry(
  scientificName: name,
  commonName: common ?? name,
  sessionCount: count,
  total: count + 10,
  lastHeard: _t0.add(Duration(seconds: second)),
  record: DetectionRecord(
    scientificName: name,
    commonName: common ?? name,
    confidence: 0.9,
    timestamp: _t0.add(Duration(seconds: second)),
  ),
  singing: singing,
);

void main() {
  group('LiveTable', () {
    Future<void> pumpTable(
      WidgetTester tester,
      List<LiveTableEntry> entries, {
      bool reduceMotion = false,
      double textScale = 1,
    }) => tester.pumpWidget(
      _app(
        LiveTable(entries: entries),
        reduceMotion: reduceMotion,
        textScale: textScale,
      ),
    );

    double top(WidgetTester tester, String name) =>
        tester.getTopLeft(find.text(name)).dy;

    testWidgets('a new species enters on top with BirdyEntrance', (
      tester,
    ) async {
      await pumpTable(tester, [_entry('Merle', 0)]);
      expect(find.byType(BirdyEntrance), findsNothing);

      await pumpTable(tester, [_entry('Pinson', 10), _entry('Merle', 0)]);
      final entrance = find.ancestor(
        of: find.text('Pinson'),
        matching: find.byType(BirdyEntrance),
      );
      expect(entrance, findsOneWidget);
      await tester.pumpAndSettle();
      expect(top(tester, 'Pinson'), lessThan(top(tester, 'Merle')));
    });

    testWidgets('a species heard again slides to the top in 250 ms', (
      tester,
    ) async {
      final merle = _entry('Merle', 0);
      final pinson = _entry('Pinson', 10);
      await pumpTable(tester, [pinson, merle]);
      final pinsonTop = top(tester, 'Pinson');
      final merleTop = top(tester, 'Merle');

      await pumpTable(tester, [_entry('Merle', 20, count: 2), pinson]);
      // First frame: still drawn where it was.
      expect(top(tester, 'Merle'), closeTo(merleTop, 0.5));
      // The move starts on the next frame.
      await tester.pump();
      expect(top(tester, 'Merle'), closeTo(merleTop, 0.5));
      await tester.pump(const Duration(milliseconds: 125));
      final mid = top(tester, 'Merle');
      expect(mid, lessThan(merleTop));
      expect(mid, greaterThan(pinsonTop));
      await tester.pump(const Duration(milliseconds: 125));
      expect(top(tester, 'Merle'), closeTo(pinsonTop, 0.5));
      expect(top(tester, 'Pinson'), closeTo(merleTop, 2));
      expect(find.text('×2'), findsOneWidget);
    });

    testWidgets('the ×N counter bumps when it goes up', (tester) async {
      await pumpTable(tester, [_entry('Merle', 0)]);
      await pumpTable(tester, [_entry('Merle', 5, count: 2)]);
      await tester.pump(const Duration(milliseconds: 60));
      final scale = tester.widget<ScaleTransition>(
        find.ancestor(
          of: find.text('×2'),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, greaterThan(1));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedCount), findsOneWidget);
    });

    testWidgets('reduced motion: rows jump, no slide', (tester) async {
      final merle = _entry('Merle', 0);
      final pinson = _entry('Pinson', 10);
      await pumpTable(tester, [pinson, merle], reduceMotion: true);
      final pinsonTop = top(tester, 'Pinson');
      await pumpTable(tester, [
        _entry('Merle', 20, count: 2),
        pinson,
      ], reduceMotion: true);
      expect(top(tester, 'Merle'), closeTo(pinsonTop, 0.5));
      final flip = tester.renderObject<RenderFlipMove>(
        find.byType(FlipMove).first,
      );
      expect(flip.shift, 0);
    });

    testWidgets('names wrap at 130 % text, nothing overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpTable(tester, [
        _entry('A', 0, common: 'Pouillot de Bonelli occidental', count: 12),
        _entry('B', 1, common: 'Rougegorge familier', singing: true),
      ], textScale: 1.3);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Pouillot de Bonelli occidental'), findsOneWidget);
    });

    testWidgets('empty table shows the placeholder', (tester) async {
      await tester.pumpWidget(
        _app(const LiveTable(entries: [], empty: Text('vide'))),
      );
      expect(find.text('vide'), findsOneWidget);
    });
  });

  group('LiveSpectrogramPanel', () {
    Widget panel({required bool expanded, required VoidCallback onToggle}) =>
        LiveSpectrogramPanel(
          expanded: expanded,
          expandedHeight: 400,
          onToggle: onToggle,
          spectrogram: const ColoredBox(color: Colors.black),
          marks: const SizedBox(),
          semanticLabel: 'Spectre en direct',
          toggleLabel: 'Agrandir le spectre',
        );

    testWidgets('a tap toggles, the size animates in 250 ms', (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder:
                (context, setState) => Align(
                  alignment: Alignment.topCenter,
                  child: panel(
                    expanded: expanded,
                    onToggle: () => setState(() => expanded = !expanded),
                  ),
                ),
          ),
        ),
      );
      final finder = find.byType(LiveSpectrogramPanel);
      expect(tester.getSize(finder).height, LiveSpectrogramPanel.normalHeight);
      expect(
        find.descendant(of: finder, matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );

      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getSize(finder).height, 400);

      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.getSize(finder).height, LiveSpectrogramPanel.normalHeight);
    });

    testWidgets('screen readers get a button with the marked species', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(panel(expanded: false, onToggle: () {})));
      expect(
        tester.getSemantics(find.byType(LiveSpectrogramPanel)),
        matchesSemantics(
          label: 'Spectre en direct',
          isButton: true,
          hasTapAction: true,
          onTapHint: 'Agrandir le spectre',
        ),
      );
      handle.dispose();
    });
  });

  group('LiveControlBar', () {
    Future<List<String>> tapAll(
      WidgetTester tester,
      LiveControlPhase phase, {
      ValueNotifier<String?>? replaying,
    }) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: LiveControlBar(
              phase: phase,
              onStart: () => calls.add('start'),
              onStop: () => calls.add('stop'),
              onTogglePause: () => calls.add('pause'),
              replaying: replaying,
            ),
          ),
        ),
      );
      for (final label in ['Écouter', 'Arrêter', 'Pause', 'Reprendre']) {
        final button = find.text(label);
        if (button.evaluate().isNotEmpty) await tester.tap(button);
      }
      return calls;
    }

    testWidgets('before a session: Écouter', (tester) async {
      expect(await tapAll(tester, LiveControlPhase.idle), ['start']);
      expect(find.text('Arrêter'), findsNothing);
    });

    testWidgets('while starting: Écouter is busy', (tester) async {
      expect(await tapAll(tester, LiveControlPhase.starting), isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('listening: Arrêter and Pause', (tester) async {
      expect(await tapAll(tester, LiveControlPhase.active), ['stop', 'pause']);
      expect(find.text('Reprendre'), findsNothing);
    });

    testWidgets('paused: Reprendre', (tester) async {
      expect(await tapAll(tester, LiveControlPhase.paused), ['stop', 'pause']);
      expect(find.text('Reprendre'), findsOneWidget);
    });

    testWidgets('toast while a clip is replayed', (tester) async {
      final replaying = ValueNotifier<String?>(null);
      addTearDown(replaying.dispose);
      await tapAll(tester, LiveControlPhase.active, replaying: replaying);
      const toast = 'Réécoute à faible volume. L\'écoute continue.';
      expect(find.text(toast), findsNothing);
      replaying.value = '/clips/a.wav';
      await tester.pump();
      expect(find.text(toast), findsOneWidget);
      replaying.value = null;
      await tester.pump();
      expect(find.text(toast), findsNothing);
    });
  });

  group('LiveHeader', () {
    test('listening time format', () {
      expect(formatListeningTime(const Duration(seconds: 767)), '12:47');
      expect(formatListeningTime(const Duration(seconds: 5)), '00:05');
      expect(
        formatListeningTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    Widget header({required bool expanded}) => LiveHeader(
      statusText: 'En écoute',
      live: true,
      stats: const LiveStats(species: 5, contacts: 12),
      elapsed: () => const Duration(minutes: 12, seconds: 47),
      expanded: expanded,
      onToggleSpectrum: () {},
      onBack: () {},
      onSettings: () {},
      onHelp: () {},
    );

    testWidgets('three tiles, then a summary when enlarged', (tester) async {
      await tester.pumpWidget(_app(header(expanded: false)));
      expect(find.text('12:47'), findsOneWidget);
      expect(find.text('espèces'), findsOneWidget);
      expect(find.text('contacts'), findsOneWidget);
      expect(find.byTooltip('Agrandir le spectre'), findsOneWidget);

      await tester.pumpWidget(_app(header(expanded: true)));
      await tester.pumpAndSettle();
      expect(find.text('12:47'), findsNothing);
      expect(find.text('5 espèces · 12 contacts'), findsOneWidget);
      expect(find.byTooltip('Réduire le spectre'), findsOneWidget);
    });
  });

  group('LiveListeningLayout', () {
    Widget layout(List<LiveTableEntry> entries) => LiveListeningLayout(
      statusText: 'En écoute',
      live: true,
      capturing: false,
      elapsed: () => Duration.zero,
      entries: entries,
      spans: [
        MarkSpan(
          scientificName: 'Merle',
          label: 'Merle noir',
          start: _t0,
          end: _t0.add(const Duration(seconds: 2)),
        ),
      ],
      displaySeconds: 10,
      spectrogramBuilder:
          (expanded) => Text(expanded ? 'spectre agrandi' : 'spectre'),
      phase: LiveControlPhase.active,
      onStart: () {},
      onStop: () {},
      onTogglePause: () {},
      onBack: () {},
      onSettings: () {},
      onHelp: () {},
    );

    testWidgets('the header button enlarges the spectrogram to 60 %', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(layout([_entry('Merle', 0)]), scaffold: false),
      );
      expect(find.text('spectre'), findsOneWidget);

      await tester.tap(find.byTooltip('Agrandir le spectre'));
      await tester.pumpAndSettle();
      final body = tester.getSize(find.byType(LayoutBuilder).first).height;
      expect(find.text('spectre agrandi'), findsOneWidget);
      expect(
        tester.getSize(find.byType(LiveSpectrogramPanel)).height,
        closeTo(body * 0.6, 1),
      );
      final marks = tester.widget<DetectionMarks>(find.byType(DetectionMarks));
      expect(marks.showLabels, isTrue);
      final table = tester.widget<LiveTable>(find.byType(LiveTable));
      expect(table.compact, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
