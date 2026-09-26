import 'dart:async';
import 'dart:io';

import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/photos/photo_credit.dart';
import 'package:birdnet_live/fork/photos/photo_manifest.dart';
import 'package:birdnet_live/fork/photos/species_photo.dart';
import 'package:birdnet_live/fork/photos/species_photo_cache.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _species = 'Erithacus rubecula';
const _asset = 'assets/species_images/dummy.webp';

Map<String, Object?> _entry({bool credit = true, bool large = true}) => {
  // dummy.webp is the only species image in the cloud checkout.
  'birdnet_id': 'dummy',
  if (large) 'photo_id': '42',
  if (large) 'large_url': 'https://example.org/photos/42/large.jpg',
  if (credit) 'author': 'Jane Doe',
  if (credit) 'license': 'cc-by-nc',
  if (credit) 'source': 'iNaturalist',
  if (credit) 'page_url': 'https://www.inaturalist.org/photos/42',
  'cropped': true,
};

class _FakeCache extends SpeciesPhotoCache {
  _FakeCache(this.answer)
    : super(
        directory: () async => Directory.systemTemp,
        client: MockClient((_) async => http.Response('', 404)),
      );

  final Future<File?> Function() answer;
  final List<String> requests = [];

  @override
  Future<File?> file(String key, Uri url) {
    requests.add(key);
    return answer();
  }
}

