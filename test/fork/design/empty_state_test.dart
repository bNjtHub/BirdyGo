import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/empty_state.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  theme: BirdyTheme.light(),
  darkTheme: BirdyTheme.dark(),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(body: child),
);

Container _disc(WidgetTester tester) => tester.widget<Container>(
  find.ancestor(of: find.byType(Icon), matching: find.byType(Container)).first,
);

void main() {
  testWidgets('full state: icon, title, body and primary action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        BirdyEmptyState(
          icon: AppIcons.hearing,
          title: 'Aucun oiseau pour l\'instant',
          body: 'Lance une écoute au lever du jour.',
          action: 'Écouter',
          onAction: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.hearing), findsOneWidget);
    expect(find.text('Aucun oiseau pour l\'instant'), findsOneWidget);
    expect(find.text('Lance une écoute au lever du jour.'), findsOneWidget);
    await tester.tap(find.text('Écouter'));
    expect(taps, 1);

    final disc = _disc(tester);
    expect(disc.constraints?.maxWidth, BirdyEmptyState.fullDisc);
    final c = BirdyColors.light;
    expect((disc.decoration as BoxDecoration).color, c.tonal);
    expect(tester.widget<Icon>(find.byType(Icon)).color, c.accentText);
  });

  testWidgets('no button without an action', (tester) async {
    await tester.pumpWidget(
      _app(
        const BirdyEmptyState(
          icon: AppIcons.libraryMusic,
          title: 'Pas encore d\'enregistrement',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Pas encore d\'enregistrement'), findsOneWidget);
  });

  testWidgets('inline state is a compact card with a smaller disc', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BirdyEmptyState.inline(
          icon: AppIcons.add,
          title: 'Aucune espèce pour l\'instant',
          body: 'Ajoute la première que tu vois.',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune espèce pour l\'instant'), findsOneWidget);
    expect(_disc(tester).constraints?.maxWidth, BirdyEmptyState.inlineDisc);
    expect(
      tester.widget<Icon>(find.byType(Icon)).size,
      BirdyEmptyState.inlineIcon,
    );
  });

  testWidgets('kinds pick the disc colors, light and dark', (tester) async {
    for (final dark in [false, true]) {
      final c = dark ? BirdyColors.dark : BirdyColors.light;
      final expected = {
        BirdyEmptyKind.firstUse: (c.tonal, c.accentText),
        BirdyEmptyKind.filtered: (c.borderOpaque, c.text2),
        BirdyEmptyKind.done: (c.sure.background, c.sure.foreground),
      };
      for (final kind in BirdyEmptyKind.values) {
        await tester.pumpWidget(
          _app(
            BirdyEmptyState(kind: kind, icon: AppIcons.check, title: 't'),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final (bg, fg) = expected[kind]!;
        expect(
          (_disc(tester).decoration as BoxDecoration).color,
          bg,
          reason: '$kind disc, dark=$dark',
        );
        expect(
          tester.widget<Icon>(find.byType(Icon)).color,
          fg,
          reason: '$kind icon, dark=$dark',
        );
      }
    }
  });

  testWidgets('filtered action is a tonal button', (tester) async {
    await tester.pumpWidget(
      _app(
        BirdyEmptyState(
          kind: BirdyEmptyKind.filtered,
          icon: AppIcons.searchOff,
          title: 'Aucun contact avec ces filtres',
          action: 'Toute la période',
          onAction: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final bg = button.style?.backgroundColor?.resolve({});
    expect(bg, BirdyColors.light.tonal);
  });

  testWidgets('body reflows at 130 % text scale without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        builder:
            (context, app) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: app!,
            ),
        home: const Scaffold(
          body: SizedBox(
            width: 360,
            child: BirdyEmptyState.inline(
              icon: AppIcons.hearing,
              title: 'Aucun oiseau sur la carte pour l\'instant',
              body:
                  'Lance une écoute avec le GPS activé : chaque oiseau '
                  'entendu viendra s\'y placer.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
