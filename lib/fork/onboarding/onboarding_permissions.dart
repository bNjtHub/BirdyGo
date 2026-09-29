/// Permission access of the BirdyGo onboarding (J6g-a).
///
/// Nothing platform-specific is reimplemented here: the default service
/// calls exactly what upstream's `OnboardingScreen` calls (`record` for the
/// microphone prompt, `geolocator` plus `isPlatformLocationServiceEnabled`
/// for the location), and adds only a silent microphone status read so the
/// page can tell « refused » from « not asked yet » without prompting again.
/// Tests replace [onboardingPermissionsProvider] with a fake.
///
/// iOS: the same calls work on iOS (the OS prompts come from the plugins),
/// nothing extra is needed for this screen.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

import '../../core/services/location_service.dart';

/// Where a permission stands, as the onboarding shows it.
enum OnboardingPermState {
  /// Not asked yet (or the state could not be read).
  unknown,

  /// Allowed.
  granted,

  /// The person said no (the OS may not ask again: only the settings can).
  refused,

  /// Nothing to ask: location turned off on the phone, or a desktop build.
  unavailable,
}

abstract class OnboardingPermissions {
  /// Reads the microphone state without prompting.
  Future<OnboardingPermState> microphoneState();

  /// Asks for the microphone (shows the OS prompt when it can).
  Future<OnboardingPermState> requestMicrophone();

  /// Reads the location state without prompting.
  Future<OnboardingPermState> locationState();

  /// Asks for the location (shows the OS prompt when it can).
  Future<OnboardingPermState> requestLocation();

  /// Opens the phone's settings for this app.
  Future<void> openSettings();
}

bool get _isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

class PlatformOnboardingPermissions implements OnboardingPermissions {
  const PlatformOnboardingPermissions();

  @override
  Future<OnboardingPermState> microphoneState() async {
    try {
      final status = await ph.Permission.microphone.status;
      if (status.isGranted) return OnboardingPermState.granted;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return OnboardingPermState.refused;
      }
    } catch (_) {
      // Plugin missing (desktop) or OS error: stay « not asked yet ».
    }
    return OnboardingPermState.unknown;
  }

  @override
  Future<OnboardingPermState> requestMicrophone() async {
    try {
      // Same call as upstream's onboarding.
      final granted = await AudioRecorder().hasPermission();
      return granted
          ? OnboardingPermState.granted
          : OnboardingPermState.refused;
    } catch (_) {
      return OnboardingPermState.refused;
    }
  }

  @override
  Future<OnboardingPermState> locationState() async {
    if (_isDesktopPlatform) return OnboardingPermState.unavailable;
    try {
      // Read the native service state without selecting geolocator's Play
      // Services fused client (as upstream does).
      final serviceEnabled = await isPlatformLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        return OnboardingPermState.granted;
      }
      if (!serviceEnabled) return OnboardingPermState.unavailable;
      if (perm == LocationPermission.deniedForever) {
        return OnboardingPermState.refused;
      }
    } catch (_) {
      // Keep « not asked yet » on plugin or OS errors.
    }
    return OnboardingPermState.unknown;
  }

  @override
  Future<OnboardingPermState> requestLocation() async {
    if (_isDesktopPlatform) return OnboardingPermState.unavailable;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        return OnboardingPermState.granted;
      }
      return OnboardingPermState.refused;
    } catch (_) {
      return locationState();
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await ph.openAppSettings();
    } catch (_) {
      // Nothing more to try.
    }
  }
}

final onboardingPermissionsProvider = Provider<OnboardingPermissions>(
  (ref) => const PlatformOnboardingPermissions(),
);
