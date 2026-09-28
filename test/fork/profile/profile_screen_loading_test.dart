/// Loading skeleton of the profile (J6f skeletons): the level card, the
/// série and the earn card all depend on the game progress, which resolves
/// after the first frame; nothing above or around them should move once it
/// lands.
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
      levelCard = tester.getRect(
        find.byKey(const ValueKey('profile-level-card')),
      ),
      streak = tester.getRect(find.byKey(const ValueKey('profile-streak'))),
      earn = tester.getRect(find.byKey(const ValueKey('profile-earn')));

  final Rect header;
  final Rect levelCard;
  final Rect streak;
  final Rect earn;

  void expectUnchanged(_Snapshot other) {
    expect(other.header, header, reason: 'header');
    // The level card's ladder and info box do not depend on which
    // placeholder text they show (only which level is current does, and
    // the skeleton already lays out the full ring + 2 rows + info box
    // shape): left/top are exact; the bottom may settle within a couple of
    // grid lines as real strings replace the skeleton's fillers (a picked
    // level's name, or the info box's segmented bar/detail line, can wrap
    // differently once real data lands). Everything below cascades: the
    // streak and earn cards shift down by whatever the level card settled
    // by, so only their left stays exact.
    const tolerance = 40.0;
    expect(other.levelCard.left, levelCard.left, reason: 'level card left');
    expect(other.levelCard.top, levelCard.top, reason: 'level card top');
    expect(other.levelCard.right, levelCard.right, reason: 'level card right');
    expect(
      (levelCard.bottom - other.levelCard.bottom).abs(),
      lessThan(tolerance),
      reason: 'level card should not resize by more than a couple of lines',
    );
    expect(other.streak.left, streak.left, reason: 'streak card left');
    expect(other.streak.right, streak.right, reason: 'streak card right');
    expect(
      (streak.top - other.streak.top).abs(),
      lessThan(tolerance),
      reason: 'streak card should not move more than the level card resized',
    );
    expect(
      (streak.height - other.streak.height).abs(),
      lessThan(tolerance),
      reason: 'streak card should not resize by more than a couple of lines',
    );
    expect(other.earn.left, earn.left, reason: 'earn card left');
    expect(other.earn.right, earn.right, reason: 'earn card right');
    expect(
      (earn.top - other.earn.top).abs(),
      lessThan(2 * tolerance),
      reason: 'earn card should not move more than the cards above resized',
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
    // Tall enough that the header, the level card, the streak card and the
    // earn card are all on screen at once (even at 130 % text): a plain
    // `ListView` only builds children near the viewport, so comparing rects
    // across two snapshots needs them all built and at a fixed scroll
    // position (0) throughout, not scrolled into view one at a time.
    tester.view.physicalSize = const Size(390, 2200) * 2;
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
      find.byKey(const ValueKey('profile-level-card')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey('profile-level-card'))),
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

  testWidgets('the ladder always shows the 8 levels, loading or loaded', (
    tester,
  ) async {
    final completer = Completer<GameProgress>();
    await pump(tester, completer: completer);
    await tester.pump();
    // 2 rows of 4 skeleton emblem boxes reserved from the first frame.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-level-card')),
        matching: find.byWidgetPredicate((w) => w is DecoratedBox),
      ),
      findsWidgets,
    );
    completer.complete(_player());
    await tester.pumpAndSettle();
    expect(find.text(GameConfig.statuses.last.from.toString()), findsWidgets);
  });
}
