import 'package:birdnet_live/fork/listening_mode/continuous_noise_reducer.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode_config.dart';
import 'package:birdnet_live/l10n/app_localizations_en.dart';
import 'package:birdnet_live/l10n/app_localizations_fr.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> container([
    Map<String, Object> init = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(init);
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  tearDown(() => ForkNoiseReductionHook.setEnabled(false));

  group('presets', () {
    test('Normal restores the upstream defaults', () {
      final p = ListeningMode.normal.preset;
      expect(p.gain, 1.0);
      expect(p.highPassHz, 0);
      expect(p.noiseReduction, isFalse);
    });

    test('Vent, Boost and Ville map to the config values', () {
      expect(ListeningMode.wind.preset.highPassHz, kWindHighPassHz);
      expect(ListeningMode.wind.preset.gain, kWindGain);
      expect(ListeningMode.boost.preset.gain, kBoostGain);
      expect(ListeningMode.boost.preset.highPassHz, kBoostHighPassHz);
      expect(ListeningMode.city.preset.highPassHz, kCityHighPassHz);
      expect(ListeningMode.city.preset.noiseReduction, isTrue);
    });

    test('values fit the Settings sliders (gain 0–2, HPF 0–1000 Hz)', () {
      for (final m in ListeningMode.values) {
        expect(m.preset.gain, inInclusiveRange(0, 2));
        expect(m.preset.highPassHz, inInclusiveRange(0, 1000));
      }
    });

    test('Ville is hidden when the flag is off', () {
      expect(
        availableListeningModes(cityEnabled: false),
        isNot(contains(ListeningMode.city)),
      );
      expect(
        availableListeningModes(cityEnabled: true),
        contains(ListeningMode.city),
      );
    });
  });

  group('controller', () {
    test('defaults to Normal', () async {
      final c = await container();
      expect(c.read(listeningModeProvider), ListeningMode.normal);
      expect(c.read(activeListeningModeProvider), ListeningMode.normal);
    });

    test('select writes gain and high-pass and persists the mode', () async {
      final c = await container();
      await c.read(listeningModeProvider.notifier).select(ListeningMode.boost);
      expect(c.read(audioGainProvider), kBoostGain);
      expect(c.read(highPassFilterProvider), kBoostHighPassHz);
      expect(prefs.getString(kListeningModePref), 'boost');

      await c.read(listeningModeProvider.notifier).select(ListeningMode.normal);
      expect(c.read(audioGainProvider), 1.0);
      expect(c.read(highPassFilterProvider), 0);
    });

    test('restores the persisted mode', () async {
      final c = await container({kListeningModePref: 'wind'});
      expect(c.read(listeningModeProvider), ListeningMode.wind);
    });

    test('unknown persisted value falls back to Normal', () async {
      final c = await container({kListeningModePref: 'storm'});
      expect(c.read(listeningModeProvider), ListeningMode.normal);
    });

    test('Ville toggles the noise hook, also after a restart', () async {
      final c = await container();
      await c.read(listeningModeProvider.notifier).select(ListeningMode.city);
      expect(ForkNoiseReductionHook.enabled, isTrue);
      await c.read(listeningModeProvider.notifier).select(ListeningMode.wind);
      expect(ForkNoiseReductionHook.enabled, isFalse);

      final restarted = await container({kListeningModePref: 'city'});
      restarted.read(listeningModeProvider);
      expect(ForkNoiseReductionHook.enabled, isTrue);
    });

    test('persisted Ville falls back to Normal when the flag is off', () async {
      SharedPreferences.setMockInitialValues({kListeningModePref: 'city'});
      prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          listeningModeProvider.overrideWith(
            (ref) => ListeningModeController(ref, prefs, cityEnabled: false),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(listeningModeProvider), ListeningMode.normal);
      expect(ForkNoiseReductionHook.enabled, isFalse);
    });

    test('a manual slider change shows the mode as custom', () async {
      final c = await container();
      await c.read(listeningModeProvider.notifier).select(ListeningMode.wind);
      expect(c.read(activeListeningModeProvider), ListeningMode.wind);
      await c.read(highPassFilterProvider.notifier).set(400);
      expect(c.read(listeningModeProvider), ListeningMode.wind);
      expect(c.read(activeListeningModeProvider), isNull);
    });
  });

  test('labels and icons exist for every mode, in French and English', () {
    final fr = AppLocalizationsFr();
    final en = AppLocalizationsEn();
    expect(listeningModeLabel(fr, ListeningMode.wind), 'Vent');
    expect(listeningModeLabel(en, ListeningMode.wind), 'Wind');
    expect(listeningModeLabel(fr, null), 'Personnalisé');
    expect(fr.forkListeningModeActivated('Vent'), 'Mode Vent activé');
    final icons = {for (final m in ListeningMode.values) m.icon};
    expect(icons, hasLength(ListeningMode.values.length));
    for (final m in ListeningMode.values) {
      expect(listeningModeDescription(fr, m), isNotEmpty);
    }
  });
}
