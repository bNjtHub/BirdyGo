/// « Réglages » (J6g-c): the few choices a family needs, in front of the
/// upstream settings. Every control reads and writes the same providers and
/// preferences as `SettingsScreen`; nothing is stored twice.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_screen.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_sheet.dart';
import '../game/quiz_sfx.dart';
import '../map/sensitive_species.dart';
import '../species_photo/online_photos_tile.dart';
import 'birdy_switch_row.dart';

/// Widest column on tablets.
const double _maxWidth = 600;

/// Interface languages of the app (code and native name), as in the
/// upstream settings.
const Map<String, String> _appLanguages = {
  'cs': 'Čeština',
  'de': 'Deutsch',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'nb': 'Norsk bokmål',
  'pl': 'Polski',
  'pt': 'Português',
  'ru': 'Русский',
  'zh': '简体中文',
};

class SimpleSettingsScreen extends ConsumerWidget {
  const SimpleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.page,
                BirdySpace.page,
                BirdySpace.page + birdySheetBottomInset(context),
              ),
              children: [
                BirdyOverlayHeader(title: l10n.forkSettingsTitle),
                const SizedBox(height: BirdySpace.block),
                BirdyBlock(
                  key: const ValueKey('settings-language'),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ChoiceRow<String?>(
                        key: const ValueKey('settings-app-language'),
                        title: l10n.settingsAppLanguage,
                        value: ref.watch(localeProvider)?.languageCode,
                        options: [
                          (null, l10n.settingsSpeciesLanguageSystem),
                          for (final e in _appLanguages.entries)
                            (e.key, e.value),
                        ],
                        onChanged:
                            (code) => ref
                                .read(localeProvider.notifier)
                                .setLocale(code == null ? null : Locale(code)),
                      ),
                      Divider(height: 1, color: c.line),
                      _ChoiceRow<String?>(
                        key: const ValueKey('settings-species-language'),
                        title: l10n.settingsSpeciesLanguage,
                        value: ref.watch(speciesLanguageProvider),
                        options: [
                          for (final e in speciesLanguageNames.entries)
                            (
                              e.key,
                              switch (e.key) {
                                'system' => l10n.settingsSpeciesLanguageSystem,
                                'app' => l10n.settingsSpeciesLanguageFollowApp,
                                _ => e.value,
                              },
                            ),
                        ],
                        onChanged: (code) {
                          if (code != null) {
                            ref
                                .read(speciesLanguageProvider.notifier)
                                .set(code);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyBlock(
                  key: const ValueKey('settings-theme'),
                  padding: const EdgeInsets.all(BirdySpace.l),
                  child: _ThemeChoice(
                    mode: ref.watch(themeModeProvider),
                    onChanged: (mode) {
                      HapticFeedback.selectionClick();
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    },
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyBlock(
                  key: const ValueKey('settings-options'),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      BirdySwitchRow(
                        key: const ValueKey('settings-quiz-sound'),
                        title: l10n.forkQuizSoundSwitch,
                        value: ref.watch(quizSoundOnProvider),
                        onChanged:
                            (on) =>
                                ref.read(quizSoundOnProvider.notifier).set(on),
                      ),
                      Divider(height: 1, color: c.line),
                      const OnlinePhotosTile(
                        key: ValueKey('settings-online-photos'),
                      ),
                      Divider(height: 1, color: c.line),
                      const _BlurSensitiveRow(
                        key: ValueKey('settings-blur-sensitive'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyBlock(
                  key: const ValueKey('settings-advanced'),
                  tone: BirdyBlockTone.oriole,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                  semanticLabel:
                      '${l10n.forkSettingsAdvanced}. '
                      '${l10n.forkSettingsAdvancedWarning}',
                  child: Row(
                    children: [
                      Icon(AppIcons.tune, color: c.text1),
                      const SizedBox(width: BirdySpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.forkSettingsAdvanced,
                              style: BirdyText.body.copyWith(
                                color: c.text1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              l10n.forkSettingsAdvancedWarning,
                              style: BirdyText.caption.copyWith(color: c.text1),
                            ),
                          ],
                        ),
                      ),
                      Icon(AppIcons.chevronRight, color: c.text2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row showing the chosen value; a tap opens the list of choices.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final current = options.where((o) => o.$1 == value).firstOrNull;
    final label = current?.$2 ?? '$value';
    return Semantics(
      button: true,
      label: '$title, $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _pick(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.row),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BirdySpace.l,
              vertical: BirdySpace.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: BirdyText.caption.copyWith(color: c.text2),
                      ),
                      Text(
                        label,
                        style: BirdyText.body.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pick(BuildContext context) {
    showBirdySheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final c = BirdyColors.of(sheetContext);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            BirdySpace.page,
            0,
            BirdySpace.page,
            BirdySpace.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: BirdySpace.s),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: BirdyText.heading.copyWith(color: c.text1),
                  ),
                ),
              ),
              for (final (option, text) in options)
                Semantics(
                  button: true,
                  selected: option == value,
                  label: text,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(BirdyRadii.inset),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onChanged(option);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: BirdySizes.target,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: BirdySpace.s,
                              ),
                              child: Text(
                                text,
                                style: BirdyText.body.copyWith(
                                  color: c.text1,
                                  fontWeight:
                                      option == value
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          if (option == value)
                            Icon(AppIcons.check, color: c.accentText),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Clair, Sombre or Système, as chips.
class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final labels = {
      ThemeMode.light: l10n.settingsThemeLight,
      ThemeMode.dark: l10n.settingsThemeDark,
      ThemeMode.system: l10n.settingsThemeSystem,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.settingsTheme,
            style: BirdyText.body.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: BirdySpace.m),
        Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.s,
          children: [
            for (final entry in labels.entries)
              BirdyFilterChip(
                key: ValueKey('theme-${entry.key.name}'),
                label: entry.value,
                selected: mode == entry.key,
                onSelected: () => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// « Flouter les espèces sensibles »: the same preference as the export
/// checkbox of the upstream settings.
class _BlurSensitiveRow extends ConsumerStatefulWidget {
  const _BlurSensitiveRow({super.key});

  @override
  ConsumerState<_BlurSensitiveRow> createState() => _BlurSensitiveRowState();
}

class _BlurSensitiveRowState extends ConsumerState<_BlurSensitiveRow> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(sharedPreferencesProvider);
    return BirdySwitchRow(
      title: l10n.forkBlurSensitiveExport,
      hint: l10n.forkBlurSensitiveExportHint,
      value: prefs.getBool(kBlurSensitiveExportPref) ?? true,
      onChanged: (on) async {
        await prefs.setBool(kBlurSensitiveExportPref, on);
        if (mounted) setState(() {});
      },
    );
  }
}
