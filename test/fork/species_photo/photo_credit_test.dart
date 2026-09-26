import 'package:birdnet_live/fork/species_photo/photo_credit.dart';
import 'package:birdnet_live/shared/models/taxonomy_species.dart';
import 'package:flutter_test/flutter_test.dart';

TaxonomySpecies _species({String? author, String? license, String? source}) =>
    TaxonomySpecies(
      scientificName: 'Erithacus rubecula',
      commonName: 'European Robin',
      imageAuthor: author,
      imageLicense: license,
      imageSource: source,
    );

void main() {
  group('PhotoLicense.parse', () {
    test('Creative Commons codes, with and without a version', () {
      final byNc = PhotoLicense.parse('cc-by-nc')!;
      expect(byNc.kind, PhotoLicenseKind.creativeCommons);
      expect(byNc.label, 'CC BY-NC');
      expect(byNc.url, 'https://creativecommons.org/licenses/by-nc/4.0/');

      final bySa3 = PhotoLicense.parse('CC BY-SA 3.0')!;
      expect(bySa3.label, 'CC BY-SA 3.0');
      expect(bySa3.url, 'https://creativecommons.org/licenses/by-sa/3.0/');

      expect(PhotoLicense.parse('cc-by-nc-nd')!.label, 'CC BY-NC-ND');
    });

    test('CC0, public domain and reserved photos', () {
      final cc0 = PhotoLicense.parse('cc0')!;
      expect(cc0.kind, PhotoLicenseKind.cc0);
      expect(cc0.label, 'CC0 1.0');
      expect(PhotoLicense.parse('pd')!.kind, PhotoLicenseKind.publicDomain);

      final reserved = PhotoLicense.parse('© Macaulay Library')!;
      expect(reserved.kind, PhotoLicenseKind.reserved);
      expect(reserved.url, isNull);
      expect(
        PhotoLicense.parse('All rights reserved')!.kind,
        PhotoLicenseKind.reserved,
      );
    });

    test('unknown text is kept as is, blanks give nothing', () {
      final other = PhotoLicense.parse('GFDL')!;
      expect(other.kind, PhotoLicenseKind.other);
      expect(other.label, 'GFDL');
      expect(PhotoLicense.parse('  '), isNull);
      expect(PhotoLicense.parse(null), isNull);
    });
  });

  group('PhotoCredit.fromSpecies', () {
    test('a Macaulay Library photo links to its asset page', () {
      final credit = PhotoCredit.fromSpecies(
        _species(
          author: 'Ryan Schain',
          license: '© Macaulay Library',
          source: 'Macaulay Library ML44599871',
        ),
      );
      expect(credit.author, 'Ryan Schain');
      expect(credit.source, 'Macaulay Library ML44599871');
      expect(credit.pageUrl, 'https://macaulaylibrary.org/asset/44599871');
      expect(credit.parsedLicense!.kind, PhotoLicenseKind.reserved);
    });

    test('a photo replaced by the bundle script links to iNaturalist', () {
      final credit = PhotoCredit.fromSpecies(
        _species(author: 'Ann', license: 'cc-by-sa', source: 'iNaturalist 99'),
      );
      expect(credit.source, 'iNaturalist');
      expect(credit.pageUrl, 'https://www.inaturalist.org/photos/99');
    });

    test('an upstream iNaturalist photo has no page, blanks are dropped', () {
      final credit = PhotoCredit.fromSpecies(
        _species(author: ' ', license: '', source: 'iNaturalist'),
      );
      expect(credit.author, isNull);
      expect(credit.license, isNull);
      expect(credit.source, 'iNaturalist');
      expect(credit.pageUrl, isNull);
      expect(credit.isEmpty, isFalse);
      expect(PhotoCredit.fromSpecies(_species()).isEmpty, isTrue);
    });
  });

  test('toJson and fromJson round trip', () {
    const credit = PhotoCredit(
      author: 'Ann',
      license: 'cc-by',
      source: 'iNaturalist',
      pageUrl: 'https://www.inaturalist.org/photos/1',
    );
    final back = PhotoCredit.fromJson(credit.toJson());
    expect(back.toJson(), credit.toJson());
  });
}
