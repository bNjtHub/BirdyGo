/// Today's local listening checklist. Opening it creates the day's list;
/// the home card only reads the saved goal and never requests GPS access.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../features/live/live_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/species_avatar.dart';
import '../design/widgets/species_tile.dart';
import 'daily_goal.dart';
import 'daily_goal_providers.dart';
import 'daily_goal_replacement_screen.dart';

class DailyGoalScreen extends ConsumerStatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  ConsumerState<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends ConsumerState<DailyGoalScreen> {
  bool _replacing = false;

  @override
  void initState() {
    super.initState();
    _ensureAfterFrame();
  }

  void _ensureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(dailyGoalProvider.notifier).ensureToday());
      }
    });
  }

  Future<void> _settings() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (!mounted) return;
    ref.invalidate(currentLocationProvider);
    await ref.read(dailyGoalProvider.notifier).ensureToday();
  }

  String _name(DailyGoalSpecies species) =>
      ref
          .read(taxonomyServiceProvider)
          .value
          ?.lookup(species.scientificName)
          ?.commonNameForLocale(ref.read(effectiveSpeciesLocaleProvider)) ??
      species.commonName;

  Future<void> _replace(DailyGoal goal, DailyGoalSpecies species) async {
    final l10n = AppLocalizations.of(context)!;
    final chosen = await Navigator.of(context).push<DailyGoalSpecies>(
      MaterialPageRoute(
        builder:
            (_) => DailyGoalReplacementScreen(
              replacing: species,
              alternatives: goal.availableReplacements,
            ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _replacing = true);
    var saved = false;
    try {
      saved = await ref
          .read(dailyGoalProvider.notifier)
          .replace(species.scientificName, chosen.scientificName);
    } catch (_) {
      // The persisted list remains the source of truth on write failure.
    }
    if (!mounted) return;
    setState(() => _replacing = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.forkDailyGoalError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dailyGoalProvider, (previous, next) {
      if (next.status == DailyGoalStatus.idle &&
          previous?.status != DailyGoalStatus.idle) {
        _ensureAfterFrame();
      }
    });
    final state = ref.watch(dailyGoalProvider);
    final goal = state.goal;
    final l10n = AppLocalizations.of(context)!;
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    ref.watch(effectiveSpeciesLocaleProvider);
    final progress = ref.watch(dailyGoalProgressProvider);
    final completed = progress.value ?? const <String>{};
    final c = BirdyColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l10n.forkDailyGoalTitle)),
      body: SafeArea(
        child: ContentWidthConstraint(
          child:
              goal == null
                  ? _empty(state.status)
                  : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(dailyGoalProgressProvider);
                      try {
                        await ref.read(dailyGoalProgressProvider.future);
                      } catch (_) {
                        // The provider's error state displays the retry action.
                      }
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(BirdySpace.l),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          DateFormat.yMMMMd(l10n.localeName).format(goal.day),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.forkDailyGoalDescription(
                            DailyGoalConfig.radiusKm,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${l10n.forkDailyGoalLocation}: '
                          '${goal.latitude.toStringAsFixed(3)}, '
                          '${goal.longitude.toStringAsFixed(3)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        if (progress.hasError)
                          _retry(
                            l10n.forkDailyGoalError,
                            () => ref.invalidate(dailyGoalProgressProvider),
                          )
                        else if (progress.isLoading)
                          const LinearProgressIndicator()
                        else ...[
                          Text(
                            l10n.forkDailyGoalProgress(
                              completed.length,
                              goal.total,
                            ),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value:
                                goal.total == 0
                                    ? 0
                                    : completed.length / goal.total,
                            semanticsLabel: l10n.forkDailyGoalProgress(
                              completed.length,
                              goal.total,
                            ),
                          ),
                          if (goal.total > 0 && completed.length == goal.total)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(l10n.forkDailyGoalComplete),
                            ),
                        ],
                        const SizedBox(height: 20),
                        for (final species in goal.species)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SpeciesTile(
                              name: _name(species),
                              scientificName: species.scientificName,
                              avatar: SpeciesAvatar(
                                image: switch (taxonomy?.assetImagePath(
                                  species.scientificName,
                                )) {
                                  final String path => AssetImage(path),
                                  null => null,
                                },
                              ),
                              meta:
                                  completed.contains(species.scientificName)
                                      ? Text(l10n.detectionEvidenceHeard)
                                      : null,
                              count:
                                  completed.contains(species.scientificName)
                                      ? Icon(
                                        AppIcons.checkCircle,
                                        color: c.accentText,
                                      )
                                      : null,
                              action: IconButton(
                                icon: const Icon(AppIcons.swapHoriz),
                                tooltip: l10n.forkDailyGoalReplace(
                                  _name(species),
                                ),
                                onPressed:
                                    _replacing
                                        ? null
                                        : () => _replace(goal, species),
                              ),
                              onTap:
                                  () => SpeciesInfoOverlay.show(
                                    context,
                                    ref,
                                    scientificName: species.scientificName,
                                    commonName: _name(species),
                                  ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(AppIcons.hearing),
                          label: Text(l10n.forkDailyGoalListen),
                          onPressed:
                              () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder:
                                      (_) => const LiveScreen(
                                        forceAutoStart: true,
                                      ),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _empty(DailyGoalStatus status) {
    final l10n = AppLocalizations.of(context)!;
    if (status == DailyGoalStatus.loading || status == DailyGoalStatus.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    final message = switch (status) {
      DailyGoalStatus.needsLocation => l10n.forkDailyGoalNoLocation,
      DailyGoalStatus.noCandidates => l10n.forkDailyGoalEmpty,
      _ => l10n.forkDailyGoalError,
    };
    return ListView(
      padding: const EdgeInsets.all(BirdySpace.l),
      children: [
        Text(message),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref.read(dailyGoalProvider.notifier).ensureToday(),
          child: Text(l10n.retry),
        ),
        TextButton(onPressed: _settings, child: Text(l10n.settings)),
      ],
    );
  }

  Widget _retry(String message, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      TextButton(
        onPressed: retry,
        child: Text(AppLocalizations.of(context)!.retry),
      ),
    ],
  );
}
