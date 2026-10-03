/// Providers of the species photos (fork/PLAN.md J6b).
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../licenses/licenses_model.dart';
import 'inat_photo_service.dart';
import 'species_photo_config.dart';

/// Ids of the species images bundled in the app: the one rule for "this
/// species has a photo of its own" (credit shown, licenses listed).
final bundledImageIdsProvider = FutureProvider<Set<String>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return bundledImageIds(manifest.listAssets());
});

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
