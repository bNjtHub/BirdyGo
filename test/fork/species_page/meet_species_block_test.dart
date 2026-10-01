/// « Fais sa connaissance » (J6h, J7 order): Suivant/Revoir, read checks,
/// hidden sections, and the sections that moved out of the discs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/species_page/meet_species_block.dart';
import 'package:birdnet_live/fork/species_sheet/species_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, SpeciesSheet sheet) async {
  tester.view.physicalSize = const Size(1170, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: MeetSpeciesBlock(sheet: sheet)),
      ),
    ),
  );
}

const _all = SpeciesSheet(
  name: 'Merle noir',
  sections: {
    SheetSection.summary: 'Un chanteur du soir.',
    SheetSection.byEar: 'Phrases flûtées.',
    SheetSection.size: 'Vingt-cinq centimètres.',
    SheetSection.behaviour: 'Fouille le sol.',
    SheetSection.migration: 'Reste toute l\'année.',
    SheetSection.anecdote: 'Il chante dès la fin de l\'hiver.',
  },
);

const _sixSheet = SpeciesSheet(
  name: 'Merle noir',
  sections: {
    SheetSection.size: 'Vingt-cinq centimètres.',
    SheetSection.behaviour: 'Fouille le sol.',
    SheetSection.whyHere: 'Il aime les jardins.',
    SheetSection.enemies: 'Le chat.',
    SheetSection.confusions: 'Le merle à plastron.',
    SheetSection.anecdote: 'Il chante.',
  },
);

