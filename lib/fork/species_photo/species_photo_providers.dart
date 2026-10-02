/// Providers of the species photos (fork/PLAN.md J6b).
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import 'inat_photo_service.dart';
import 'species_photo_config.dart';

/// "Large photos (online)": off by default, like upstream's map and weather.
/// While off, no request leaves the phone.
final onlinePhotosAllowedProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, kOnlinePhotosPref, false);
    });

final inatPhotoServiceProvider = Provider<InatPhotoService>((ref) {
  final client = RetryClient(http.Client());
  ref.onDispose(client.close);
  return InatPhotoService(
    client: client,
    cacheDir:
        () async => Directory(
          p.join(
            (await getApplicationCacheDirectory()).path,
            kPhotoCacheDirName,
          ),
        ),
  );
});

/// The online photo of iNaturalist taxon `inatId`, or null.
final onlineSpeciesPhotoProvider = FutureProvider.autoDispose
    .family<OnlinePhoto?, int>((ref, inatId) async {
      if (!ref.watch(onlinePhotosAllowedProvider)) return null;
      return ref.watch(inatPhotoServiceProvider).photoFor(inatId);
    });

/// The extra photos loaded so far, and whether more may still come.
class SpeciesGallery {
  const SpeciesGallery(this.photos, {required this.loading});

  final List<GalleryPhoto> photos;

  /// The API call is pending or downloads remain.
  final bool loading;
}

/// The extra carousel photos of iNaturalist taxon `inatId`, growing as they
/// load. `bundledPage` is the page of the bundled photo, left out. Empty
/// and silent (no request) while online photos are off.
final speciesGalleryProvider = StreamProvider.autoDispose
    .family<SpeciesGallery, ({int inatId, String? bundledPage})>((ref, key) {
      if (!ref.watch(onlinePhotosAllowedProvider)) return const Stream.empty();
      return _withProgress(
        ref
            .watch(inatPhotoServiceProvider)
            .galleryFor(
              key.inatId,
              exclude: {if (key.bundledPage != null) key.bundledPage!},
            ),
      );
    });

/// Marks every event as "still loading", then ends with an explicit
/// "finished" event whatever happened (done, partly failed, error).
Stream<SpeciesGallery> _withProgress(Stream<List<GalleryPhoto>> source) async* {
  var last = const <GalleryPhoto>[];
  yield const SpeciesGallery([], loading: true);
  try {
    await for (final photos in source) {
      last = photos;
      yield SpeciesGallery(photos, loading: true);
    }
  } on Object {
    // Whatever loaded so far stays.
  }
  yield SpeciesGallery(last, loading: false);
}

/// Test hook for [_withProgress].
Stream<SpeciesGallery> withGalleryProgress(Stream<List<GalleryPhoto>> source) =>
    _withProgress(source);

/// Whether the spinner shows: only while the gallery stream has neither
/// finished nor failed.
bool galleryLoading(AsyncValue<SpeciesGallery> state) {
  if (state.hasError) return false;
  return state.value?.loading ?? true;
}
