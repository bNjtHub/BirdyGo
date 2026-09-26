/// Credit and license of a species photo (fork/PLAN.md J6b).
library;

import '../../shared/models/taxonomy_species.dart';
import 'species_photo_config.dart';

/// What a license lets people do, as far as the credit sheet cares.
enum PhotoLicenseKind { creativeCommons, cc0, publicDomain, reserved, other }

/// A photo license read from taxonomy.csv or iNaturalist.
///
/// Codes look like "cc-by-nc", "CC BY-SA 3.0", "cc0", "pd" or
/// "© Macaulay Library".
class PhotoLicense {
  const PhotoLicense._(this.kind, this.label, [this.url]);

  final PhotoLicenseKind kind;

  /// "CC BY-NC", "CC BY-SA 3.0", "CC0 1.0"; the raw text for
  /// [PhotoLicenseKind.other]; empty when the UI words it itself.
  final String label;

  /// License deed, when there is one.
  final String? url;

  static final _cc = RegExp(r'^cc-(by(?:-nc)?(?:-sa|-nd)?)(?:-(\d\.\d))?$');

  static PhotoLicense? parse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final code = text.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    if (text.startsWith('©') || code.contains('rights-reserved')) {
      return const PhotoLicense._(PhotoLicenseKind.reserved, '');
    }
    if (code == 'cc0' || code == 'cc0-1.0') {
      return const PhotoLicense._(
        PhotoLicenseKind.cc0,
        'CC0 1.0',
        'https://creativecommons.org/publicdomain/zero/1.0/',
      );
    }
    if (code == 'pd' || code == 'public-domain') {
      return const PhotoLicense._(
        PhotoLicenseKind.publicDomain,
        '',
        'https://creativecommons.org/publicdomain/mark/1.0/',
      );
    }
    final match = _cc.firstMatch(code);
    if (match == null) return PhotoLicense._(PhotoLicenseKind.other, text);
    final terms = match[1]!;
    final version = match[2];
    // No version in the code: iNaturalist's licenses are 4.0.
    return PhotoLicense._(
      PhotoLicenseKind.creativeCommons,
      'CC ${terms.toUpperCase()}${version == null ? '' : ' $version'}',
      'https://creativecommons.org/licenses/$terms/${version ?? '4.0'}/',
    );
  }
}

/// Who took a photo, under which license, and where it comes from.
class PhotoCredit {
  const PhotoCredit({this.author, this.license, this.source, this.pageUrl});

  /// Credit of the bundled photo, from taxonomy.csv.
  ///
  /// The bundle script writes `iNaturalist <photo id>` for the photos it
  /// replaced (J6b) and upstream `Macaulay Library ML<asset>`: both link to
  /// the photo's page.
  factory PhotoCredit.fromSpecies(TaxonomySpecies species) {
    final source = _clean(species.imageSource);
    final inat = source == null ? null : _inatSource.firstMatch(source);
    final macaulay = source == null ? null : _macaulaySource.firstMatch(source);
    return PhotoCredit(
      author: _clean(species.imageAuthor),
      license: _clean(species.imageLicense),
      source: inat != null ? 'iNaturalist' : source,
      pageUrl:
          inat != null
              ? '$kInatPhotoPage${inat[1]}'
              : macaulay != null
              ? '$kMacaulayAssetPage${macaulay[1]}'
              : null,
    );
  }

  factory PhotoCredit.fromJson(Map<String, dynamic> json) => PhotoCredit(
    author: json['author'] as String?,
    license: json['license'] as String?,
    source: json['source'] as String?,
    pageUrl: json['page_url'] as String?,
  );

  static final _inatSource = RegExp(r'^iNaturalist (\d+)$');
  static final _macaulaySource = RegExp(r'^Macaulay Library ML(\d+)$');

  final String? author;

  /// Raw license code; see [PhotoLicense.parse].
  final String? license;
  final String? source;
  final String? pageUrl;

  PhotoLicense? get parsedLicense => PhotoLicense.parse(license);

  bool get isEmpty => author == null && license == null && source == null;

  Map<String, dynamic> toJson() => {
    'author': author,
    'license': license,
    'source': source,
    'page_url': pageUrl,
  };

  static String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
