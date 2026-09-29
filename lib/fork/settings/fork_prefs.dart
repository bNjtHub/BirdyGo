/// Small fork preferences (J6h): the first name used in greetings and the
/// theme of the live screen. Both live in SharedPreferences.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/app_providers.dart';

const String kFirstNamePref = 'fork_first_name_v1';
const String kLiveThemePref = 'fork_live_theme_v1';

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

/// Theme of the live screen: the dark well, or the light page.
enum LiveTheme { dark, light }

class LiveThemeSetting extends Notifier<LiveTheme> {
  @override
  LiveTheme build() {
    final stored = ref
        .read(sharedPreferencesProvider)
        .getString(kLiveThemePref);
    return LiveTheme.values.firstWhere(
      (t) => t.name == stored,
      orElse: () => LiveTheme.dark,
    );
  }

  Future<void> set(LiveTheme theme) async {
    state = theme;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kLiveThemePref, theme.name);
  }
}

final liveThemeProvider = NotifierProvider<LiveThemeSetting, LiveTheme>(
  LiveThemeSetting.new,
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
