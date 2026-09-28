/// Place name under the live status (J6f, « Le jardin · Beaulieu »).
///
/// Same source as the home screen and the listening summary: the geocoding
/// cache, or OpenStreetMap with the user's consent. Never asks for the
/// location permission: without it, or offline, there is no place line.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';

final livePlaceProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    if (ref.read(useGpsProvider) &&
        !await ref.read(locationServiceProvider).hasPermission()) {
      return null;
    }
    // Watched: a fresh fix at « Écouter » renames the place if it moved.
    final location = await ref.watch(currentLocationProvider.future);
    if (location == null) return null;
    return await reverseGeocode(
      latitude: location.latitude,
      longitude: location.longitude,
      localeName: ref.read(effectiveAppLocaleProvider),
    );
  } catch (_) {
    return null;
  }
});
