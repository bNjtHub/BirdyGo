/// Larger species photos from iNaturalist, kept in a disk cache
/// (fork/PLAN.md J6b, DESIGN.md Photos).
///
/// Asked only when a species sheet opens and the "large photos (online)"
/// switch is on: one API request per species and per month at most, no
/// prefetch. Never throws: offline, the bundled photo simply stays.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import 'photo_credit.dart';
import 'photo_label.dart';
import 'species_photo_config.dart';

/// A photo on disk and whom to credit for it.
class OnlinePhoto {
  const OnlinePhoto(this.file, this.credit);

  final File file;
  final PhotoCredit credit;
}

/// The photo of an iNaturalist taxon chosen for the app.
class InatPhotoChoice {
  const InatPhotoChoice(this.url, this.credit, [this.label]);

  final String url;
  final PhotoCredit credit;

  /// What the photo shows, when iNaturalist annotations say so.
  final PhotoLabel? label;

  /// First open-license landscape photo of [taxon] (a `/v1/taxa` result),
  /// in the order curated on iNaturalist, default photo first.
  /// Same rule as tools/fork_species_photos.py, so the online photo is
  /// usually the one the bundle carries.
  static InatPhotoChoice? pick(
    Map<String, dynamic> taxon, {
    String size = kOnlinePhotoSize,
  }) {
    final candidates = <Object?>[
      for (final taxonPhoto in taxon['taxon_photos'] as List? ?? const [])
        if (taxonPhoto is Map) taxonPhoto['photo'],
      taxon['default_photo'],
    ];
    for (final photo in candidates.whereType<Map<String, dynamic>>()) {
      final choice = _choiceOf(photo, size);
      if (choice != null) return choice;
    }
    return null;
  }

  /// Up to [max] open-license landscape photos of [taxon], same rule as
  /// [pick], without those whose page is in [exclude] (the photo the sheet
  /// already shows) and without duplicates. Carousel photos (J7).
  static List<InatPhotoChoice> pickAll(
    Map<String, dynamic> taxon, {
    int max = kCarouselExtraPhotos,
    Set<String> exclude = const {},
    String size = kOnlinePhotoSize,
  }) {
    final candidates = <Object?>[
      for (final taxonPhoto in taxon['taxon_photos'] as List? ?? const [])
        if (taxonPhoto is Map) taxonPhoto['photo'],
    ];
    final seen = {...exclude};
    final out = <InatPhotoChoice>[];
    for (final photo in candidates.whereType<Map<String, dynamic>>()) {
      final choice = _choiceOf(photo, size);
      if (choice == null) continue;
      if (!seen.add(choice.credit.pageUrl ?? choice.url)) continue;
      out.add(choice);
      if (out.length >= max) break;
    }
    return out;
  }

  /// Up to [max] photos from `/v2/observations` [results] (best voted first),
  /// each labelled by its annotations. Adults come first, the first adult
  /// then one of the other sex for variety, and one juvenile last; photos
  /// of unknown life stage are left to the taxon fallback. One photo per
  /// observation, same licence and landscape rule as [pickAll].
  static List<InatPhotoChoice> pickFromObservations(
    List<Map<String, dynamic>> results, {
    int max = kCarouselExtraPhotos,
    Set<String> exclude = const {},
    String size = kOnlinePhotoSize,
  }) {
    final seen = {...exclude};
    final adults = <InatPhotoChoice>[];
    InatPhotoChoice? juvenile;
    for (final obs in results) {
      final label = PhotoLabel.fromAnnotations(obs['annotations']);
      final stage = label?.stage;
      if (stage != PhotoLifeStage.adult && stage != PhotoLifeStage.juvenile) {
        continue;
      }
      if (stage == PhotoLifeStage.juvenile && juvenile != null) continue;
      final photos = obs['photos'];
      if (photos is! List) continue;
      final photo = photos.whereType<Map<String, dynamic>>().firstOrNull;
      if (photo == null) continue;
      final choice = _choiceOf(photo, size, label);
      if (choice == null) continue;
      if (!seen.add(choice.credit.pageUrl ?? choice.url)) continue;
      if (stage == PhotoLifeStage.juvenile) {
        juvenile = choice;
      } else {
        adults.add(choice);
      }
    }
    final adultRoom = juvenile == null ? max : max - 1;
    final out = <InatPhotoChoice>[];
    if (adults.isNotEmpty && adultRoom > 0) {
      final first = adults.first;
      final other = adults.skip(1).where(
        (a) => a.label?.sex != null && a.label!.sex != first.label?.sex,
      );
      out.add(first);
      if (other.isNotEmpty && adultRoom > 1) out.add(other.first);
      for (final a in adults.skip(1)) {
        if (out.length >= adultRoom) break;
        if (!out.contains(a)) out.add(a);
      }
    }
    if (juvenile != null && max > 0) out.add(juvenile);
    return out;
  }

