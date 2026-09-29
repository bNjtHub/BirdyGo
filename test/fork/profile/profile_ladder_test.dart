import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/game_widgets.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/profile/profile_screen.dart';
import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameProgress _player() => GameProgress(
  GameFacts(
    verifiedBirds: {
      'Strix aluco',
      'Parus major',
      for (var i = 2; i < 24; i++) 'Species $i',
    },
    dawnChoruses: 1,
    earlyStarts: 2,
    reviewed: 36,
    migrants: const {'Sylvia atricapilla'},
    streak: computeStreak({
      for (var d = 18; d <= 26; d++)
        if (d != 22) DateTime(2026, 9, d),
    }, DateTime(2026, 9, 26, 9)),
  ),
);

void main() {
  Future<void> pump(WidgetTester tester, {String? firstName}) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      if (firstName != null) kFirstNamePref: firstName,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProgressProvider.overrideWith((ref) async => _player()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('congratulation without a first name keeps the old sentence', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Bravo, te voilà'), findsOneWidget);
  });

  testWidgets('congratulation greets the saved first name', (tester) async {
    await pump(tester, firstName: 'Benjamin');
    expect(find.text('Bravo Benjamin, te voilà'), findsOneWidget);
    expect(find.text('Bravo, te voilà'), findsNothing);
  });

  testWidgets('ladder: 3 strokes per row, between emblems, centered', (
    tester,
  ) async {
    await pump(tester);
    for (var j = 0; j < 3; j++) {
      // One stroke j per row, two rows.
      expect(find.byKey(ValueKey('ladder-stroke-$j')), findsNWidgets(2));
    }
    expect(find.byKey(const ValueKey('ladder-stroke-3')), findsNothing);

    final emblems = find.byWidgetPredicate(
      (w) => w is StatusEmblem && w.size == BirdySizes.levelEmblem,
    );
    expect(emblems, findsNWidgets(8));
    final emblemRects = [
      for (var i = 0; i < 8; i++) tester.getRect(emblems.at(i)),
    ];
    for (var row = 0; row < 2; row++) {
      for (var j = 0; j < 3; j++) {
        final stroke = tester.getRect(
          find.byKey(ValueKey('ladder-stroke-$j')).at(row),
        );
        final left = emblemRects[row * 4 + j];
        final right = emblemRects[row * 4 + j + 1];
        // Between the emblems, never inside their bounds.
        expect(stroke.left, greaterThanOrEqualTo(left.right - 0.01));
        expect(stroke.right, lessThanOrEqualTo(right.left + 0.01));
        // Centered vertically on the emblem, cell width minus 48 wide.
        expect(stroke.center.dy, closeTo(left.center.dy, 0.01));
        final cell = right.center.dx - left.center.dx;
        expect(stroke.width, closeTo(cell - BirdySizes.levelLineInset, 0.01));
      }
    }
  });
}
