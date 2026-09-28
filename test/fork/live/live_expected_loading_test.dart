/// Loading skeleton of « Attendus ici » (J6f skeletons): while the
/// geo-model/position have not resolved yet, [ReliabilityConfig
/// .liveExpectedCount] skeleton rows stand in, at the real row height, so
/// the tip below does not move once the real species (the common case)
/// land. Without a geo-model/position at all, the final state is the
/// title and the tip only — rows may then go, this is the one case
/// allowed to shift.
library;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/live/live_expected.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// The default test font is a rough substitute with different metrics: the
/// rect assertions below compare wrapped-or-not text, so they need the real
/// bundled fonts loaded.
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

/// 7 a.m. in September: « ce matin », « septembre ».
final _morning = DateTime(2026, 9, 28, 7);

/// The common case the skeleton targets: short one-word names, the
/// shortest reason (no month, so no locale-dependent length), no goal
/// pill. A long two-word name, a wrapping reason or a goal pill are all
/// real but less common, and are covered by the general appearance
/// tests in live_expected_test.dart instead of the loading ones here.
const _five = [
  LiveExpectedSpecies(
    scientificName: 'Erithacus rubecula',
    commonName: 'Rougegorge',
    reason: LiveExpectedReason.peak,
  ),
  LiveExpectedSpecies(
    scientificName: 'Turdus merula',
    commonName: 'Merle',
    reason: LiveExpectedReason.peak,
  ),
  LiveExpectedSpecies(
    scientificName: 'Parus major',
    commonName: 'Mésange',
    reason: LiveExpectedReason.peak,
  ),
  LiveExpectedSpecies(
    scientificName: 'Troglodytes troglodytes',
    commonName: 'Troglodyte',
    reason: LiveExpectedReason.peak,
  ),
  LiveExpectedSpecies(
    scientificName: 'Cyanistes caeruleus',
    commonName: 'Cyanistes',
    reason: LiveExpectedReason.peak,
  ),
];

Widget _app(
  Widget child, {
  bool dark = true,
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: dark ? BirdyTheme.dark() : BirdyTheme.light(),
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

/// Rects of every element the loading skeleton must reserve exactly: they
/// must be identical before and after the data lands.
class _Snapshot {
  _Snapshot(WidgetTester tester)
    : rows = [
        for (var i = 0; i < ReliabilityConfig.liveExpectedCount; i++)
          tester.getRect(find.byKey(ValueKey('expected-row-$i'))),
      ],
      tip = tester.getRect(find.byType(LiveExpectedTip));

  final List<Rect> rows;
  final Rect tip;

  void expectUnchanged(_Snapshot other) {
    for (var i = 0; i < rows.length; i++) {
      expect(other.rows[i], rows[i], reason: 'row $i');
    }
    expect(other.tip, tip, reason: 'tip');
  }
}

void main() {
  setUpAll(_loadRealFonts);

  Future<void> pumpLoading(
    WidgetTester tester, {
    bool dark = true,
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        LiveExpectedView(
          now: _morning,
          species: [],
          loading: true,
        ),
        dark: dark,
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    );
    // Entrance (BirdyEntrance.staggered) is a fixed-duration animation,
    // no pending future: it settles on its own.
    await tester.pumpAndSettle();
  }

  testWidgets(
    'light, 100 %: the 5 expected species land without moving the tip',
    (tester) async {
      await pumpLoading(tester, dark: false);
      final loading = _Snapshot(tester);

      await tester.pumpWidget(
        _app(LiveExpectedView(now: _morning, species: _five)),
      );
      await tester.pumpAndSettle();
      loading.expectUnchanged(_Snapshot(tester));

      expect(find.text('Rougegorge'), findsOneWidget);
    },
  );

  testWidgets(
    'dark, 130 %: the 5 expected species land without moving the tip',
    (tester) async {
      await pumpLoading(tester, textScale: 1.3);
      final loading = _Snapshot(tester);

      await tester.pumpWidget(
        _app(
          LiveExpectedView(now: _morning, species: _five),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      loading.expectUnchanged(_Snapshot(tester));
    },
  );

  testWidgets('reduced motion: nothing animates while loading', (
    tester,
  ) async {
    await pumpLoading(tester, reduceMotion: true);
    final before = tester.getRect(find.byType(LiveExpectedTip));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(find.byType(LiveExpectedTip)), before);
    }
  });

  testWidgets(
    'without a geo-model/position: title and tip only, no rows reserved',
    (tester) async {
      await tester.pumpWidget(
        _app(LiveExpectedView(now: _morning, species: [])),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('expected-row-0')), findsNothing);
      expect(find.byType(LiveExpectedTip), findsOneWidget);
    },
  );
}
