import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/bilan/bilan_model.dart';
import 'package:birdnet_live/fork/bilan/bilan_text.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'bilan_fixture.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  BilanSummary morning() => buildBilan(
    session: morningSession(),
    presence: morningPresence(),
    heardBefore: heardBeforeMorning(),
  );

  test('title and date line in French', () {
    final bilan = morning();
    expect(bilanTitle(fr, bilan), 'Belle matinée !');
    expect(
      bilanDateLine(fr, 'fr', bilan, place: 'Beaulieu-sur-Brenne'),
      'Samedi 26 septembre · 7 h 12 – 7 h 54 · Beaulieu-sur-Brenne',
    );
    expect(
      bilanDateLine(fr, 'fr', bilan),
      'Samedi 26 septembre · 7 h 12 – 7 h 54',
    );
  });

  test('title and date line in English', () {
    final bilan = morning();
    expect(bilanTitle(en, bilan), 'Lovely morning!');
    expect(
      bilanDateLine(en, 'en', bilan),
      'Saturday 26 September · 7:12 – 7:54',
    );
  });

  test('a session saved in UTC shows local day and times', () {
    // Just after midnight: in UTC it is still Friday east of Greenwich.
    final json =
        morningSession().toJson()
          ..['startTime'] = at(0, 30).toUtc().toIso8601String()
          ..['endTime'] = at(1, 0).toUtc().toIso8601String();
    final bilan = buildBilan(session: LiveSession.fromJson(json));
    expect(bilan.start.isUtc, isTrue);
    expect(
      bilanDateLine(fr, 'fr', bilan),
      'Samedi 26 septembre · 0 h 30 – 1 h 00',
    );
  });

  test('an empty outing has its own title', () {
    final session = morningSession()..detections.clear();
    expect(
      bilanTitle(fr, buildBilan(session: session)),
      "Pas d'oiseau cette fois",
    );
  });

  test('durations', () {
    expect(bilanDuration(fr, const Duration(minutes: 42)), '42 min');
    expect(bilanDuration(fr, const Duration(seconds: 20)), '1 min');
    expect(bilanDuration(fr, Duration.zero), '0 min');
    expect(bilanDuration(fr, const Duration(minutes: 65)), '1 h 05');
  });

  test('novelty heading', () {
    expect(bilanNoveltyHeading(fr, morning()), 'Une nouvelle, peut-être deux');
    expect(bilanNoveltyHeading(en, morning()), 'One new, maybe two');

    final onlySure = buildBilan(
      session: morningSession(),
      presence: morningPresence(),
      heardBefore: heardBeforeMorning()..add(hoopoe),
    );
    expect(bilanNoveltyHeading(fr, onlySure), 'Une nouvelle espèce');

    final onlyMaybe = buildBilan(
      session: morningSession(),
      presence: morningPresence(),
      heardBefore: heardBeforeMorning()..add(woodpecker),
    );
    expect(bilanNoveltyHeading(fr, onlyMaybe), 'Peut-être une nouvelle espèce');

    final none = buildBilan(
      session: morningSession(),
      presence: morningPresence(),
      heardBefore: heardBeforeMorning()..addAll([woodpecker, hoopoe]),
    );
    expect(bilanNoveltyHeading(fr, none), isNull);
  });

  test('shared summary', () {
    final text = bilanShareText(
      fr,
      'fr',
      morning(),
      place: 'Beaulieu-sur-Brenne',
    );
    final lines = text.split('\n');
    expect(lines.take(3), [
      'Belle matinée !',
      'Samedi 26 septembre · 7 h 12 – 7 h 54 · Beaulieu-sur-Brenne',
      '13 espèces · 52 contacts · 42 min',
    ]);
    expect(lines, contains('Rougegorge familier ×9'));
    expect(lines, contains('Huppe fasciée ×1 (à vérifier)'));
    expect(lines.last, 'Entendu avec BirdyGo');
  });

  test('the place is not shared with a sensitive species', () {
    final session = morningSession();
    session.detections.add(
      DetectionRecord(
        scientificName: 'Bubo bubo',
        commonName: 'Grand-duc d’Europe',
        confidence: 0.9,
        timestamp: at(7, 40),
      ),
    );
    final text = bilanShareText(
      fr,
      'fr',
      buildBilan(session: session),
      place: 'Beaulieu-sur-Brenne',
    );
    expect(text, isNot(contains('Beaulieu')));
  });
}
