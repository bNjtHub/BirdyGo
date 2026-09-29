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
import '../../shared/services/taxonomy_service.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/pressable.dart';
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
    final loadingProgress = progress.isLoading && !progress.hasValue;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: ContentWidthConstraint(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BirdySpace.page,
                  BirdySpace.s,
                  BirdySpace.page,
                  BirdySpace.s,
                ),
                child: BirdyOverlayHeader(title: l10n.forkDailyGoalTitle),
              ),
              Expanded(
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
                            padding: const EdgeInsets.fromLTRB(
                              BirdySpace.page,
                              BirdySpace.s,
                              BirdySpace.page,
                              BirdySpace.xxl,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _intro(goal, l10n, c),
                              const SizedBox(height: BirdySpace.block),
                              _progressBlock(
                                goal,
                                progress,
                                completed,
                                loadingProgress,
                                l10n,
                                c,
                              ),
                              const SizedBox(height: BirdySpace.block),
                              if (loadingProgress)
                                for (final _ in goal.species) ...[
                                  BirdySkeleton.box(
                                    width: double.infinity,
                                    height: BirdySizes.row,
                                    radius: BirdyRadii.card,
                                  ),
                                  const SizedBox(height: BirdySpace.s),
                                ]
                              else
                                for (final species in goal.species)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: BirdySpace.s,
                                    ),
                                    child: _tile(
                                      goal,
                                      species,
                                      completed.contains(
                                        species.scientificName,
                                      ),
                                      taxonomy,
                                      l10n,
                                      c,
                                    ),
                                  ),
                              const SizedBox(height: BirdySpace.l),
                              Pressable(
                                child: FilledButton.icon(
                                  style: BirdyButtonStyles.primary(context),
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
                              ),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    DailyGoal goal,
    DailyGoalSpecies species,
    bool heard,
    TaxonomyService? taxonomy,
    AppLocalizations l10n,
    BirdyColors c,
  ) {
    final imagePath = taxonomy?.assetImagePath(species.scientificName);
    return SpeciesTile(
      name: _name(species),
      scientificName: species.scientificName,
      avatar: SpeciesAvatar(
        image: imagePath is String ? AssetImage(imagePath) : null,
      ),
      meta: heard ? Text(l10n.detectionEvidenceHeard) : null,
      count: heard ? Icon(AppIcons.checkCircle, color: c.accentText) : null,
      action: BirdyIconButton(
        icon: AppIcons.swapHoriz,
        semanticLabel: l10n.forkDailyGoalReplace(_name(species)),
        onPressed: _replacing ? null : () => _replace(goal, species),
      ),
      onTap:
          () => SpeciesInfoOverlay.show(
            context,
            ref,
            scientificName: species.scientificName,
            commonName: _name(species),
          ),
    );
  }

  Widget _intro(DailyGoal goal, AppLocalizations l10n, BirdyColors c) {
    return BirdyBlock(
      padding: const EdgeInsets.all(BirdySpace.xl),
      radius: BirdyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMd(l10n.localeName).format(goal.day),
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            l10n.forkDailyGoalDescription(DailyGoalConfig.radiusKm),
            style: BirdyText.bodyCompact.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            '${l10n.forkDailyGoalLocation}: '
            '${goal.latitude.toStringAsFixed(3)}, '
            '${goal.longitude.toStringAsFixed(3)}',
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
        ],
      ),
    );
  }

  Widget _progressBlock(
    DailyGoal goal,
    AsyncValue<Set<String>> progress,
    Set<String> completed,
    bool loading,
    AppLocalizations l10n,
    BirdyColors c,
  ) {
    if (progress.hasError) {
      return BirdyBlock(
        tone: BirdyBlockTone.toCheck,
        child: _retry(
          l10n.forkDailyGoalError,
          () => ref.invalidate(dailyGoalProgressProvider),
          c,
        ),
      );
    }
    final label = l10n.forkDailyGoalProgress(completed.length, goal.total);
    if (loading) {
      return BirdyBlock(
        tone: BirdyBlockTone.tonal,
        padding: const EdgeInsets.all(BirdySpace.xl),
        radius: BirdyRadii.hero,
        child: Column(
          key: const ValueKey('dailyGoalProgressSkeleton'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BirdySkeleton.text(BirdyText.title, placeholder: label),
            const SizedBox(height: BirdySpace.m),
            BirdySkeleton.box(
              width: double.infinity,
              height: BirdySizes.progressBar,
              radius: BirdyRadii.pill,
            ),
          ],
        ),
      );
    }
    return BirdyBlock(
      tone: BirdyBlockTone.tonal,
      padding: const EdgeInsets.all(BirdySpace.xl),
      radius: BirdyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: label,
            excludeSemantics: true,
            child: Text(label, style: BirdyText.title.copyWith(color: c.text1)),
          ),
          const SizedBox(height: BirdySpace.m),
          ExcludeSemantics(
            child: BirdyProgressBar(
              value: goal.total == 0 ? 0 : completed.length / goal.total,
              color: c.accent,
              track: birdyTrackOnTint(c),
            ),
          ),
          if (goal.total > 0 && completed.length == goal.total) ...[
            const SizedBox(height: BirdySpace.m),
            Text(
              l10n.forkDailyGoalComplete,
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty(DailyGoalStatus status) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    if (status == DailyGoalStatus.loading || status == DailyGoalStatus.idle) {
      return ListView(
        key: const ValueKey('dailyGoalSkeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.page,
          BirdySpace.s,
          BirdySpace.page,
          BirdySpace.xxl,
        ),
        children: [
          BirdySkeleton.box(
            width: double.infinity,
            height: BirdySizes.heroMinHeight - BirdySizes.row,
            radius: BirdyRadii.hero,
          ),
          const SizedBox(height: BirdySpace.block),
          BirdySkeleton.box(
            width: double.infinity,
            height: BirdySizes.heroMinHeight / 2,
            radius: BirdyRadii.hero,
          ),
          const SizedBox(height: BirdySpace.block),
          for (var i = 0; i < 4; i++) ...[
            BirdySkeleton.box(
              width: double.infinity,
              height: BirdySizes.row,
              radius: BirdyRadii.card,
            ),
            const SizedBox(height: BirdySpace.s),
          ],
        ],
      );
    }
    final message = switch (status) {
      DailyGoalStatus.needsLocation => l10n.forkDailyGoalNoLocation,
      DailyGoalStatus.noCandidates => l10n.forkDailyGoalEmpty,
      _ => l10n.forkDailyGoalError,
    };
    return ListView(
      padding: const EdgeInsets.all(BirdySpace.page),
      children: [
        BirdyBlock(
          tone: BirdyBlockTone.toCheck,
          padding: const EdgeInsets.all(BirdySpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: BirdyText.body.copyWith(color: c.text1)),
              const SizedBox(height: BirdySpace.l),
              Wrap(
                spacing: BirdySpace.s,
                runSpacing: BirdySpace.s,
                children: [
                  Pressable(
                    child: FilledButton(
                      style: BirdyButtonStyles.tonal(context),
                      onPressed:
                          () =>
                              ref
                                  .read(dailyGoalProvider.notifier)
                                  .ensureToday(),
                      child: Text(l10n.retry),
                    ),
                  ),
                  TextButton(
                    onPressed: _settings,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, BirdySizes.target),
                      textStyle: BirdyText.labelCompact,
                    ),
                    child: Text(l10n.settings),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _retry(String message, VoidCallback retry, BirdyColors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: BirdyText.body.copyWith(color: c.text1)),
      const SizedBox(height: BirdySpace.s),
      Pressable(
        child: FilledButton(
          style: BirdyButtonStyles.tonal(context),
          onPressed: retry,
          child: Text(AppLocalizations.of(context)!.retry),
        ),
      ),
    ],
  );
}
