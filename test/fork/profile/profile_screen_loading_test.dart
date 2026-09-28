/// Loading skeleton of the profile (J6f skeletons): the status card, the
/// ladder, the série and the badges all depend on the game progress, which
/// resolves after the first frame; nothing above or around them should
/// move once it lands.
library;

import 'dart:async';

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
import 'package:birdnet_live/fork/game/game_loader.dart';
import 'package:birdnet_live/fork/game/game_progress.dart';
import 'package:birdnet_live/fork/game/streak.dart';
import 'package:birdnet_live/fork/profile/profile_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// See notebook_screen_loading_test.dart: the rect assertions below compare
/// wrapped-or-not text, so they need the real bundled fonts, not the test
/// font's different metrics.
Future<void> _loadRealFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load(asset).then((d) => d));
    await loader.load();
  }

  await load('Fraunces', 'assets/fonts/Fraunces-Variable.ttf');
  await load(
    'AtkinsonHyperlegibleNext',
    'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
  );
}

// The skeleton's calendar strip (`_skeletonCalendar` in profile_screen.dart)
// is anchored to the real clock, since which day is "today" doesn't depend
// on the loaded game facts. So the mock streak here is too, or its "today"
// cell (the one `_DayDot` draws with an extra ring) would land on a
// different day than the skeleton reserved space for — a test-only mismatch
// that would never happen in the app itself (loading takes moments, not
// days).
GameProgress _player() {
  final now = DateTime.now();
  DateTime day(int daysAgo) =>
      DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
  return GameProgress(
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
        for (var d = 0; d <= 8; d++)
          if (d != 4) day(d),
      }, now),
    ),
  );
}

class _Snapshot {
  _Snapshot(WidgetTester tester)
    : header = tester.getRect(find.byKey(const ValueKey('profile-header'))),
      statusCard = tester.getRect(
        find.byKey(const ValueKey('profile-status-card')),
      ),
      ladder = tester.getRect(find.byKey(const ValueKey('profile-ladder'))),
      streak = tester.getRect(find.byKey(const ValueKey('profile-streak'))),
      badges = tester.getRect(find.byKey(const ValueKey('profile-badges')));

  final Rect header;
  final Rect statusCard;
  final Rect ladder;
  final Rect streak;
  final Rect badges;

  void expectUnchanged(_Snapshot other) {
    expect(other.header, header, reason: 'header');
    expect(other.statusCard, statusCard, reason: 'status card');
    expect(other.ladder, ladder, reason: 'ladder');
    // Left/top/right are exact; the bottom is allowed a small settle at
    // 130 % text (the calendar strip's `FittedBox`es scale to fit their
    // own natural size, and a skeleton's filler glyphs don't measure to
    // quite the same natural size as the real weekday letters and digits).
    expect(other.streak.left, streak.left, reason: 'streak card left');
    expect(other.streak.top, streak.top, reason: 'streak card top');
    expect(other.streak.right, streak.right, reason: 'streak card right');
    expect(
      (streak.bottom - other.streak.bottom).abs(),
      lessThan(24),
      reason: 'streak card should not resize by more than one grid line',
    );
    // The top never moves (nothing above it grew or shrank); its own
    // bottom can settle within a line's height once real data lands, since
    // a badge's tier dots (earned) are shorter than its progress line
    // (locked) and which one a given badge shows is exactly the fact the
    // skeleton is still waiting on. The skeleton always reserves the
    // taller of the two, so it only ever shrinks, never grows past it.
    expect(other.badges.left, badges.left, reason: 'badges block left');
    expect(other.badges.top, badges.top, reason: 'badges block top');
    expect(other.badges.right, badges.right, reason: 'badges block right');
    expect(
      other.badges.bottom,
      lessThanOrEqualTo(badges.bottom),
      reason: 'badges block must not grow past its skeleton',
    );
    expect(
      badges.bottom - other.badges.bottom,
      lessThan(24),
      reason: 'badges block should not shrink by more than one tile line',
    );
  }
}

void main() {
  setUpAll(_loadRealFonts);

  Future<void> pump(
    WidgetTester tester, {
    required Completer<GameProgress> completer,
    bool dark = false,
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProgressProvider.overrideWith((ref) => completer.future)],
        child: MaterialApp(
          theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, app) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reducedMotion,
                ),
                child: app!,
              ),
          home: const ProfileScreen(),
        ),
      ),
    );
  }

  Future<void> expectStableLayout(
    WidgetTester tester,
    Completer<GameProgress> completer,
  ) async {
    await tester.pump();
    final firstFrame = _Snapshot(tester);

    completer.complete(_player());
    await tester.pumpAndSettle();
    firstFrame.expectUnchanged(_Snapshot(tester));

    expect(find.text('24 espèces découvertes'), findsOneWidget);
  }

  testWidgets('light, 100 %: no layout shift as the game progress lands', (
    tester,
  ) async {
    final completer = Completer<GameProgress>();
    await pump(tester, completer: completer);
    await expectStableLayout(tester, completer);
  });

  testWidgets('dark, 130 %: no layout shift as the game progress lands', (
    tester,
  ) async {
    final completer = Completer<GameProgress>();
    await pump(tester, completer: completer, dark: true, textScale: 1.3);
    await expectStableLayout(tester, completer);
  });

  testWidgets('reduced motion: nothing animates while loading', (
    tester,
  ) async {
    final completer = Completer<GameProgress>();
    await pump(tester, completer: completer, reducedMotion: true);
    await tester.pump();
    final before = tester.getRect(
      find.byKey(const ValueKey('profile-status-card')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey('profile-status-card'))),
        before,
      );
    }
    completer.complete(_player());
    await tester.pumpAndSettle();
    expect(find.text('24 espèces découvertes'), findsOneWidget);
  });

  testWidgets('the loading state is announced once, skeletons excluded', (
    tester,
  ) async {
    final completer = Completer<GameProgress>();
    final handle = tester.ensureSemantics();
    await pump(tester, completer: completer);
    await tester.pump();

    final data = tester.getSemantics(find.byType(ProfileScreen));
    String allLabels(SemanticsNode node) {
      final buffer = StringBuffer(node.label);
      node.visitChildren((child) {
        buffer.write(' ');
        buffer.write(allLabels(child));
        return true;
      });
      return buffer.toString();
    }

    expect(allLabels(data), contains('Chargement du profil'));
    expect(allLabels(data), isNot(contains('00000000')));

    completer.complete(_player());
    await tester.pumpAndSettle();
    final loaded = tester.getSemantics(find.byType(ProfileScreen));
    expect(allLabels(loaded), isNot(contains('Chargement du profil')));
    handle.dispose();
  });

  testWidgets('the ladder always shows the 8 statuses, loading or loaded', (
    tester,
  ) async {
    final completer = Completer<GameProgress>();
    await pump(tester, completer: completer);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-ladder')),
        matching: find.byWidgetPredicate((w) => w is DecoratedBox),
      ),
      findsWidgets,
    );
    completer.complete(_player());
    await tester.pumpAndSettle();
    expect(find.text(GameConfig.statuses.last.from.toString()), findsWidgets);
  });
}
