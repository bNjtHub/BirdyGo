/// Species photos (J6b): the bundled 480x320 photo of each species, its
/// credit, and the URL of its large version online.
///
/// Built on the PC by tools/fork_species_photos.py. A species missing from
/// the manifest keeps the BirdNET bundle photo and its taxonomy credit,
/// as long as the image is bundled.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/models/taxonomy_species.dart';
import 'photo_config.dart';
import 'photo_license.dart';

/// The photo of a species: bundled image, large version, credit.
@immutable
class SpeciesPhotoInfo {
  const SpeciesPhotoInfo({
    required this.assetPath,
    this.photoId,
    this.largeUrl,
    this.author,
    this.license,
    this.source,
    this.pageUrl,
    this.cropped = false,
  });

  /// Entry of assets/fork/species_photos.json, or null when unusable.
  static SpeciesPhotoInfo? fromManifest(Map<String, dynamic> json) {
    final birdnetId = _text(json['birdnet_id']);
    if (birdnetId == null) return null;
    final large = Uri.tryParse(_text(json['large_url']) ?? '');
    return SpeciesPhotoInfo(
      assetPath: '${PhotoConfig.bundledImagesDir}$birdnetId.webp',
      photoId: _text(json['photo_id']),
      largeUrl: large != null && large.isScheme('https') ? large : null,
      author: _text(json['author']),
      license: PhotoLicense.parse(_text(json['license'])),
      source: _text(json['source']),
      pageUrl: _text(json['page_url']),
      cropped: json['cropped'] == true,
    );
  }

  /// The BirdNET bundle photo, credited from taxonomy.csv.
  factory SpeciesPhotoInfo.fromTaxonomy(TaxonomySpecies species) =>
      SpeciesPhotoInfo(
        assetPath: species.assetImagePath,
        author: species.imageAuthor,
        license: PhotoLicense.parse(species.imageLicense),
        source: species.imageSource,
      );

  /// Bundled 480x320 WebP.
  final String assetPath;

  /// Key of the large version in the cache.
  final String? photoId;

  /// Large version online (https only).
  final Uri? largeUrl;

  final String? author;
  final PhotoLicense? license;

  /// "iNaturalist", "Wikimedia", …
  final String? source;

  /// Page of the photo at its source.
  final String? pageUrl;

  /// Cropped and resized for the app (said in the credit, as CC BY asks).
  final bool cropped;

  bool get hasCredit => author != null || license != null || source != null;

  /// Whether a large version can be fetched and cached.
  bool get hasLarge => largeUrl != null && photoId != null;

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Every manifest entry, by scientific name (model label).
class SpeciesPhotoManifest {
  const SpeciesPhotoManifest(this._photos);

  factory SpeciesPhotoManifest.fromJson(Map<String, dynamic> json) {
    final species = json['species'];
    if (species is! Map<String, dynamic>) return empty;
    return SpeciesPhotoManifest({
      for (final entry in species.entries)
        if (entry.value is Map<String, dynamic>)
          if (SpeciesPhotoInfo.fromManifest(entry.value as Map<String, dynamic>)
              case final info?)
            entry.key: info,
    });
  }

  static const empty = SpeciesPhotoManifest({});

  final Map<String, SpeciesPhotoInfo> _photos;

  SpeciesPhotoInfo? operator [](String scientificName) =>
      _photos[scientificName];

  int get length => _photos.length;
}

/// Loads the manifest once; a missing or unreadable one means no entries.
final speciesPhotoManifestProvider = FutureProvider<SpeciesPhotoManifest>((
  ref,
) async {
  try {
    final text = await rootBundle.loadString(PhotoConfig.manifestAsset);
    return SpeciesPhotoManifest.fromJson(
      jsonDecode(text) as Map<String, dynamic>,
    );
  } catch (e) {
    debugPrint('[SpeciesPhotos] no manifest: $e');
    return SpeciesPhotoManifest.empty;
  }
});

/// Paths of the bundled species images, so a species without image shows
/// its silhouette at once instead of a failed image.
final bundledSpeciesImagesProvider = FutureProvider<Set<String>>((ref) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest
        .listAssets()
        .where((path) => path.startsWith(PhotoConfig.bundledImagesDir))
        .toSet();
  } catch (e) {
    debugPrint('[SpeciesPhotos] no asset manifest: $e');
    return const {};
  }
});

/// The photo of a species, or null when no image of it is bundled.
final speciesPhotoProvider = FutureProvider.family<SpeciesPhotoInfo?, String>((
  ref,
  scientificName,
) async {
  final bundled = await ref.watch(bundledSpeciesImagesProvider.future);
  final manifest = await ref.watch(speciesPhotoManifestProvider.future);
  var info = manifest[scientificName];
  if (info == null) {
    final taxonomy = await ref.watch(taxonomyServiceProvider.future);
    final species = taxonomy.lookup(scientificName);
    if (species?.birdnetId != null) {
      info = SpeciesPhotoInfo.fromTaxonomy(species!);
    }
  }
  return info != null && bundled.contains(info.assetPath) ? info : null;
});
