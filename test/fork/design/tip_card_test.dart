import 'dart:math';

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/widgets/animated_count.dart';
import 'package:birdnet_live/fork/design/widgets/tip_card.dart';
import 'package:birdnet_live/fork/live/live_header.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: BirdyTheme.dark(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

const _tips = <BirdyTip>[
  (icon: AppIcons.air, title: 'Vent', body: 'Abrite le micro du vent.'),
  (
    icon: AppIcons.graphicEq,
    title: 'Spectrogramme',
    body:
        'Touche le spectrogramme pour l\'agrandir, avec l\'échelle en kHz '
        'et un trait sous chaque chant détecté.',
  ),
];

void main() {
  testWidgets('card: caption, title, body and icon', (tester) async {
    await tester.pumpWidget(
      _app(
        const BirdyTipCard(
          icon: AppIcons.air,
          title: 'Vent',
          body: 'Abrite le micro du vent.',
        ),
      ),
    );
    expect(find.text('Le saviez-vous ?'), findsOneWidget);
    expect(find.text('Vent'), findsOneWidget);
    expect(find.text('Abrite le micro du vent.'), findsOneWidget);
    expect(find.byIcon(AppIcons.air), findsOneWidget);
  });

  testWidgets('carousel: tap shows the next tip, height stays the same', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(BirdyTipCarousel(tips: _tips, random: Random(0))),
    );
    await tester.pumpAndSettle();

    double opacityOf(String title) =>
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(
                of: find.text(title),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity;

    final first = opacityOf('Vent') == 1 ? 'Vent' : 'Spectrogramme';
    final second = first == 'Vent' ? 'Spectrogramme' : 'Vent';
    final height = tester.getSize(find.byType(BirdyTipCarousel)).height;

    await tester.tap(find.byType(BirdyTipCarousel));
    await tester.pumpAndSettle();

    expect(opacityOf(second), 1);
    expect(opacityOf(first), 0);
    expect(tester.getSize(find.byType(BirdyTipCarousel)).height, height);
  });

  testWidgets('carousel: every card has its dots at the same place', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(SizedBox(width: 360, child: BirdyTipCarousel(tips: _tips))),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(BirdyTipCard);
    expect(cards, findsNWidgets(2));
    expect(tester.getRect(cards.at(0)), tester.getRect(cards.at(1)));
    final dots = find.byType(Wrap);
    expect(tester.getRect(dots.at(0)), tester.getRect(dots.at(1)));
  });

  testWidgets('stat tile keeps a long duration on one line', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 96,
          child: StatTile(
            value: Text(
              formatListeningTime(const Duration(hours: 1, minutes: 2)),
            ),
            label: 'durée',
          ),
        ),
      ),
    );
    final text = find.text('1:02:00');
    expect(tester.getSize(text).height, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}
