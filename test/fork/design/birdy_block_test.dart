import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_block.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_filter_chip.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_headers.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool dark = false, double textScale = 1}) =>
    MaterialApp(
      theme: BirdyTheme.light(),
      darkTheme: BirdyTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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
      home: Scaffold(body: child),
    );

void main() {
  group('block tones reach AA for text1 and text2', () {
    for (final (name, c) in [
      ('light', BirdyColors.light),
      ('dark', BirdyColors.dark),
    ]) {
      for (final tone in BirdyBlockTone.values) {
        test('$name ${tone.name}', () {
          final fill = Color.alphaBlend(birdyBlockColor(c, tone), c.background);
          expect(contrastRatio(c.text1, fill), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(c.text2, fill), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  testWidgets('a tappable block is one button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        BirdyBlock(
          tone: BirdyBlockTone.oriole,
          semanticLabel: '9 jours de suite',
          onTap: () => taps++,
          child: const Text('9'),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('9 jours de suite'));
    expect(taps, 1);
  });

  testWidgets('progress ring and bar clamp their value', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            BirdyProgressRing(
              value: 1.4,
              color: Colors.teal,
              track: Colors.white,
              child: Text('5/8'),
            ),
            BirdyProgressBar(
              value: -1,
              color: Colors.teal,
              track: Colors.white,
            ),
          ],
        ),
      ),
    );
    expect(find.text('5/8'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0);
  });

  for (final dark in [false, true]) {
    testWidgets('headers hold at 130 % text (dark: $dark)', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              BirdyTabHeader(
                title: 'Mon carnet',
                caption: '24 espèces découvertes',
              ),
              BirdyOverlayHeader(title: 'Palmarès de la saison'),
            ],
          ),
          dark: dark,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Mon carnet'), findsOneWidget);
      expect(find.byTooltip('Retour'), findsOneWidget);
    });
  }

  testWidgets('overlay header: closing cross, disabled while saving', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      _app(
        BirdyOverlayHeader(
          title: 'Bilan',
          closing: true,
          enabled: false,
          onBack: () => closed++,
        ),
      ),
    );
    expect(find.byTooltip('Fermer'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    expect(closed, 0);
  });

  for (final dark in [false, true]) {
    testWidgets('a floating selected chip is opaque over a map (dark: $dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: BirdyFilterChip(
              label: 'Ce mois',
              selected: true,
              floating: true,
              onSelected: () {},
            ),
          ),
          dark: dark,
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(BirdyFilterChip),
          matching: find.byType(Material),
        ),
      );
      expect(material.color!.a, 1.0);
    });
  }

  testWidgets('filter chip: 48 dp, selected state announced', (tester) async {
    var picked = false;
    await tester.pumpWidget(
      _app(
        Center(
          child: BirdyFilterChip(
            label: 'Rares',
            selected: true,
            onSelected: () => picked = true,
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(BirdyFilterChip)).height,
      greaterThanOrEqualTo(BirdySizes.target),
    );
    expect(
      tester.getSemantics(find.text('Rares')),
      matchesSemantics(
        label: 'Rares',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text('Rares'));
    expect(picked, isTrue);
  });
}
