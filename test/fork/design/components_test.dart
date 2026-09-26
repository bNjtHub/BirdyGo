import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/design_gallery_screen.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/design/widgets/animated_count.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_buttons.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_pill.dart';
import 'package:birdnet_live/fork/design/widgets/clip_play_button.dart';
import 'package:birdnet_live/fork/design/widgets/entrance.dart';
import 'package:birdnet_live/fork/design/widgets/pressable.dart';
import 'package:birdnet_live/fork/design/widgets/species_avatar.dart';
import 'package:birdnet_live/fork/design/widgets/species_card.dart';
import 'package:birdnet_live/fork/design/widgets/species_tile.dart';
import 'package:birdnet_live/fork/reliability/reliability_badge.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  bool dark = false,
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: BirdyTheme.light(),
  darkTheme: BirdyTheme.dark(),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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
  home: Scaffold(body: child),
);

void main() {
  group('Pressable', () {
    Future<double> pressedScale(WidgetTester tester, bool reduced) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: Pressable(
              child: FilledButton(onPressed: () {}, child: const Text('A')),
            ),
          ),
          reduceMotion: reduced,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A')),
      );
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      await gesture.up();
      await tester.pumpAndSettle();
      return scale.scale;
    }

    testWidgets('shrinks to 0.97 while pressed', (tester) async {
      expect(await pressedScale(tester, false), BirdyMotion.pressScale);
    });

    testWidgets('does not move with reduced motion', (tester) async {
      expect(await pressedScale(tester, true), 1);
    });
  });

  group('AnimatedCount', () {
    Widget counter(int value, {bool reduced = false}) => _app(
      Center(child: AnimatedCount(value: value, format: (v) => '×$v')),
      reduceMotion: reduced,
    );

    double scale(WidgetTester tester) =>
        tester
            .widget<ScaleTransition>(
              find.descendant(
                of: find.byType(AnimatedCount),
                matching: find.byType(ScaleTransition),
              ),
            )
            .scale
            .value;

    testWidgets('bumps when the value goes up', (tester) async {
      await tester.pumpWidget(counter(3));
      await tester.pumpWidget(counter(4));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scale(tester), greaterThan(1));
      expect(scale(tester), lessThanOrEqualTo(BirdyMotion.counterBumpScale));
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
      expect(find.text('×4'), findsOneWidget);
    });

    testWidgets('no bump going down or with reduced motion', (tester) async {
      await tester.pumpWidget(counter(4));
      await tester.pumpWidget(counter(3));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scale(tester), 1);

      await tester.pumpWidget(counter(3, reduced: true));
      await tester.pumpWidget(counter(5, reduced: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scale(tester), 1);
      expect(find.text('×5'), findsOneWidget);
    });
  });

  group('badges', () {
    testWidgets('three levels with French labels', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              ReliabilityBadge(level: ReliabilityLevel.sure),
              ReliabilityBadge(level: ReliabilityLevel.probable),
              ReliabilityBadge(
                level: ReliabilityLevel.toCheck,
                unexpected: true,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Sûr'), findsOneWidget);
      expect(find.text('Probable'), findsOneWidget);
      expect(find.text('À vérifier'), findsOneWidget);
      expect(find.text('Inattendu ici'), findsOneWidget);
      expect(
        find.bySemanticsLabel('À vérifier, Inattendu ici'),
        findsOneWidget,
      );
      expect(find.byType(ReliabilityGlyph), findsNWidgets(3));
    });

    testWidgets('compact badge keeps its label for screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: ReliabilityBadge(
              level: ReliabilityLevel.sure,
              compact: true,
            ),
          ),
        ),
      );
      expect(find.text('Sûr'), findsNothing);
      expect(find.bySemanticsLabel('Sûr'), findsOneWidget);
    });

    testWidgets('badges fit in an unbounded row (live row trailing)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ListTile(
            title: Text('Rougegorge familier'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReliabilityBadge(
                  level: ReliabilityLevel.toCheck,
                  unexpected: true,
                ),
                SizedBox(width: 48, height: 48),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Inattendu ici'), findsOneWidget);
    });

    testWidgets('novelty pills', (tester) async {
      await tester.pumpWidget(
        _app(
          Wrap(
            children: [
              for (final kind in NoveltyKind.values) NoveltyPill(kind: kind),
            ],
          ),
          dark: true,
        ),
      );
      for (final label in [
        'Première fois',
        'Nouveau cette année',
        'Inattendu ici',
        'Nouveau',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('buttons', () {
    testWidgets('Écouter is 72 px tall and tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(Center(child: ListenButton(onPressed: () => taps++))),
      );
      expect(find.text('Écouter'), findsOneWidget);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        BirdySizes.listen,
      );
      await tester.tap(find.text('Écouter'));
      expect(taps, 1);
    });

    testWidgets('icon button: 48 dp and a label', (tester) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: BirdyIconButton(
              icon: Icons.close,
              semanticLabel: 'Fermer',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
      expect(find.byTooltip('Fermer'), findsOneWidget);
    });
  });

  group('ClipPlayButton', () {
    testWidgets('idle and playing states', (tester) async {
      var taps = 0;
      Widget button(ClipPlayState state) => _app(
        Center(
          child: ClipPlayButton(
            state: state,
            semanticLabel: 'Réécouter : Rougegorge familier',
            progress: 0.5,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pumpWidget(button(ClipPlayState.idle));
      expect(
        find.bySemanticsLabel('Réécouter : Rougegorge familier'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byType(ClipPlayButton));
      expect(taps, 1);
      expect(tester.getSize(find.byType(InkWell)), const Size(48, 48));

      await tester.pumpWidget(button(ClipPlayState.playing));
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, 0.5);
    });

    testWidgets('pending is not tappable', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: ClipPlayButton(
              state: ClipPlayState.pending,
              semanticLabel: 'Extrait en préparation…',
            ),
          ),
        ),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(find.byTooltip('Extrait en préparation…'), findsOneWidget);
    });
  });

  group('species', () {
    final tint = SpeciesTint.fromAccent(const Color(0xFF29A9D6));

    testWidgets('long names wrap at 130 % on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Padding(
            padding: const EdgeInsets.all(8),
            child: SpeciesTile(
              name: 'Martin-pêcheur d\'Europe',
              scientificName: 'Alcedo atthis',
              avatar: SpeciesAvatar(tint: tint),
              meta: const ReliabilityBadge(
                level: ReliabilityLevel.toCheck,
                unexpected: true,
              ),
              count: AnimatedCount(value: 12, format: (v) => '×$v'),
              action: ClipPlayButton(
                state: ClipPlayState.idle,
                semanticLabel: 'Réécouter',
                onPressed: () {},
              ),
              onTap: () {},
            ),
          ),
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      final name = tester.widget<Text>(find.text('Martin-pêcheur d\'Europe'));
      expect(name.maxLines, isNull);
      expect(name.overflow, isNull);
      expect(
        tester.getSize(find.byType(SpeciesTile)).height,
        greaterThanOrEqualTo(BirdySizes.row),
      );
    });

    testWidgets('cards build in both themes', (tester) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          _app(
            ListView(
              children: [
                SpeciesCard(
                  name: 'Martin-pêcheur d\'Europe',
                  hero: true,
                  tint: tint,
                  visual: SpeciesAvatar(tint: tint, size: 96),
                ),
                SpeciesCard(
                  name: 'Pic épeiche',
                  tint: tint,
                  visual: SpeciesAvatar(tint: tint, size: 56),
                  corner: const NoveltyPill(kind: NoveltyKind.isNew),
                ),
                SpeciesCard.toConfirm(
                  name: 'Huppe fasciée',
                  visual: const SpeciesAvatar(size: 56, muted: true),
                ),
                const SpeciesCard.mystery(
                  name: 'À découvrir',
                  visual: SpeciesAvatar(size: 56, muted: true),
                ),
              ],
            ),
            dark: dark,
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('À découvrir'), findsOneWidget);
        expect(
          tester.getSize(find.byType(SpeciesCard).at(1)).height,
          greaterThanOrEqualTo(BirdySizes.collectionCard),
        );
      }
    });

    testWidgets('avatar falls back to a silhouette', (tester) async {
      await tester.pumpWidget(_app(const Center(child: SpeciesAvatar())));
      expect(find.byType(Icon), findsOneWidget);
      expect(find.byType(ColorFiltered), findsNothing);

      await tester.pumpWidget(
        _app(const Center(child: SpeciesAvatar(muted: true, heroTag: 'x'))),
      );
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byType(Hero), findsOneWidget);
    });
  });

  group('BirdyEntrance', () {
    Future<Offset> startOffset(WidgetTester tester, bool reduced) async {
      await tester.pumpWidget(
        _app(
          const Align(
            alignment: Alignment.topLeft,
            child: BirdyEntrance(
              child: SizedBox(key: Key('item'), width: 10, height: 10),
            ),
          ),
          reduceMotion: reduced,
        ),
      );
      final start = tester.getCenter(find.byKey(const Key('item')));
      final opacity =
          tester
              .widget<FadeTransition>(find.byType(FadeTransition).last)
              .opacity
              .value;
      expect(opacity, 0);
      await tester.pumpAndSettle();
      final end = tester.getCenter(find.byKey(const Key('item')));
      return start - end;
    }

    testWidgets('slides in by 8 px', (tester) async {
      final delta = await startOffset(tester, false);
      expect(delta.dy, greaterThan(0));
      expect(delta.dy, lessThanOrEqualTo(BirdyMotion.maxOffset));
    });

    testWidgets('fades only with reduced motion', (tester) async {
      expect(await startOffset(tester, true), Offset.zero);
    });

    testWidgets('staggered items wait their turn', (tester) async {
      await tester.pumpWidget(
        _app(
          BirdyEntrance.staggered(
            index: 3,
            child: const SizedBox(key: Key('late'), width: 10, height: 10),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const Key('late')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0);
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
    });
  });

  testWidgets('gallery builds in light and dark at 130 %', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The pending clip spinner never settles: pump fixed durations.
    await tester.pumpWidget(_app(const DesignGalleryScreen(), textScale: 1.3));
    await tester.pump(const Duration(milliseconds: 500));
    for (final dark in [false, true]) {
      if (dark) {
        await tester.tap(find.text('Sombre'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          Theme.of(tester.element(find.byType(ListView))).brightness,
          Brightness.dark,
        );
      }
      await tester.dragUntilVisible(
        find.text('Animations'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 20000));
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
