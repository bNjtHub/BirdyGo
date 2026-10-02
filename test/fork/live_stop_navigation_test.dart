// Guards the stop navigation: live -> Bilan directly, no session library
// route in between (it flashed under the page transition after the upstream
// sync). A full LiveScreen needs audio/GPS services, so the two navigation
// facts are checked on the source and the route replacement on a navigator.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder extends NavigatorObserver {
  final events = <String>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) =>
      events.add('push:${route.settings.name}');
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      events.add(
        'replace:${oldRoute?.settings.name}->${newRoute?.settings.name}',
      );
}

void main() {
  test('live_screen finalize opens the Bilan without the session library', () {
    final src = File('lib/features/live/live_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(src.contains('SessionLibraryScreen'), isFalse);
    expect(
      src.contains('pushReplacement(\n          afterStopSummaryRoute('),
      isTrue,
    );
    // Every stop path (button, notification, background limit) goes through
    // the single finalize method.
    expect(
      src.contains('_finalizeAndReview(backgroundLimitReached: true)'),
      isTrue,
    );
  });

  testWidgets('replacing the live route records a single replace', (t) async {
    final rec = _Recorder();
    await t.pumpWidget(
      MaterialApp(
        navigatorObservers: [rec],
        initialRoute: '/',
        onGenerateRoute: (s) => MaterialPageRoute<void>(
          settings: s,
          builder: (_) => const SizedBox(),
        ),
      ),
    );
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'live'),
        builder: (_) => const SizedBox(),
      ),
    );
    await t.pumpAndSettle();
    rec.events.clear();
    nav.pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'bilan'),
        builder: (_) => const SizedBox(),
      ),
    );
    await t.pumpAndSettle();
    expect(rec.events, ['replace:live->bilan']);
  });
}
