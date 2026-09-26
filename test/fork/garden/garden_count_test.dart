import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/garden/garden_count.dart';
import 'package:birdnet_live/fork/garden/garden_count_screen.dart';
import 'package:birdnet_live/fork/garden/garden_summary.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  group('national weekends', () {
    test('last full weekend of January and May', () {
      // January 2026 ends on a Saturday: the 31st has no Sunday after it.
      expect(lastFullWeekendSaturday(2026, 1), DateTime(2026, 1, 24));
      expect(lastFullWeekendSaturday(2026, 5), DateTime(2026, 5, 30));
      // May 2027 ends on a Monday.
      expect(lastFullWeekendSaturday(2027, 5), DateTime(2027, 5, 29));
      expect(isNationalGardenWeekend(DateTime(2026, 1, 24, 10)), isTrue);
      expect(isNationalGardenWeekend(DateTime(2026, 1, 25, 10)), isTrue);
      expect(isNationalGardenWeekend(DateTime(2026, 1, 31, 10)), isFalse);
      expect(isNationalGardenWeekend(DateTime(2026, 5, 31, 10)), isTrue);
      expect(isNationalGardenWeekend(DateTime(2026, 9, 26, 10)), isFalse);
    });

    test('one hour on a national weekend, free otherwise', () {
      expect(
        GardenCount.startAt(DateTime(2026, 1, 24, 10)).planned,
        const Duration(hours: 1),
      );
      expect(GardenCount.startAt(DateTime(2026, 9, 26, 10)).planned, isNull);
    });
  });

  group('controller', () {
    test('counts by hand, keeps the count across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer container() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final first = container();
      final controller = first.read(gardenCountProvider.notifier);
      controller.start(DateTime(2026, 9, 26, 9));
      controller.addSpecies('Parus major');
      controller.addSpecies('Erithacus rubecula');
      controller.setCount('Parus major', 4);
      controller.setCount('Parus major', 3);
      controller.setCount('Erithacus rubecula', -2);
      first.dispose();

      final second = container();
      final count = second.read(gardenCountProvider)!;
      expect(count.counts, {'Parus major': 3, 'Erithacus rubecula': 0});
      expect(count.seen, {'Parus major': 3});
      expect(count.finished, isFalse);

      second
          .read(gardenCountProvider.notifier)
          .finish(DateTime(2026, 9, 26, 9, 42));
      expect(
        second.read(gardenCountProvider)!.elapsed(DateTime(2030)),
        const Duration(minutes: 42),
      );
      second.read(gardenCountProvider.notifier).clear();
      expect(second.read(gardenCountProvider), isNull);
      expect(prefs.getString(kGardenCountPref), isNull);
      second.dispose();
    });
  });

  test('summary to report on oiseauxdesjardins.fr', () {
    final count = GardenCount(
      start: DateTime(2026, 1, 24, 10, 5),
      planned: const Duration(hours: 1),
      counts: const {'Parus major': 4, 'Pica pica': 0, 'Turdus merula': 2},
      end: DateTime(2026, 1, 24, 11, 10),
    );
    expect(
      gardenSummaryLines(
        fr,
        count,
        names: (sci) => {'Parus major': 'Mésange charbonnière'}[sci] ?? sci,
        now: DateTime(2030),
      ),
      [
        'Oiseaux des jardins, comptage du 24/01/2026',
        'Début : 10:05, durée : 1 h 05',
        'Mésange charbonnière : 4',
        'Turdus merula : 2',
        '2 espèces, 6 oiseaux en tout',
      ],
    );
    expect(gardenDuration(fr, const Duration(minutes: 42)), '42 min');
  });

  test('sound detections only invite to look, once per species', () {
    final start = DateTime(2026, 9, 26, 9);
    expect(
      heardSince([
        (name: 'Turdus merula', time: start.add(const Duration(minutes: 5))),
        (name: 'Parus major', time: start.subtract(const Duration(minutes: 1))),
        (name: 'Turdus merula', time: start.add(const Duration(minutes: 2))),
        (name: 'Pica pica', time: start.add(const Duration(minutes: 1))),
      ], start),
      ['Turdus merula', 'Pica pica'],
    );
  });

  testWidgets('start, count and finish', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GardenCountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commencer le comptage'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune espèce'), findsOneWidget);

    await tester.tap(find.text('Ajouter une espèce'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parus major').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Un de plus'));
    await tester.pump();
    await tester.tap(find.byTooltip('Un de plus'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.ensureVisible(find.text('Terminer le comptage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer le comptage'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Parus major : 2'), findsOneWidget);
    expect(find.text('oiseauxdesjardins.fr'), findsOneWidget);

    await tester.tap(find.text('Nouveau comptage'));
    await tester.pumpAndSettle();
    expect(find.text('Commencer le comptage'), findsOneWidget);
  });
}
