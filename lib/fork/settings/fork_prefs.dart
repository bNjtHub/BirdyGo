/// Small fork preferences (J6h): the first name used in greetings and the
/// theme of the live screen, and the chosen bird theme (J6i). All live in
/// SharedPreferences.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';
import '../design/birdy_theme_choice.dart';

const String kFirstNamePref = 'fork_first_name_v1';
/// Old two-way live theme (dark / light), read once to migrate.
const String kLiveThemePref = 'fork_live_theme_v1';
const String kLiveAlwaysDarkPref = 'fork_live_always_dark_v1';
const String kBirdyBirdPref = 'fork_birdy_bird_v1';

/// Longest first name kept.
const int kFirstNameMaxLength = 24;

/// The first name, trimmed and cut to [kFirstNameMaxLength]; null when empty.
String? normalizeFirstName(String? raw) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty) return null;
  final cut =
      name.length > kFirstNameMaxLength
          ? name.substring(0, kFirstNameMaxLength).trimRight()
          : name;
  return cut.isEmpty ? null : cut;
}

class FirstNameSetting extends Notifier<String?> {
  @override
  String? build() => normalizeFirstName(
    ref.read(sharedPreferencesProvider).getString(kFirstNamePref),
  );

  /// Saves [raw] normalized; an empty name clears the preference.
  Future<void> set(String? raw) async {
    final name = normalizeFirstName(raw);
    state = name;
    final prefs = ref.read(sharedPreferencesProvider);
    if (name == null) {
      await prefs.remove(kFirstNamePref);
    } else {
      await prefs.setString(kFirstNamePref, name);
    }
  }
}

final firstNameProvider = NotifierProvider<FirstNameSetting, String?>(
  FirstNameSetting.new,
);

/// « Écran d'écoute toujours sombre » (J7): off by default, the live screen
/// follows the app theme (light or dark, and the chosen bird); on, it is
/// always dark, as before J7. A user who had explicitly chosen the dark
/// screen with the old two-way setting keeps it.
class LiveAlwaysDarkSetting extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(kLiveAlwaysDarkPref) ??
        prefs.getString(kLiveThemePref) == 'dark';
  }

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(kLiveAlwaysDarkPref, on);
  }
}

final liveAlwaysDarkProvider = NotifierProvider<LiveAlwaysDarkSetting, bool>(
  LiveAlwaysDarkSetting.new,
);

const String kNewSpeciesNotifPref = 'fork_new_species_notif_v1';

/// « Me prévenir des nouvelles espèces »: a notification per new species
/// while listening in the background. On by default.
class NewSpeciesNotifSetting extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(kNewSpeciesNotifPref) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(kNewSpeciesNotifPref, on);
  }
}

final newSpeciesNotifProvider = NotifierProvider<NewSpeciesNotifSetting, bool>(
  NewSpeciesNotifSetting.new,
);

/// The bird stored in [prefs] ([BirdyBird.loriot] when none, or no prefs).
/// Read before `runApp`, so the launch screen is already in the right theme.
BirdyBird birdyBirdFromPrefs(SharedPreferences? prefs) =>
    BirdyBird.fromName(prefs?.getString(kBirdyBirdPref));

class BirdyBirdSetting extends Notifier<BirdyBird> {
  @override
  BirdyBird build() => birdyBirdFromPrefs(ref.read(sharedPreferencesProvider));

  /// Picks [bird]: the whole app recolors at once, and the choice is saved.
  Future<void> set(BirdyBird bird) async {
    state = bird;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kBirdyBirdPref, bird.name);
  }
}

/// The chosen bird theme, `loriot` until the child picks one.
final birdyBirdProvider = NotifierProvider<BirdyBirdSetting, BirdyBird>(
  BirdyBirdSetting.new,
);