void main() {
  testWidgets('starts on the first section, 1/3 discovered', (tester) async {
    await _pump(tester, _all);
    expect(find.text('Sa taille'), findsOneWidget);
    expect(find.text('Vingt-cinq centimètres.'), findsOneWidget);
    expect(find.text('1/3 découverts'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
  });

  testWidgets('Suivant walks the sections, then becomes Revoir', (
    tester,
  ) async {
    await _pump(tester, _all);
    for (final hook in ['Ce qu\'il fait', 'Le savais-tu ?']) {
      await tester.tap(find.byKey(const ValueKey('meet-next')));
      await tester.pumpAndSettle();
      expect(find.text(hook), findsOneWidget);
    }
    expect(find.text('Revoir'), findsOneWidget);
    expect(find.text('Suivant'), findsNothing);
    expect(find.text('3/3 découverts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meet-next')));
    await tester.pumpAndSettle();
    expect(find.text('Sa taille'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
  });

  testWidgets('a read section gets a check, the current one is counted', (
    tester,
  ) async {
    await _pump(tester, _all);
    expect(find.byKey(const ValueKey('meet-read-anecdote')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meet-disc-anecdote')));
    await tester.pumpAndSettle();
    expect(find.text('Le savais-tu ?'), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-read-size')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-read-anecdote')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-read-behaviour')), findsNothing);
    expect(find.text('2/3 découverts'), findsOneWidget);
  });

  testWidgets('sections without content are hidden, count is N/available', (
    tester,
  ) async {
    await _pump(
      tester,
      const SpeciesSheet(
        name: 'x',
        sections: {
          SheetSection.size: 'A.',
          SheetSection.anecdote: 'B.',
          SheetSection.byEar: 'Not one of the discs.',
        },
      ),
    );
    expect(find.byKey(const ValueKey('meet-disc-size')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-disc-anecdote')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-disc-behaviour')), findsNothing);
    expect(find.text('1/2 découverts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meet-next')));
    await tester.pumpAndSettle();
    expect(find.text('Revoir'), findsOneWidget);
  });

  testWidgets('no quiz link, no summary, no by-ear or migration disc (J7)', (
    tester,
  ) async {
    await _pump(tester, _all);
    expect(find.text('Qui chante ?'), findsNothing);
    expect(find.textContaining('Teste ton oreille'), findsNothing);
    expect(find.text('Un chanteur du soir.'), findsNothing);
    expect(find.byKey(const ValueKey('meet-disc-by_ear')), findsNothing);
    expect(find.byKey(const ValueKey('meet-disc-migration')), findsNothing);
    expect(find.text('Phrases flûtées.'), findsNothing);
    expect(find.text('Reste toute l\'année.'), findsNothing);
    expect(meetAvailable(_all), [
      SheetSection.size,
      SheetSection.behaviour,
      SheetSection.anecdote,
    ]);
  });

  testWidgets('one section left: a plain tonal block, no disc grid', (
    tester,
  ) async {
    await _pump(
      tester,
      const SpeciesSheet(
        name: 'x',
        sections: {
          SheetSection.byEar: 'Phrases flûtées.',
          SheetSection.size: 'Vingt-cinq centimètres.',
        },
      ),
    );
    expect(find.byKey(const ValueKey('meet-plain-size')), findsOneWidget);
    expect(find.text('Vingt-cinq centimètres.'), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-disc-size')), findsNothing);
    expect(find.byKey(const ValueKey('meet-next')), findsNothing);
    expect(find.textContaining('découverts'), findsNothing);
    expect(find.text('Phrases flûtées.'), findsNothing);
  });

  testWidgets('two sections: the grid stays, with two discs', (tester) async {
    await _pump(
      tester,
      const SpeciesSheet(
        name: 'x',
        sections: {SheetSection.size: 'A.', SheetSection.enemies: 'B.'},
      ),
    );
    expect(find.byKey(const ValueKey('meet-disc-size')), findsOneWidget);
    expect(find.byKey(const ValueKey('meet-disc-enemies')), findsOneWidget);
    expect(find.text('1/2 découverts'), findsOneWidget);
  });

  test('meetHasContent: discs only', () {
    expect(meetHasContent(_all), isTrue);
    expect(
      meetHasContent(
        const SpeciesSheet(
          name: 'x',
          sections: {
            SheetSection.summary: 'S.',
            SheetSection.byEar: 'E.',
            SheetSection.migration: 'M.',
          },
        ),
      ),
      isFalse,
    );
    expect(
      meetHasContent(
        const SpeciesSheet(name: 'x', sections: {SheetSection.whyHere: 'W.'}),
      ),
      isTrue,
    );
  });

  group('six sections (J7 7-block page)', () {
    const six = SpeciesSheet(
      name: 'Merle noir',
      sections: {
        SheetSection.size: 'Vingt-cinq centimètres.',
        SheetSection.behaviour: 'Fouille le sol.',
        SheetSection.whyHere: 'Il aime les jardins.',
        SheetSection.enemies: 'Le chat.',
        SheetSection.confusions: 'Le merle à plastron.',
        SheetSection.anecdote: 'Il chante.',
      },
    );

    testWidgets('six discs in a 3 x 2 grid, no extra blocks', (tester) async {
      await _pump(tester, six);
      expect(meetAvailable(six), kMeetSections);
      for (final s in kMeetSections) {
        expect(find.byKey(ValueKey('meet-disc-${s.key}')), findsOneWidget);
      }
      expect(find.text('1/6 découverts'), findsOneWidget);
      expect(find.byKey(const ValueKey('meet-extra-why_here')), findsNothing);
      // Two rows of three: size, behaviour, whyHere then enemies...
      final top = tester.getTopLeft(find.byKey(const ValueKey('meet-disc-size')));
      final third = tester.getTopLeft(
        find.byKey(const ValueKey('meet-disc-why_here')),
      );
      final fourth = tester.getTopLeft(
        find.byKey(const ValueKey('meet-disc-enemies')),
      );
      expect(third.dy, top.dy);
      expect(fourth.dy, greaterThan(top.dy));
    });

    testWidgets('whyHere and confusions: label, hook, text, icon, tone', (
      tester,
    ) async {
      await _pump(tester, six);
      final c = BirdyColors.of(
        tester.element(find.byKey(const ValueKey('meet-disc-why_here'))),
      );
      Icon discIcon(String key) => tester.widget<Icon>(
        find.descendant(
          of: find.byKey(ValueKey('meet-disc-$key')),
          matching: find.byType(Icon),
        ),
      );
      expect(discIcon('why_here').icon, AppIcons.locationOn);
      expect(discIcon('why_here').color, c.accentText);
      expect(discIcon('confusions').icon, AppIcons.swapHoriz);
      expect(discIcon('confusions').color, c.probable.foreground);
      expect(find.text('Pourquoi ici'), findsOneWidget);
      expect(find.text('Confusions'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meet-disc-why_here')));
      await tester.pumpAndSettle();
      expect(find.text('Pourquoi il est ici'), findsOneWidget);
      expect(find.text('Il aime les jardins.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meet-disc-confusions')));
      await tester.pumpAndSettle();
      expect(find.text('Ne le confonds pas'), findsOneWidget);
      expect(find.text('Le merle à plastron.'), findsOneWidget);
    });
  });

  group('four sections (Ennemis)', () {
    const four = SpeciesSheet(
      name: 'Merle noir',
      sections: {
        SheetSection.byEar: 'Phrases flûtées.',
        SheetSection.size: 'Vingt-cinq centimètres.',
        SheetSection.behaviour: 'Fouille le sol.',
        SheetSection.migration: 'Reste toute l\'année.',
        SheetSection.enemies: 'L\'épervier et le chat.',
        SheetSection.anecdote: 'Il chante dès la fin de l\'hiver.',
      },
    );
    const keys = ['size', 'behaviour', 'enemies', 'anecdote'];

    test('order of the four sections', () {
      expect(meetAvailable(four), [
        SheetSection.size,
        SheetSection.behaviour,
        SheetSection.enemies,
        SheetSection.anecdote,
      ]);
    });

    testWidgets('four discs, Habitudes label, counter 1/4', (tester) async {
      await _pump(tester, four);
      for (final k in keys) {
        expect(find.byKey(ValueKey('meet-disc-$k')), findsOneWidget);
      }
      expect(find.text('Habitudes'), findsOneWidget);
      expect(find.text('Comportement'), findsNothing);
      expect(find.text('Ennemis'), findsOneWidget);
      expect(find.text('1/4 découverts'), findsOneWidget);
    });

    testWidgets('Ennemis shows its kicker and text', (tester) async {
      await _pump(tester, four);
      await tester.tap(find.byKey(const ValueKey('meet-disc-enemies')));
      await tester.pumpAndSettle();
      expect(find.text('Qui le chasse'), findsOneWidget);
      expect(find.text('L\'épervier et le chat.'), findsOneWidget);
      expect(find.text('2/4 découverts'), findsOneWidget);
    });

    testWidgets('Ennemis is hidden without text, counter is n/3', (
      tester,
    ) async {
      await _pump(tester, _all);
      expect(find.byKey(const ValueKey('meet-disc-enemies')), findsNothing);
      expect(find.text('1/3 découverts'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('labels never overflow at 320 dp, text x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(960, 3000);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: Scaffold(
              body: SingleChildScrollView(child: MeetSpeciesBlock(sheet: four)),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final k in keys) {
          final disc = tester.getRect(find.byKey(ValueKey('meet-disc-$k')));
          final label = tester.getRect(
            find.descendant(
              of: find.byKey(ValueKey('meet-disc-$k')),
              matching: find.byType(Text),
            ),
          );
          expect(label.left, greaterThanOrEqualTo(disc.left - 0.5));
          expect(label.right, lessThanOrEqualTo(disc.right + 0.5));
        }
      });
    }
  });
  group('bundled Ennemis section', () {
    late SpeciesSheets sheets;

    setUpAll(() {
      sheets = SpeciesSheets.fromGzip(
        File(speciesSheetsAsset).readAsBytesSync(),
      );
    });

    test('at least 80 bundled sheets have a non-empty Ennemis text', () {
      final json =
          jsonDecode(
                utf8.decode(
                  gzip.decode(File(speciesSheetsAsset).readAsBytesSync()),
                ),
              )
              as Map<String, dynamic>;
      var count = 0;
      for (final key in (json['species'] as Map<String, dynamic>).keys) {
        final text = sheets[key]!.sections[SheetSection.enemies];
        if (text != null && text.trim().isNotEmpty) count++;
      }
      expect(count, greaterThanOrEqualTo(80));
    });

    testWidgets('shows every section of a full sheet', (tester) async {
      final sheet = sheets['Accipiter nisus']!;
      expect(meetAvailable(sheet), kMeetSections);
      await _pump(tester, sheet);
      expect(find.text('1/6 découverts'), findsOneWidget);
    });
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x$scale (J7)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: MeetSpeciesBlock(sheet: _sixSheet),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('découverts'), findsOneWidget);
      });
    }
  }
}