Widget _app(
  Widget child, {
  required _FakeCache cache,
  Map<String, Object?>? entry,
  bool bundled = true,
}) => ProviderScope(
  overrides: [
    speciesPhotoCacheProvider.overrideWithValue(cache),
    bundledSpeciesImagesProvider.overrideWith(
      (ref) async => bundled ? {_asset} : const <String>{},
    ),
    speciesPhotoManifestProvider.overrideWith(
      (ref) async => SpeciesPhotoManifest.fromJson({
        'species': {if (entry != null) _species: entry},
      }),
    ),
    taxonomyServiceProvider.overrideWith((ref) async => TaxonomyService()),
  ],
  child: MaterialApp(
    theme: BirdyTheme.light(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

Widget _column(Widget photo) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [SizedBox(width: 300, child: photo), const Text('below')],
);

Finder _largeImage() => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      (w.image is FileImage ||
          (w.image is ResizeImage &&
              (w.image as ResizeImage).imageProvider is FileImage)),
);

Finder _bundledImage() =>
    find.byWidgetPredicate((w) => w is Image && w.image is AssetImage);

void main() {
  late File largeFile;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('species_photo_test');
    largeFile = File('${dir.path}/42.img')..writeAsBytesSync([1, 2, 3]);
  });

  testWidgets('the large photo does not move the layout', (tester) async {
    final answer = Completer<File?>();
    final cache = _FakeCache(() => answer.future);
    await tester.pumpWidget(
      _app(
        _column(const SpeciesPhoto(scientificName: _species)),
        cache: cache,
        entry: _entry(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final frame = tester.getSize(find.byType(SpeciesPhoto));
    final below = tester.getTopLeft(find.text('below'));
    expect(frame, const Size(300, 200));
    expect(_bundledImage(), findsOneWidget);
    expect(_largeImage(), findsNothing);
    expect(cache.requests, ['42']);

    answer.complete(largeFile);
    await tester.pump(); // the cache answers
    await tester.pump(); // the large layer is built

    expect(_largeImage(), findsOneWidget);
    expect(_bundledImage(), findsOneWidget, reason: 'stays under the fade');
    expect(tester.getSize(find.byType(SpeciesPhoto)), frame);
    expect(tester.getTopLeft(find.text('below')), below);
    final large = tester.widget<Image>(_largeImage());
    expect(large.frameBuilder, photoFadeIn);
    expect(large.fit, BoxFit.cover);
    expect(tester.widget<Image>(_bundledImage()).fit, BoxFit.cover);
  });

  testWidgets('offline, the bundled photo stays', (tester) async {
    final cache = _FakeCache(() async => null);
    await tester.pumpWidget(
      _app(
        const SpeciesPhoto(scientificName: _species),
        cache: cache,
        entry: _entry(),
      ),
    );
    await tester.pumpAndSettle();
    expect(cache.requests, ['42']);
    expect(_bundledImage(), findsOneWidget);
    expect(_largeImage(), findsNothing);
  });

  testWidgets('lists keep the bundled photo', (tester) async {
    final cache = _FakeCache(() async => largeFile);
    await tester.pumpWidget(
      _app(
        const SpeciesPhoto(scientificName: _species, loadLarge: false),
        cache: cache,
        entry: _entry(),
      ),
    );
    await tester.pumpAndSettle();
    expect(cache.requests, isEmpty);
    expect(_largeImage(), findsNothing);
  });

  testWidgets('without photo, a silhouette', (tester) async {
    final cache = _FakeCache(() async => largeFile);
    await tester.pumpWidget(
      _app(
        _column(const SpeciesPhoto(scientificName: _species)),
        cache: cache,
        entry: _entry(),
        bundled: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.bird), findsOneWidget);
    expect(_bundledImage(), findsNothing);
    expect(cache.requests, isEmpty);
    expect(tester.getSize(find.byType(SpeciesPhoto)), const Size(300, 200));
    expect(
      find.bySemanticsLabel('Crédit et licence de la photo'),
      findsNothing,
    );
  });

  testWidgets('a tap shows credit and licence', (tester) async {
    await tester.pumpWidget(
      _app(
        _column(const SpeciesPhoto(scientificName: _species)),
        cache: _FakeCache(() async => null),
        entry: _entry(),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.bySemanticsLabel('Crédit et licence de la photo');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(48));

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCreditSheet), findsOneWidget);
    expect(find.text('Crédit photo'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Auteur'), findsOneWidget);
    expect(find.text('CC BY-NC'), findsOneWidget);
    expect(find.text('Licence'), findsOneWidget);
    expect(find.text('iNaturalist'), findsOneWidget);
    expect(find.text("Recadrée et redimensionnée pour l'app."), findsOneWidget);
    expect(find.byIcon(AppIcons.openInNew), findsNWidgets(2));

    // The whole photo opens it too.
    Navigator.of(tester.element(find.byType(PhotoCreditSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(SpeciesPhoto)) + const Offset(40, 40),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCreditSheet), findsOneWidget);
  });

  testWidgets('no credit button without credit', (tester) async {
    await tester.pumpWidget(
      _app(
        const SpeciesPhoto(scientificName: _species),
        cache: _FakeCache(() async => null),
        entry: _entry(credit: false, large: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(_bundledImage(), findsOneWidget);
    expect(
      find.bySemanticsLabel('Crédit et licence de la photo'),
      findsNothing,
    );
  });

  testWidgets('credit line under the photo', (tester) async {
    await tester.pumpWidget(
      _app(
        const PhotoCreditLine(scientificName: _species),
        cache: _FakeCache(() async => null),
        entry: _entry(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Photo : Jane Doe · CC BY-NC'), findsOneWidget);
    await tester.tap(find.text('Photo : Jane Doe · CC BY-NC'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCreditSheet), findsOneWidget);
  });

  testWidgets('photoFadeIn fades from 0 to 1', (tester) async {
    const child = SizedBox(key: Key('photo'));
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    final waiting = photoFadeIn(context, child, null, false) as AnimatedOpacity;
    expect(waiting.opacity, 0);
    expect(waiting.duration, BirdyMotion.enter);
    expect(waiting.curve, BirdyMotion.standard);
    final shown = photoFadeIn(context, child, 0, false) as AnimatedOpacity;
    expect(shown.opacity, 1);
    expect(photoFadeIn(context, child, 0, true), same(child));
  });
}