  static InatPhotoChoice? _choiceOf(
    Map<String, dynamic> photo,
    String size, [
    PhotoLabel? label,
  ]) {
    final license = (photo['license_code'] as String? ?? '').toLowerCase();
    if (!kOpenPhotoLicenses.contains(license)) return null;
    final dims = photo['original_dimensions'];
    final width = dims is Map ? dims['width'] as num? : null;
    final height = dims is Map ? dims['height'] as num? : null;
    if (width == null || height == null || height <= 0) return null;
    if (width / height < kPhotoMinAspectRatio) return null;
    final url = inatSizedUrl(photo, size);
    if (url == null) return null;
    return InatPhotoChoice(
      url,
      PhotoCredit(
        author: inatAuthor(photo),
        license: license,
        source: 'iNaturalist',
        pageUrl: photo['id'] == null ? null : '$kInatPhotoPage${photo['id']}',
      ),
      label,
    );
  }
}

/// A carousel photo held in memory for the app run, with its credit.
class GalleryPhoto {
  const GalleryPhoto(this.bytes, this.credit, [this.label]);

  final Uint8List bytes;
  final PhotoCredit credit;
  final PhotoLabel? label;
}

final _sizedUrl = RegExp(
  r'/(square|thumb|small|medium|large|original)\.(\w+)(\?.*)?$',
);
final _attribution = RegExp(
  r'^\(c\)\s*(.+?),\s*(?:some|all|no) rights reserved',
  caseSensitive: false,
);

/// URL of an iNaturalist [photo] at [size] (square … original).
String? inatSizedUrl(Map<String, dynamic> photo, String size) {
  final explicit = photo['${size}_url'];
  if (explicit is String && explicit.isNotEmpty) return explicit;
  for (final key in const ['url', 'medium_url', 'square_url']) {
    final url = photo[key];
    if (url is String && _sizedUrl.hasMatch(url)) {
      return url.replaceFirstMapped(
        _sizedUrl,
        (m) => '/$size.${m[2]}${m[3] ?? ''}',
      );
    }
  }
  return null;
}

/// Photographer's name, from `attribution_name` or "(c) Name, …".
String? inatAuthor(Map<String, dynamic> photo) {
  final name = (photo['attribution_name'] as String? ?? '').trim();
  if (name.isNotEmpty) return name;
  final attribution = (photo['attribution'] as String? ?? '').trim();
  if (attribution.isEmpty) return null;
  return _attribution.firstMatch(attribution)?[1]?.trim() ?? attribution;
}

/// Fetches, caches and hands out the online photo of a taxon.
class InatPhotoService {
  InatPhotoService({
    required http.Client client,
    required Future<Directory> Function() cacheDir,
    DateTime Function()? now,
    this.maxCacheBytes = kPhotoCacheMaxBytes,
    this.infoMaxAge = kPhotoInfoMaxAge,
  }) : _client = client,
       _cacheDir = cacheDir,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final Future<Directory> Function() _cacheDir;
  final DateTime Function() _now;
  final int maxCacheBytes;
  final Duration infoMaxAge;

  final Map<int, Future<OnlinePhoto?>> _inFlight = {};

  // Carousel, kept for the app run only: one API request per species.
  final Map<int, Future<Map<String, dynamic>?>> _taxa = {};
  final Map<int, Future<List<Map<String, dynamic>>>> _observations = {};
  final Map<String, GalleryPhoto> _gallery = {};

  static const _headers = {
    'User-Agent': AppConstants.networkUserAgent,
    'Accept': 'application/json',
  };

  /// The online photo of iNaturalist taxon [inatId], or null (no open
  /// photo, offline with nothing cached, any error).
  Future<OnlinePhoto?> photoFor(int inatId) =>
      _inFlight[inatId] ??= _load(inatId).whenComplete(() {
        // A block, not an arrow: returning the removed future would make
        // this future wait for itself.
        _inFlight.remove(inatId);
      });

