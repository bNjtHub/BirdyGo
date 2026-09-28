/// Listening modes « Conditions d'écoute » (fork/PLAN.md J6f).
///
/// The mode is authoritative: choosing one writes the upstream gain and
/// high-pass settings (`audioGainProvider`, `highPassFilterProvider`), which
/// the live screens already apply to the capture service on change, so the
/// switch happens without stopping the listening. « Ville » also turns on
/// [ForkNoiseReductionHook].
///
/// The Settings sliders keep working. When they no longer match the stored
/// mode's preset, [activeListeningModeProvider] is null and the UI shows
/// « Personnalisé »; the stored mode is kept (so the reducer of « Ville »
/// stays on) until the user picks a mode again.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import 'continuous_noise_reducer.dart';
import 'listening_mode_config.dart';

enum ListeningMode { normal, wind, boost, city }

/// Gain and high-pass cutoff written by a mode, plus the reducer switch.
@immutable
class ListeningModePreset {
  const ListeningModePreset({
    required this.gain,
    required this.highPassHz,
    this.noiseReduction = false,
  });

  final double gain;
  final double highPassHz;
  final bool noiseReduction;

  bool matches(double gain, double highPassHz) =>
      (this.gain - gain).abs() < 1e-6 &&
      (this.highPassHz - highPassHz).abs() < 1e-6;
}

extension ListeningModeX on ListeningMode {
  ListeningModePreset get preset => switch (this) {
    ListeningMode.normal => const ListeningModePreset(
      gain: kNormalGain,
      highPassHz: kNormalHighPassHz,
    ),
    ListeningMode.wind => const ListeningModePreset(
      gain: kWindGain,
      highPassHz: kWindHighPassHz,
    ),
    ListeningMode.boost => const ListeningModePreset(
      gain: kBoostGain,
      highPassHz: kBoostHighPassHz,
    ),
    ListeningMode.city => const ListeningModePreset(
      gain: kCityGain,
      highPassHz: kCityHighPassHz,
      noiseReduction: true,
    ),
  };

  IconData get icon => listeningModeIcon(this);
}

/// Modes offered in the sheet: « Ville » only when [cityEnabled].
List<ListeningMode> availableListeningModes({
  bool cityEnabled = kCityModeEnabled,
}) => [
  for (final m in ListeningMode.values)
    if (m != ListeningMode.city || cityEnabled) m,
];

ListeningMode _parse(String? name, bool cityEnabled) {
  final mode = ListeningMode.values.asNameMap()[name] ?? ListeningMode.normal;
  return availableListeningModes(cityEnabled: cityEnabled).contains(mode)
      ? mode
      : ListeningMode.normal;
}

/// Stores the last chosen mode and applies modes to the audio settings.
class ListeningModeController extends StateNotifier<ListeningMode> {
  ListeningModeController(
    this._ref,
    this._prefs, {
    this.cityEnabled = kCityModeEnabled,
  }) : super(_parse(_prefs.getString(kListeningModePref), cityEnabled)) {
    // A persisted « Ville » must turn the reducer back on after a restart.
    ForkNoiseReductionHook.setEnabled(state.preset.noiseReduction);
  }

  final Ref _ref;
  final SharedPreferences _prefs;
  final bool cityEnabled;

  /// Applies [mode] right away: writes gain and high-pass (live screens
  /// forward them to the capture service), switches the reducer, persists.
  Future<void> select(ListeningMode mode) async {
    if (!availableListeningModes(cityEnabled: cityEnabled).contains(mode)) {
      return;
    }
    final preset = mode.preset;
    state = mode;
    ForkNoiseReductionHook.setEnabled(preset.noiseReduction);
    await Future.wait([
      _ref.read(audioGainProvider.notifier).set(preset.gain),
      _ref.read(highPassFilterProvider.notifier).set(preset.highPassHz),
      _prefs.setString(kListeningModePref, mode.name),
    ]);
  }
}

/// Last chosen mode (persisted). Read it once at app start or in the Live
/// header so a persisted « Ville » re-enables the reducer.
final listeningModeProvider =
    StateNotifierProvider<ListeningModeController, ListeningMode>((ref) {
      return ListeningModeController(ref, ref.watch(sharedPreferencesProvider));
    });

/// The stored mode if the audio settings still match its preset, null when
/// the Settings sliders were moved by hand (shown as « Personnalisé »).
final activeListeningModeProvider = Provider<ListeningMode?>((ref) {
  final mode = ref.watch(listeningModeProvider);
  final gain = ref.watch(audioGainProvider);
  final hpf = ref.watch(highPassFilterProvider);
  return mode.preset.matches(gain, hpf) ? mode : null;
});

/// Short name of [mode]; null gives « Personnalisé ».
String listeningModeLabel(AppLocalizations l10n, ListeningMode? mode) =>
    switch (mode) {
      ListeningMode.normal => l10n.forkListeningModeNormal,
      ListeningMode.wind => l10n.forkListeningModeWind,
      ListeningMode.boost => l10n.forkListeningModeBoost,
      ListeningMode.city => l10n.forkListeningModeCity,
      null => l10n.forkListeningModeCustom,
    };

/// One-sentence description shown in the sheet.
String listeningModeDescription(AppLocalizations l10n, ListeningMode mode) =>
    switch (mode) {
      ListeningMode.normal => l10n.forkListeningModeNormalDesc,
      ListeningMode.wind => l10n.forkListeningModeWindDesc,
      ListeningMode.boost => l10n.forkListeningModeBoostDesc,
      ListeningMode.city => l10n.forkListeningModeCityDesc,
    };

/// Icon of [mode]; null (custom) gives the tune icon.
IconData listeningModeIcon(ListeningMode? mode) => switch (mode) {
  ListeningMode.normal => AppIcons.listeningNormal,
  ListeningMode.wind => AppIcons.listeningWind,
  ListeningMode.boost => AppIcons.listeningBoost,
  ListeningMode.city => AppIcons.listeningCity,
  null => AppIcons.tuneRounded,
};
