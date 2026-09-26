import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ValueNotifier<String?> replaying;
  late List<String> calls;

  setUp(() {
    replaying = ValueNotifier(null);
    calls = [];
  });

  Widget app(LiveBarState state) => MaterialApp(
    theme: BirdyTheme.dark(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: LiveControlBar(
          state: state,
          onStart: () => calls.add('start'),
          onStop: () => calls.add('stop'),
          onPauseToggle: () => calls.add('pause'),
          replaying: replaying,
        ),
      ),
    ),
  );

  testWidgets('before the session: one « Écouter » button', (tester) async {
    await tester.pumpWidget(app(LiveBarState.idle));
    expect(find.text('Arrêter'), findsNothing);
    await tester.tap(find.text('Écouter'));
    expect(calls, ['start']);
  });

  testWidgets('while starting, « Écouter » waits', (tester) async {
    await tester.pumpWidget(app(LiveBarState.starting));
    await tester.tap(find.text('Écouter'), warnIfMissed: false);
    expect(calls, isEmpty);
  });

  testWidgets('listening: Arrêter and Pause', (tester) async {
    await tester.pumpWidget(app(LiveBarState.active));
    await tester.tap(find.text('Arrêter'));
    await tester.tap(find.text('Pause'));
    expect(calls, ['stop', 'pause']);
  });

  testWidgets('paused: Reprendre', (tester) async {
    await tester.pumpWidget(app(LiveBarState.paused));
    expect(find.text('Pause'), findsNothing);
    await tester.tap(find.text('Reprendre'));
    expect(calls, ['pause']);
  });

  testWidgets('a notice shows while a clip is replayed', (tester) async {
    await tester.pumpWidget(app(LiveBarState.active));
    const notice = 'Réécoute à faible volume. L\'écoute continue.';
    expect(find.text(notice), findsNothing);
    replaying.value = 'clip.wav';
    await tester.pumpAndSettle();
    expect(find.text(notice), findsOneWidget);
    replaying.value = null;
    await tester.pumpAndSettle();
    expect(find.text(notice), findsNothing);
  });
}