  /// The extra photos of the carousel of taxon [inatId], as a growing list:
  /// one yield per photo once it is fully downloaded, so a page only exists
  /// when its image is ready. One API request per species and app run, then
  /// the photos one after the other (the next one is thus always prefetched).
  /// [exclude] holds the photo pages already shown. Never throws: any
  /// failure just ends the stream with what was loaded.
  Stream<List<GalleryPhoto>> galleryFor(
    int inatId, {
    Set<String> exclude = const {},
  }) async* {
    // Observations first (photos labelled adult, juvenile, sex), then the
    // taxon photos (unlabelled) only if they leave room: two requests at most.
    final choices = <InatPhotoChoice>[];
    try {
      final results = await (_observations[inatId] ??= _fetchObservations(
        inatId,
      ));
      choices.addAll(
        InatPhotoChoice.pickFromObservations(results, exclude: exclude),
      );
    } on Object {
      _observations.remove(inatId); // a failure is not remembered
    }
    if (choices.length < kCarouselExtraPhotos) {
      try {
        final taxon = await (_taxa[inatId] ??= _fetchTaxon(inatId));
        if (taxon != null) {
          choices.addAll(
            InatPhotoChoice.pickAll(
              taxon,
              max: kCarouselExtraPhotos - choices.length,
              exclude: {
                ...exclude,
                for (final c in choices) c.credit.pageUrl ?? c.url,
              },
            ),
          );
        }
      } on Object {
        _taxa.remove(inatId); // a failure is not remembered
      }
    }
    final loaded = <GalleryPhoto>[];
    for (final choice in choices) {
      try {
        final photo = _gallery[choice.url] ??= await _download(choice);
        loaded.add(photo);
        yield List.unmodifiable(loaded);
      } on Object {
        // This photo is skipped, the next ones may work.
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchObservations(int inatId) async {
    final uri = Uri.parse('$kInatApiBaseV2/observations').replace(
      queryParameters: {
        'taxon_id': '$inatId',
        'quality_grade': 'research',
        'photos': 'true',
        'photo_license': kOpenPhotoLicenses.where((l) => l != 'pd').join(','),
        'order_by': 'votes',
        'per_page': '$kObservationsPerPage',
        'fields': kObservationFields,
      },
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(kPhotoApiTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    final results = (jsonDecode(response.body) as Map)['results'] as List?;
    return (results ?? const []).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>?> _fetchTaxon(int inatId) async {
    final response = await _client
        .get(Uri.parse('$kInatApiBase/taxa/$inatId'), headers: _headers)
        .timeout(kPhotoApiTimeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    final results = (jsonDecode(response.body) as Map)['results'] as List?;
    final taxa = (results ?? const []).whereType<Map<String, dynamic>>();
    return taxa.where((t) => t['id'] == inatId).firstOrNull ??
        taxa.firstOrNull;
  }

  Future<GalleryPhoto> _download(InatPhotoChoice choice) async {
    final response = await _client
        .get(Uri.parse(choice.url), headers: _headers)
        .timeout(kPhotoDownloadTimeout);
    final type = response.headers['content-type'];
    if (response.statusCode != 200 ||
        response.bodyBytes.isEmpty ||
        response.bodyBytes.length > kOnlinePhotoMaxBytes ||
        (type != null && !type.startsWith('image/'))) {
      throw http.ClientException('bad photo');
    }
    return GalleryPhoto(response.bodyBytes, choice.credit, choice.label);
  }

  Future<OnlinePhoto?> _load(int inatId) async {
    try {
      final dir = await _cacheDir();
      await dir.create(recursive: true);
      final infoFile = File('${dir.path}/$inatId.json');
      final cached = await _readInfo(infoFile);
      final cachedPhoto = await _cachedPhoto(dir, cached);

      if (cached != null && _now().difference(cached.fetchedAt) < infoMaxAge) {
        if (cached.url == null) return null;
        if (cachedPhoto != null) return await _touched(cachedPhoto);
        // The file was evicted: download it again, no API request.
        return await _store(dir, infoFile, inatId, cached.url!, cached.credit);
      }

      final InatPhotoChoice? choice;
      try {
        choice = await _fetchChoice(inatId);
      } on Object {
        return cachedPhoto; // offline: an old photo beats none
      }
      if (choice == null) {
        await _writeInfo(infoFile, _CacheInfo(_now(), null, null, null));
        await _delete(cachedPhoto?.file);
        return null;
      }
      if (cachedPhoto != null && cached!.url == choice.url) {
        await _writeInfo(
          infoFile,
          _CacheInfo(_now(), choice.url, cached.file, choice.credit),
        );
        return await _touched(OnlinePhoto(cachedPhoto.file, choice.credit));
      }
      return await _store(dir, infoFile, inatId, choice.url, choice.credit) ??
          cachedPhoto;
    } on Object {
      return null;
    }
  }

  Future<InatPhotoChoice?> _fetchChoice(int inatId) async {
    final response = await _client
        .get(Uri.parse('$kInatApiBase/taxa/$inatId'), headers: _headers)
        .timeout(kPhotoApiTimeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    final results = (jsonDecode(response.body) as Map)['results'] as List?;
    final taxa = (results ?? const []).whereType<Map<String, dynamic>>();
    final taxon =
        taxa.where((t) => t['id'] == inatId).firstOrNull ?? taxa.firstOrNull;
    return taxon == null ? null : InatPhotoChoice.pick(taxon);
  }

  /// Downloads [url] into a new file, records it, evicts old photos.
  Future<OnlinePhoto?> _store(
    Directory dir,
    File infoFile,
    int inatId,
    String url,
    PhotoCredit? credit,
  ) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(kPhotoDownloadTimeout);
    final bytes = response.bodyBytes;
    final type = response.headers['content-type'];
    if (response.statusCode != 200 ||
        bytes.isEmpty ||
        bytes.length > kOnlinePhotoMaxBytes ||
        (type != null && !type.startsWith('image/'))) {
      return null;
    }
    // A new name per download: Flutter's image cache is keyed by path.
    final name = '${inatId}_${_now().millisecondsSinceEpoch}.photo';
    final file = File('${dir.path}/$name');
    final part = File('${file.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file.path);

    final previous = await _readInfo(infoFile);
    await _writeInfo(infoFile, _CacheInfo(_now(), url, name, credit));
    if (previous?.file != null && previous!.file != name) {
      await _delete(File('${dir.path}/${previous.file}'));
    }
    final photo = await _touched(
      OnlinePhoto(file, credit ?? const PhotoCredit()),
    );
    await _evict(dir, keep: file);
    return photo;
  }

  Future<OnlinePhoto?> _cachedPhoto(Directory dir, _CacheInfo? info) async {
    if (info?.file == null || info?.url == null) return null;
    final file = File('${dir.path}/${info!.file}');
    if (!await file.exists()) return null;
    return OnlinePhoto(file, info.credit ?? const PhotoCredit());
  }

  /// Marks a photo as just shown, for the least-recently-shown eviction.
  Future<OnlinePhoto> _touched(OnlinePhoto photo) async {
    try {
      await photo.file.setLastModified(_now());
    } on Object {
      // Some file systems refuse it: eviction order is then by download.
    }
    return photo;
  }

  Future<void> _evict(Directory dir, {required File keep}) async {
    final photos = <File, FileStat>{};
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.photo')) {
        photos[entity] = await entity.stat();
      }
    }
    var total = photos.values.fold<int>(0, (sum, s) => sum + s.size);
    final oldestFirst =
        photos.keys.toList()
          ..sort((a, b) => photos[a]!.modified.compareTo(photos[b]!.modified));
    for (final file in oldestFirst) {
      if (total <= maxCacheBytes) break;
      if (file.path == keep.path) continue;
      total -= photos[file]!.size;
      await _delete(file);
    }
  }

  Future<_CacheInfo?> _readInfo(File file) async {
    try {
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _CacheInfo.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> _writeInfo(File file, _CacheInfo info) =>
      file.writeAsString(jsonEncode(info.toJson()), flush: true);

  Future<void> _delete(File? file) async {
    try {
      if (file != null && await file.exists()) await file.delete();
    } on Object {
      // Already gone.
    }
  }
}

/// What the cache knows about a taxon: its photo, or that it has none.
class _CacheInfo {
  const _CacheInfo(this.fetchedAt, this.url, this.file, this.credit);

  factory _CacheInfo.fromJson(Map<String, dynamic> json) => _CacheInfo(
    DateTime.parse(json['fetched_at'] as String),
    json['url'] as String?,
    json['file'] as String?,
    json['credit'] is Map<String, dynamic>
        ? PhotoCredit.fromJson(json['credit'] as Map<String, dynamic>)
        : null,
  );

  final DateTime fetchedAt;

  /// Null when the taxon has no open-license landscape photo.
  final String? url;
  final String? file;
  final PhotoCredit? credit;

  Map<String, dynamic> toJson() => {
    'fetched_at': fetchedAt.toIso8601String(),
    'url': url,
    'file': file,
    'credit': credit?.toJson(),
  };
}
