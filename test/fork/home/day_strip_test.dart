import 'package:birdnet_live/fork/day/day_times.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_buttons.dart';
import 'package:birdnet_live/fork/home/day_sheet.dart';
import 'package:birdnet_live/fork/home/day_strip.dart';
import 'package:birdnet_live/fork/home/home_text.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _times = DayTimes(
  sunrise: DateTime(2026, 9, 29, 7, 36),
  sunset: DateTime(2026, 9, 29, 19, 41),
);

Widget _app(Widget child) => MaterialApp(
  theme: BirdyTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  Future<void> size(WidgetTester tester, Size s) async {
    tester.view.physicalSize = s * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('five pills, never wrapped, even at 320 dp and 130 %', (
    tester,
  ) async {
    await size(tester, const Size(320, 640));
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BirdySpace.page),
            child: DayStrip(times: _times, onMoment: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final tops = {
      for (final m in DayMoment.values)
        tester.getRect(find.byKey(ValueKey('day-pill-${m.name}'))).top,
    };
    expect(tops, hasLength(1));
    final strip = tester.getRect(find.byType(DayStrip));
    for (final m in DayMoment.values) {
      final r = tester.getRect(find.byKey(ValueKey('day-pill-${m.name}')));
      expect(r.left, greaterThanOrEqualTo(strip.left));
      expect(r.right, lessThanOrEqualTo(strip.right));
    }
  });

  testWidgets('shows the five times', (tester) async {
    await tester.pumpWidget(_app(DayStrip(times: _times, onMoment: (_) {})));
    expect(find.text('06:51'), findsOneWidget); // sunrise - 45 min
    expect(find.text('07:36'), findsOneWidget);
    expect(find.text('18:56'), findsOneWidget); // sunset - 45 min
    expect(find.text('19:11'), findsOneWidget); // sunset - 30 min
    expect(find.text('19:41'), findsOneWidget);
  });

  testWidgets('tap opens the sheet with the touched moment highlighted', (
    tester,
  ) async {
    var listened = 0;
    await tester.pumpWidget(
      _app(
        Builder(
          builder:
              (context) => DayStrip(
                times: _times,
                onMoment:
                    (m) => showDaySheet(
                      context,
                      times: _times,
                      caption: 'Mardi 29 septembre · Lieu',
                      highlighted: m,
                      onListen: () => listened++,
                    ),
              ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('day-pill-goldenHour')));
    await tester.pumpAndSettle();
    expect(find.text("Ta journée d'écoute"), findsOneWidget);
    expect(find.text('Mardi 29 septembre · Lieu'), findsOneWidget);
    // Highlighted: exactly one row with the 2 px accent border.
    final c = BirdyColors.light;
    final bordered = tester.widgetList<Container>(find.byType(Container)).where(
      (w) {
        final d = w.decoration;
        return d is BoxDecoration &&
            d.border is Border &&
            (d.border! as Border).top.color == c.accent;
      },
    );
    expect(bordered, hasLength(1));
    await tester.tap(find.byType(ListenButton));
    await tester.pumpAndSettle();
    expect(listened, 1);
    expect(find.text("Ta journée d'écoute"), findsNothing);
  });

  testWidgets('day sheet content: two blocks, five moments, one action', (
    tester,
  ) async {
    await size(tester, const Size(390, 1200));
    await tester.pumpWidget(
      _app(
        DaySheet(times: _times, caption: 'Mardi 29 septembre', onListen: () {}),
      ),
    );
    expect(find.text('Quand les oiseaux chantent'), findsOneWidget);
    expect(find.text('Le soleil'), findsOneWidget);
    expect(find.text('06:51 → 08:31'), findsOneWidget);
    expect(find.text('19:11 → 20:11'), findsOneWidget);
    expect(find.text('18:56 → 19:41'), findsOneWidget);
    expect(find.text('Lever du soleil'), findsOneWidget);
    expect(find.text('Coucher du soleil'), findsOneWidget);
    expect(find.text('Me le rappeler'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  test('greeting with and without a first name', () async {
    final fr = await AppLocalizations.delegate.load(const Locale('fr'));
    final morning = DateTime(2026, 9, 29, 8);
    expect(homeGreeting(fr, morning), 'Bonjour');
    expect(
      homeGreeting(fr, morning, firstName: 'Benjamin'),
      'Bonjour Benjamin',
    );
    expect(homeGreeting(fr, morning, firstName: ''), 'Bonjour');
  });
}
