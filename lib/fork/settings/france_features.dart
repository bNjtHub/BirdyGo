/// Visibility of the France-only features (Faune-France / LPO sending, the
/// « Oiseaux des jardins » count, NaturaList links).
///
/// Rule: visible when the device region is France (platform locale country
/// code `FR`, e.g. `fr_FR`) OR the language the app is shown in is French;
/// hidden otherwise. The UI language is passed by the caller (from
/// `Localizations.localeOf(context)`, so it follows the in-app language
/// setting as well as the system one).
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pure rule, kept apart for tests.
bool franceFeaturesRule({String? deviceCountry, String? uiLanguage}) =>
    deviceCountry?.toUpperCase() == 'FR' ||
    uiLanguage?.toLowerCase() == 'fr';

/// True when the device region is France. Override in tests.
final deviceRegionIsFranceProvider = Provider<bool>((ref) {
  final locales = ui.PlatformDispatcher.instance.locales;
  final country = locales.isEmpty ? null : locales.first.countryCode;
  return franceFeaturesRule(deviceCountry: country);
});

/// Whether France-only features show, for the given UI language code.
/// Override in tests (`overrideWith((ref, lang) => true)`).
final franceFeaturesProvider = Provider.family<bool, String>(
  (ref, uiLanguage) =>
      ref.watch(deviceRegionIsFranceProvider) ||
      franceFeaturesRule(uiLanguage: uiLanguage),
);

/// Watches [franceFeaturesProvider] with the UI language of [context].
bool watchFranceFeatures(BuildContext context, WidgetRef ref) => ref.watch(
  franceFeaturesProvider(Localizations.localeOf(context).languageCode),
);

/// Shows [child] only when the France-only features are visible.
class FranceOnly extends ConsumerWidget {
  const FranceOnly({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      watchFranceFeatures(context, ref) ? child : const SizedBox.shrink();
}
