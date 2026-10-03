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
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_list_row.dart';
import '../design/widgets/birdy_sheet.dart';
import '../design/widgets/birdy_toast.dart'; // FORK: J7 settings toast
import '../game/quiz_sfx.dart';
import '../map/sensitive_species.dart';
import '../species_photo/online_photos_tile.dart';
import 'birdy_switch_row.dart';
import 'fork_prefs.dart';
import 'my_bird_screen.dart'; // FORK: J6i

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
                BirdyListBlock(
                  key: const ValueKey('settings-you'),
                  title: l10n.forkSettingsYou,
                  children: [
                    const _FirstNameField(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BirdySpace.l,
                        BirdySpace.s,
                        BirdySpace.l,
                        BirdySpace.l,
                      ),
                      child: Text(
                        l10n.forkFirstNameNote,
                        style: BirdyText.caption.copyWith(color: c.text2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyListBlock(
                  key: const ValueKey('settings-language'),
                  title: l10n.forkSettingsLanguages,
                  children: [
                    _ChoiceRow<String?>(
                      key: const ValueKey('settings-app-language'),
                      icon: AppIcons.public,
                      title: l10n.settingsAppLanguage,
                      value: ref.watch(localeProvider)?.languageCode,
                      options: [
                        (null, l10n.settingsSpeciesLanguageSystem),
                        for (final e in _appLanguages.entries) (e.key, e.value),
                      ],
                      onChanged:
                          (code) => ref
                              .read(localeProvider.notifier)
                              .setLocale(code == null ? null : Locale(code)),
                    ),
                    _ChoiceRow<String?>(
                      key: const ValueKey('settings-species-language'),
                      icon: AppIcons.translate,
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
                          ref.read(speciesLanguageProvider.notifier).set(code);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyListBlock(
                  key: const ValueKey('settings-theme'),
                  title: l10n.settingsTheme,
                  children: [
                    const MyBirdRow(key: ValueKey('settings-my-bird')), // FORK: J6i
                    _ThemeChoice(
                      mode: ref.watch(themeModeProvider),
                      onChanged: (mode) {
                        HapticFeedback.selectionClick();
                        ref.read(themeModeProvider.notifier).setThemeMode(mode);
                      },
                    ),
                    // FORK: J7, the listening screen follows the theme unless asked dark
                    BirdySwitchRow(
                      key: const ValueKey('settings-live-always-dark'),
                      icon: AppIcons.hearing,
                      title: l10n.forkLiveAlwaysDark,
                      hint: l10n.forkLiveAlwaysDarkHint,
                      value: ref.watch(liveAlwaysDarkProvider),
                      onChanged: (on) {
                        HapticFeedback.selectionClick();
                        ref.read(liveAlwaysDarkProvider.notifier).set(on);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyListBlock(
                  key: const ValueKey('settings-options'),
                  title: l10n.forkSettingsOptions,
                  children: [
                    BirdySwitchRow(
                      key: const ValueKey('settings-quiz-sound'),
                      icon: AppIcons.volumeUpRounded,
                      title: l10n.forkSettingsQuizEffects,
                      value: ref.watch(quizSoundOnProvider),
                      onChanged:
                          (on) =>
                              ref.read(quizSoundOnProvider.notifier).set(on),
                    ),
                    const OnlinePhotosTile(
                      key: ValueKey('settings-online-photos'),
                      icon: AppIcons.image,
                    ),
                    const _BlurSensitiveRow(
                      key: ValueKey('settings-blur-sensitive'),
                    ),
                  ],
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyListBlock(
                  key: const ValueKey('settings-advanced'),
                  children: [
                    BirdyListRow(
                      icon: AppIcons.tune,
                      discColor: c.oriole,
                      iconColor: c.onOriole,
                      title: l10n.forkSettingsAdvanced,
                      subtitle: l10n.forkSettingsAdvancedWarning,
                      semanticLabel:
                          '${l10n.forkSettingsAdvanced}. '
                          '${l10n.forkSettingsAdvancedWarning}',
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                    ),
                  ],
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
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.$1 == value).firstOrNull;
    final label = current?.$2 ?? '$value';
    return BirdyListRow(
      icon: icon,
      title: label,
      subtitle: title,
      semanticLabel: '$title, $label',
      onTap: () => _pick(context),
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
                      // The row outlives the sheet: confirm the choice.
                      if (context.mounted && option != value) {
                        showSettingSaved(context, title, text);
                      }
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

/// Chips in one row of equal cells, laid in a Brume well on the white block
/// (white chips would vanish on white).
class _ChipGrid extends StatelessWidget {
  const _ChipGrid({required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(BirdyRadii.inset),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.s),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: BirdySpace.s),
              Expanded(child: chips[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Clair, Sombre or Auto (system), on one line, the chosen one in ink.
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
      ThemeMode.system: l10n.forkThemeAuto,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.l,
        BirdySpace.xs,
        BirdySpace.l,
        BirdySpace.l,
      ),
      child: _ChipGrid(
        chips: [
          for (final entry in labels.entries)
            BirdyFilterChip(
              key: ValueKey('theme-${entry.key.name}'),
              label: entry.value,
              selected: mode == entry.key,
              selectedColors: BirdyChipColors.ink(c),
              centered: true,
              leading:
                  entry.key == ThemeMode.system
                      ? const Icon(AppIcons.smartphone)
                      : null,
              onSelected: () => onChanged(entry.key),
            ),
        ],
      ),
    );
  }
}

/// « Ton prénom »: saved on every change (empty clears it), trimmed and cut
/// to [kFirstNameMaxLength] by the provider.
class _FirstNameField extends ConsumerStatefulWidget {
  const _FirstNameField();

  @override
  ConsumerState<_FirstNameField> createState() => _FirstNameFieldState();
}

class _FirstNameFieldState extends ConsumerState<_FirstNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(firstNameProvider) ?? '',
  );

  final FocusNode _focus = FocusNode();
  String _committed = '';

  @override
  void initState() {
    super.initState();
    _committed = _controller.text;
    _focus.addListener(() {
      if (!_focus.hasFocus) _confirm();
    });
  }

  /// Toast once per committed change (submit or focus loss).
  void _confirm() {
    final v = _controller.text.trim();
    if (v == _committed.trim()) return;
    _committed = v;
    ref.read(firstNameProvider.notifier).set(v);
    if (mounted) showFirstNameSaved(context);
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.l,
        vertical: BirdySpace.s,
      ),
      child: Row(
        children: [
          Container(
            width: BirdySizes.rowDisc,
            height: BirdySizes.rowDisc,
            decoration: BoxDecoration(color: c.oriole, shape: BoxShape.circle),
            child: Icon(
              AppIcons.personOutline,
              size: BirdyGlyph.xxl,
              color: c.onOriole,
              fill: 1,
            ),
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: TextField(
              key: const ValueKey('settings-first-name'),
              controller: _controller,
              focusNode: _focus,
              maxLength: kFirstNameMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: BirdyText.label.copyWith(color: c.text1),
              decoration: InputDecoration(
                labelText: l10n.forkFirstNameLabel,
                hintText: l10n.forkFirstNameHint,
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: (v) => ref.read(firstNameProvider.notifier).set(v),
              onSubmitted: (_) => _confirm(),
            ),
          ),
        ],
      ),
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
      icon: AppIcons.visibilityOff,
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
