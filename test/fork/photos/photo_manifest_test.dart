import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/fork/photos/photo_credit.dart';
import 'package:birdnet_live/fork/photos/photo_license.dart';
import 'package:birdnet_live/fork/photos/photo_manifest.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _robin = {
  'birdnet_id': 'BN05247',
  'photo_id': '42',
  'large_url':
      'https://inaturalist-open-data.s3.amazonaws.com/photos/42/large.jpg',
  'author': 'Jane Doe',
  'license': 'cc-by-nc',
  'source': 'iNaturalist',
  'page_url': 'https://www.inaturalist.org/photos/42',
  'cropped': true,
};

const _taxonomyCsv =
    'birdnet_id,scientific_name,common_name,image_author,image_license,'
    'image_source\n'
    'BN05247,Erithacus rubecula,European Robin,Ryan,© Macaulay Library,'
    'Macaulay Library\n'
    'BN1,Turdus merula,Eurasian Blackbird,Ann,cc-by,iNaturalist\n'
    'BN2,Pica pica,Eurasian Magpie,,,\n';

void main() {
  group('PhotoLicense', () {
    test('iNaturalist codes link to the 4.0 deed', () {
      expect(
        PhotoLicense.parse('cc-by-nc'),
        const PhotoLicense(
          label: 'CC BY-NC',
          url: 'https://creativecommons.org/licenses/by-nc/4.0/',
        ),
      );
      expect(PhotoLicense.parse('cc-by-nc-sa')!.label, 'CC BY-NC-SA');
      expect(PhotoLicense.parse('cc-by')!.url, contains('/licenses/by/4.0/'));
    });

    test('versioned texts keep their version', () {
      final license = PhotoLicense.parse('CC BY-SA 3.0')!;
      expect(license.label, 'CC BY-SA 3.0');
      expect(license.url, 'https://creativecommons.org/licenses/by-sa/3.0/');
    });

    test('CC0 links to the public domain dedication', () {
      for (final raw in ['cc0', 'CC0 1.0']) {
        final license = PhotoLicense.parse(raw)!;
        expect(license.label, 'CC0');
        expect(license.url, contains('publicdomain/zero/1.0'));
      }
    });

    test('other texts are kept, without link', () {
      expect(
        PhotoLicense.parse('© Macaulay Library'),
        const PhotoLicense(label: '© Macaulay Library'),
      );
      expect(PhotoLicense.parse(''), isNull);
      expect(PhotoLicense.parse(null), isNull);
    });
  });

  group('SpeciesPhotoManifest', () {
    test('reads an entry', () {
      final manifest = SpeciesPhotoManifest.fromJson({
        'version': 1,
        'species': {'Erithacus rubecula': _robin},
      });
      final info = manifest['Erithacus rubecula']!;
      expect(info.assetPath, 'assets/species_images/BN05247.webp');
      expect(info.photoId, '42');
      expect(info.largeUrl!.path, '/photos/42/large.jpg');
      expect(info.hasLarge, isTrue);
      expect(info.author, 'Jane Doe');
      expect(info.license!.label, 'CC BY-NC');
      expect(info.cropped, isTrue);
      expect(photoCreditText(info), 'Jane Doe · CC BY-NC');
    });

    test('skips unusable entries and refuses plain http', () {
      final manifest = SpeciesPhotoManifest.fromJson({
        'species': {
          'No id': {'author': 'X'},
          'Not a map': 'oops',
          'Http': {
            ...{'birdnet_id': 'BN3', 'photo_id': '3'},
            'large_url': 'http://example.org/large.jpg',
          },
        },
      });
      expect(manifest.length, 1);
      expect(manifest['Http']!.largeUrl, isNull);
      expect(manifest['Http']!.hasLarge, isFalse);
    });

    test('a broken manifest is empty', () {
      expect(SpeciesPhotoManifest.fromJson({'species': []}).length, 0);
      expect(SpeciesPhotoManifest.fromJson({}).length, 0);
    });
  });

  group('speciesPhotoProvider', () {
    ProviderContainer container({
      required Set<String> bundled,
      Map<String, Object?> manifest = const {},
    }) {
      final taxonomy = TaxonomyService()..loadFromCsv(_taxonomyCsv);
      final c = ProviderContainer(
        overrides: [
          bundledSpeciesImagesProvider.overrideWith((ref) async => bundled),
          speciesPhotoManifestProvider.overrideWith(
            (ref) async => SpeciesPhotoManifest.fromJson({'species': manifest}),
          ),
          taxonomyServiceProvider.overrideWith((ref) async => taxonomy),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('the manifest wins over the taxonomy credit', () async {
      final c = container(
        bundled: {'assets/species_images/BN05247.webp'},
        manifest: {'Erithacus rubecula': _robin},
      );
      final info = await c.read(
        speciesPhotoProvider('Erithacus rubecula').future,
      );
      expect(info!.author, 'Jane Doe');
      expect(info.source, 'iNaturalist');
    });

    test('falls back to the BirdNET photo and its taxonomy credit', () async {
      final c = container(bundled: {'assets/species_images/BN1.webp'});
      final info = await c.read(speciesPhotoProvider('Turdus merula').future);
      expect(info!.assetPath, 'assets/species_images/BN1.webp');
      expect(info.author, 'Ann');
      expect(info.license!.label, 'CC BY');
      expect(info.hasLarge, isFalse);
      expect(info.cropped, isFalse);
    });

    test('null when the image is not bundled', () async {
      final c = container(
        bundled: {'assets/species_images/dummy.webp'},
        manifest: {'Erithacus rubecula': _robin},
      );
      expect(
        await c.read(speciesPhotoProvider('Erithacus rubecula').future),
        isNull,
      );
      expect(await c.read(speciesPhotoProvider('Pica pica').future), isNull);
      expect(await c.read(speciesPhotoProvider('Unknown').future), isNull);
    });
  });

  group('bundled assets', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('lists the species images of the asset bundle', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final images = await c.read(bundledSpeciesImagesProvider.future);
      expect(images, contains('assets/species_images/dummy.webp'));
      expect(
        images.every((p) => p.startsWith('assets/species_images/')),
        isTrue,
      );
    });

    test('loading the manifest never fails, generated or not', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await expectLater(
        c.read(speciesPhotoManifestProvider.future),
        completion(isA<SpeciesPhotoManifest>()),
      );
    });
  });
}
