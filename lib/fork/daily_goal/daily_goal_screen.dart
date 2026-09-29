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
import '../design/species_accents.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_list_row.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/birdy_wing_icon.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
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
                              BirdySpace.l,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              BirdyCrossFade(
                                child: _progressBlock(
                                  goal,
                                  progress,
                                  completed,
                                  loadingProgress,
                                  l10n,
                                  c,
                                ),
                              ),
                              const SizedBox(height: BirdySpace.block),
                              BirdyCrossFade(
                                child:
                                    loadingProgress
                                        ? _listSkeleton(goal)
                                        : BirdyListBlock(
                                          key: const ValueKey('dailyGoalList'),
                                          children: [
                                            for (final species in goal.species)
                                              _row(
                                                goal,
                                                species,
                                                completed.contains(
                                                  species.scientificName,
                                                ),
                                                taxonomy,
                                                l10n,
                                                c,
                                              ),
                                          ],
                                        ),
                              ),
                            ],
                          ),
                        ),
              ),
              if (goal != null) _listenButton(l10n, c),
            ],
          ),
        ),
      ),
    );
  }

  /// The single pinned action: 72 pill, Martin-pêcheur, listen glow, wing.
  Widget _listenButton(AppLocalizations l10n, BirdyColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        BirdySpace.s,
        BirdySpace.page,
        BirdySpace.l,
      ),
      child: Pressable(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            shadows: c.listenGlow,
          ),
          child: FilledButton.icon(
            key: const ValueKey('dailyGoalListen'),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
              minimumSize: const Size.fromHeight(BirdySizes.listen),
              shape: const StadiumBorder(),
              textStyle: BirdyText.labelLarge,
            ),
            icon: const Padding(
              padding: EdgeInsetsDirectional.only(end: BirdySpace.wingLabelGap),
              child: BirdyWingIcon(animated: true),
            ),
            label: Text(l10n.forkDailyGoalListen),
            onPressed:
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const LiveScreen(forceAutoStart: true),
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _listSkeleton(DailyGoal goal) => BirdyBlock(
    key: const ValueKey('dailyGoalListSkeleton'),
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < goal.species.length; i++)
          SizedBox(
            height: BirdySizes.row,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.l,
                vertical: BirdySpace.s,
              ),
              child: Row(
                children: [
                  BirdySkeleton.box(
                    width: BirdySizes.rowDisc,
                    height: BirdySizes.rowDisc,
                    radius: BirdyRadii.pill,
                  ),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: BirdySkeleton.box(
                      width: double.infinity,
                      height: BirdySizes.progressBar,
                      radius: BirdyRadii.pill,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  /// One species of the list, on the single row model: the found bird keeps
  /// its tint and reads « Entendu · Sûr » in Lichen; a bird to find is a
  /// grey silhouette with the hearing icon.
  Widget _row(
    DailyGoal goal,
    DailyGoalSpecies species,
    bool heard,
    TaxonomyService? taxonomy,
    AppLocalizations l10n,
    BirdyColors c,
  ) {
    final imagePath = taxonomy?.assetImagePath(species.scientificName);
    return BirdyListRow(
      key: ValueKey(
        'dailyGoal-${heard ? 'found' : 'todo'}-${species.scientificName}',
      ),
      title: _name(species),
      titleStyle: BirdyText.species,
      subtitle: heard ? l10n.forkDailyGoalHeardSure : species.scientificName,
      subtitleColor: heard ? c.sure.foreground : null,
      avatar:
          heard
              ? SpeciesAvatar(
                size: BirdySizes.rowAvatar,
                image: imagePath is String ? AssetImage(imagePath) : null,
                tint: SpeciesAccents.tintOf(species.scientificName),
              )
              : const SpeciesAvatar(size: BirdySizes.rowAvatar, mystery: true),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            heard ? AppIcons.checkCircle : AppIcons.hearing,
            color: heard ? c.sure.foreground : c.text2,
          ),
          BirdyIconButton(
            icon: AppIcons.swapHoriz,
            semanticLabel: l10n.forkDailyGoalReplace(_name(species)),
            onPressed: _replacing ? null : () => _replace(goal, species),
          ),
        ],
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
        key: const ValueKey('dailyGoalProgressError'),
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
        key: const ValueKey('dailyGoalProgressSkeleton'),
        tone: BirdyBlockTone.tonal,
        padding: const EdgeInsets.all(BirdySpace.xl),
        radius: BirdyRadii.hero,
        child: Row(
          children: [
            BirdySkeleton.box(
              width: BirdySizes.dailyGoalRing,
              height: BirdySizes.dailyGoalRing,
              radius: BirdyRadii.pill,
            ),
            const SizedBox(width: BirdySpace.xl),
            Expanded(
              child: BirdySkeleton.text(BirdyText.title, placeholder: label),
            ),
          ],
        ),
      );
    }
    final done = goal.total > 0 && completed.length == goal.total;
    return BirdyBlock(
      key: const ValueKey('dailyGoalHero'),
      tone: BirdyBlockTone.tonal,
      padding: const EdgeInsets.all(BirdySpace.xl),
      radius: BirdyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: BirdyProgressRing(
                  value: goal.total == 0 ? 0 : completed.length / goal.total,
                  color: c.accent,
                  track: birdyTrackOnTint(c),
                  size: BirdySizes.dailyGoalRing,
                  child: Text(
                    '${completed.length}',
                    style: BirdyText.display.copyWith(color: c.text1),
                  ),
                ),
              ),
              const SizedBox(width: BirdySpace.xl),
              Expanded(
                child: Semantics(
                  label: label,
                  excludeSemantics: true,
                  child: Text(
                    label,
                    style: BirdyText.title.copyWith(color: c.text1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.l),
          if (done) ...[
            Text(
              l10n.forkDailyGoalComplete,
              style: BirdyText.label.copyWith(color: c.accentText),
            ),
            const SizedBox(height: BirdySpace.s),
          ],
          Text(
            l10n.forkDailyGoalDescription(DailyGoalConfig.radiusKm),
            style: BirdyText.bodyCompact.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            '${DateFormat.yMMMMd(l10n.localeName).format(goal.day)} · '
            '${goal.latitude.toStringAsFixed(3)}, '
            '${goal.longitude.toStringAsFixed(3)}',
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
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
