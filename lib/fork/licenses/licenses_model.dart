/// Model of the « Licences des contenus » screen (fork/PLAN.md J7): the
/// bundled species photos grouped by license family.
library;

import '../../shared/models/taxonomy_species.dart';
import '../species_photo/photo_credit.dart';

/// License families the screen groups photos under, in display order.
enum LicenseFamily {
  by,
  bySa,
  byNc,
  byNd,
  cc0,
  publicDomain,
  reserved,
  other;

  /// Family of a raw `image_license` value; null when the value is empty.
  static LicenseFamily? of(String? raw) {
    final license = PhotoLicense.parse(raw);
    if (license == null) return null;
    switch (license.kind) {
      case PhotoLicenseKind.cc0:
        return LicenseFamily.cc0;
      case PhotoLicenseKind.publicDomain:
        return LicenseFamily.publicDomain;
      case PhotoLicenseKind.reserved:
        return LicenseFamily.reserved;
      case PhotoLicenseKind.other:
        return LicenseFamily.other;
      case PhotoLicenseKind.creativeCommons:
        final label = license.label;
        if (label.contains('-ND')) return LicenseFamily.byNd;
        if (label.contains('-NC')) return LicenseFamily.byNc;
        if (label.contains('-SA')) return LicenseFamily.bySa;
        return LicenseFamily.by;
    }
  }

  /// Name shown as is, or null when the UI words it itself.
  String? get code => switch (this) {
    LicenseFamily.by => 'CC BY',
    LicenseFamily.bySa => 'CC BY-SA',
    LicenseFamily.byNc => 'CC BY-NC',
    LicenseFamily.byNd => 'CC BY-ND',
    LicenseFamily.cc0 => 'CC0',
    _ => null,
  };

  /// Deed of the family (current version), null when there is none.
  String? get deedUrl => switch (this) {
    LicenseFamily.by => 'https://creativecommons.org/licenses/by/4.0/',
    LicenseFamily.bySa => 'https://creativecommons.org/licenses/by-sa/4.0/',
    LicenseFamily.byNc => 'https://creativecommons.org/licenses/by-nc/4.0/',
    LicenseFamily.byNd => 'https://creativecommons.org/licenses/by-nd/4.0/',
    LicenseFamily.cc0 => 'https://creativecommons.org/publicdomain/zero/1.0/',
    LicenseFamily.publicDomain =>
      'https://creativecommons.org/publicdomain/mark/1.0/',
    _ => null,
  };
}

/// One bundled photo and its credit.
class LicensedPhoto {
  const LicensedPhoto({
    required this.birdnetId,
    required this.scientificName,
    required this.commonNames,
    required this.commonName,
    required this.author,
    required this.licenseLabel,
    required this.family,
    this.pageUrl,
  });

  final String birdnetId;
  final String scientificName;

  /// Every localized common name, for the search.
  final Iterable<String> commonNames;

  /// Common name in the app language.
  final String commonName;
  final String? author;

  /// « CC BY-SA 4.0 », the raw text for other licenses.
  final String licenseLabel;
  final LicenseFamily family;
  final String? pageUrl;

  bool matches(String query) {
    final q = foldForSearch(query);
    if (q.isEmpty) return true;
    return foldForSearch(scientificName).contains(q) ||
        commonNames.any((n) => foldForSearch(n).contains(q));
  }
}

/// Photos of [species] whose image is in [bundledIds], sorted by name.
///
/// Species without license text are left out: there is nothing to list.
List<LicensedPhoto> licensedPhotos(
  Iterable<TaxonomySpecies> species,
  Set<String> bundledIds, {
  required String locale,
}) {
  final out = <LicensedPhoto>[];
  for (final s in species) {
    final id = s.birdnetId;
    if (id == null || !bundledIds.contains(id)) continue;
    final family = LicenseFamily.of(s.imageLicense);
    if (family == null) continue;
    final credit = PhotoCredit.fromSpecies(s);
    final parsed = credit.parsedLicense;
    out.add(
      LicensedPhoto(
        birdnetId: id,
        scientificName: s.displayScientificName,
        commonNames: [s.commonName, ...?s.commonNames?.values],
        commonName: s.commonNameForLocale(locale),
        author: credit.author,
        licenseLabel:
            parsed == null || parsed.label.isEmpty
                ? (credit.license ?? '')
                : parsed.label,
        family: family,
        pageUrl: credit.pageUrl,
      ),
    );
  }
  out.sort(
    (a, b) => foldForSearch(a.commonName).compareTo(foldForSearch(b.commonName)),
  );
  return out;
}

/// [photos] matching [query], by family in display order, empty families
/// left out.
Map<LicenseFamily, List<LicensedPhoto>> groupByFamily(
  Iterable<LicensedPhoto> photos, {
  String query = '',
}) {
  final groups = {for (final f in LicenseFamily.values) f: <LicensedPhoto>[]};
  for (final p in photos) {
    if (p.matches(query)) groups[p.family]!.add(p);
  }
  groups.removeWhere((_, list) => list.isEmpty);
  return groups;
}

/// Ids of the bundled species images in an asset list
/// (`assets/species_images/BN00001.webp`).
Set<String> bundledImageIds(Iterable<String> assets) {
  final pattern = RegExp(r'^assets/species_images/(BN\d+)\.webp$');
  return {
    for (final a in assets)
      if (pattern.firstMatch(a) case final m?) m[1]!,
  };
}

/// Lower case without the accents of French and Western European names.
String foldForSearch(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyo';
  final buf = StringBuffer();
  for (final r in s.trim().toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString();
}
