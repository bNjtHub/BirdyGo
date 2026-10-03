/// « Oiseaux des jardins » screen: timer, hand-entered counters, sound
/// detections as invitations to look, and a summary to report (J5b).
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/live/live_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_sheet.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/empty_state.dart';
import '../lpo/lpo_config.dart';
import 'garden_count.dart';
import 'garden_summary.dart';

/// Species heard since [since] in the current listening session, newest
/// first, without repeats.
List<String> heardSince(
  Iterable<({String name, DateTime time})> heard,
  DateTime since,
) {
  final out = <String>[];
  for (final h in heard) {
    if (h.time.isBefore(since) || out.contains(h.name)) continue;
    out.add(h.name);
  }
  return out;
}

class GardenCountScreen extends ConsumerStatefulWidget {
  const GardenCountScreen({super.key});

  @override
  ConsumerState<GardenCountScreen> createState() => _GardenCountScreenState();
}

class _GardenCountScreenState extends ConsumerState<GardenCountScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The elapsed time is shown in minutes: a tick every 10 s is enough.
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      final count = ref.read(gardenCountProvider);
      if (mounted && count != null && !count.finished) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = ref.watch(gardenCountProvider);
    return Scaffold(
      backgroundColor: BirdyColors.of(context).background,
      body: SafeArea(
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
              child: BirdyOverlayHeader(title: l10n.forkGardenTitle),
            ),
            Expanded(
              child: switch (count) {
                null => _Intro(
                  onStart:
                      () => ref
                          .read(gardenCountProvider.notifier)
                          .start(DateTime.now()),
                ),
                GardenCount(finished: false) => _Running(count: count),
                _ => _Summary(count: count),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Protocol and the start button.
class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final national = isNationalGardenWeekend(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        BirdySpace.s,
        BirdySpace.page,
        BirdySpace.xxxl,
      ),
      children: [
        BirdyBlock(
          radius: BirdyRadii.hero,
          padding: const EdgeInsets.all(BirdySpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.forkGardenIntro,
                style: BirdyText.body.copyWith(color: c.text1),
              ),
              const SizedBox(height: BirdySpace.m),
              Text(
                l10n.forkGardenRule,
                style: BirdyText.body.copyWith(color: c.text1),
              ),
              const SizedBox(height: BirdySpace.m),
              Text(
                l10n.forkGardenSoundHint,
                style: BirdyText.bodyCompact.copyWith(color: c.text2),
              ),
            ],
          ),
        ),
        const SizedBox(height: BirdySpace.block),
        BirdyBlock(
          tone: BirdyBlockTone.tonal,
          child: Text(
            national ? l10n.forkGardenNational : l10n.forkGardenFree,
            style: BirdyText.label.copyWith(color: c.text1),
          ),
        ),
        const SizedBox(height: BirdySpace.xxl),
        Pressable(
          child: FilledButton.icon(
            style: BirdyButtonStyles.primary(context),
            icon: const Icon(AppIcons.timerRounded),
            label: Text(l10n.forkGardenStart),
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

/// Count in progress.
class _Running extends ConsumerWidget {
  const _Running({required this.count});

  final GardenCount count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final controller = ref.read(gardenCountProvider.notifier);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final locale = ref.watch(effectiveSpeciesLocaleProvider);
    String name(String sci) =>
        taxonomy?.lookup(sci)?.commonNameForLocale(locale) ?? sci;

    final elapsed = count.elapsed(DateTime.now());
    final planned = count.planned;
    final heard =
        heardSince(
          ref
              .watch(allSessionDetectionsProvider)
              .map((d) => (name: d.scientificName, time: d.timestamp)),
          count.start,
        ).where((s) => !count.counts.containsKey(s)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        BirdySpace.s,
        BirdySpace.page,
        BirdySpace.xxxl,
      ),
      children: [
        BirdyBlock(
          tone: BirdyBlockTone.tonal,
          radius: BirdyRadii.hero,
          padding: const EdgeInsets.all(BirdySpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gardenDuration(l10n, elapsed),
                style: BirdyText.numberXL.copyWith(color: c.text1),
              ),
              const SizedBox(height: BirdySpace.xs),
              Text(
                planned == null
                    ? l10n.forkGardenFreeRunning
                    : elapsed >= planned
                    ? l10n.forkGardenHourDone
                    : l10n.forkGardenOf(gardenDuration(l10n, planned)),
                style: BirdyText.body.copyWith(color: c.text1),
              ),
              const SizedBox(height: BirdySpace.s),
              Text(
                l10n.forkGardenRule,
                style: BirdyText.caption.copyWith(color: c.text2),
              ),
            ],
          ),
        ),
        if (heard.isNotEmpty) ...[
          const SizedBox(height: BirdySpace.block),
          BirdyBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.forkGardenHeardTitle,
                  style: BirdyText.heading.copyWith(color: c.text1),
                ),
                const SizedBox(height: BirdySpace.xs),
                Text(
                  l10n.forkGardenHeardHint,
                  style: BirdyText.caption.copyWith(color: c.text2),
                ),
                const SizedBox(height: BirdySpace.m),
                Wrap(
                  spacing: BirdySpace.s,
                  runSpacing: BirdySpace.s,
                  children: [
                    for (final sci in heard)
                      BirdyFilterChip(
                        label: name(sci),
                        selected: true,
                        leading: const Icon(AppIcons.add),
                        onSelected: () => controller.addSpecies(sci),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: BirdySpace.block),
        if (count.counts.isEmpty)
          BirdyEmptyState.inline(
            icon: AppIcons.add,
            title: l10n.forkGardenEmptyTitle,
            body: l10n.forkGardenEmpty,
          )
        else
          for (final e in count.counts.entries) ...[
            _CounterRow(
              name: name(e.key),
              value: e.value,
              onChanged: (v) => controller.setCount(e.key, v),
            ),
            const SizedBox(height: BirdySpace.s),
          ],
        const SizedBox(height: BirdySpace.s),
        Pressable(
          child: OutlinedButton.icon(
            style: BirdyButtonStyles.secondary(context),
            icon: const Icon(AppIcons.add),
            label: Text(l10n.forkGardenAddSpecies),
            onPressed:
                () => _pickSpecies(context, taxonomy, locale).then((sci) {
                  if (sci != null) controller.addSpecies(sci);
                }),
          ),
        ),
        const SizedBox(height: BirdySpace.xxl),
        Pressable(
          child: FilledButton.icon(
            style: BirdyButtonStyles.primary(context),
            icon: const BirdyIcon(BirdyIcons.tick),
            label: Text(l10n.forkGardenFinish),
            onPressed: () => controller.finish(DateTime.now()),
          ),
        ),
      ],
    );
  }

  Future<String?> _pickSpecies(
    BuildContext context,
    TaxonomyService? taxonomy,
    String locale,
  ) => showBirdySheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SpeciesPicker(taxonomy: taxonomy, locale: locale),
  );
}

/// Name, then − count +.
class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.name,
    required this.value,
    required this.onChanged,
  });

  final String name;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return BirdyBlock(
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.l,
        vertical: BirdySpace.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: BirdyText.species.copyWith(color: c.text1),
            ),
          ),
          BirdyIconButton(
            semanticLabel: l10n.forkLpoCountLess,
            icon: AppIcons.remove,
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: BirdySizes.target,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: BirdyText.numberM.copyWith(color: c.text1),
            ),
          ),
          BirdyIconButton(
            semanticLabel: l10n.forkLpoCountMore,
            icon: AppIcons.add,
            onPressed:
                value < LpoConfig.gardenMaxCount
                    ? () => onChanged(value + 1)
                    : null,
          ),
        ],
      ),
    );
  }
}

/// Garden birds first, any species by search.
class _SpeciesPicker extends StatefulWidget {
  const _SpeciesPicker({required this.taxonomy, required this.locale});

  final TaxonomyService? taxonomy;
  final String locale;

  @override
  State<_SpeciesPicker> createState() => _SpeciesPickerState();
}

class _SpeciesPickerState extends State<_SpeciesPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final taxonomy = widget.taxonomy;
    String name(String sci) =>
        taxonomy?.lookup(sci)?.commonNameForLocale(widget.locale) ?? sci;
    final results =
        _query.trim().isEmpty
            ? kGardenSpecies
            : taxonomy == null
            ? [
              for (final sci in kGardenSpecies)
                if ('${name(sci)} $sci'.toLowerCase().contains(
                  _query.trim().toLowerCase(),
                ))
                  sci,
            ]
            : [
              for (final s in taxonomy.search(_query, locale: widget.locale))
                s.scientificName,
            ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.page,
              0,
              BirdySpace.page,
              BirdySpace.s,
            ),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search),
                hintText: l10n.forkGardenSearch,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final sci in results)
                  ListTile(
                    minTileHeight: BirdySizes.target,
                    title: Text(
                      name(sci),
                      style: BirdyText.species.copyWith(
                        color: BirdyColors.of(context).text1,
                      ),
                    ),
                    subtitle: Text(
                      sci,
                      style: BirdyText.latinCompact.copyWith(
                        color: BirdyColors.of(context).text2,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(sci),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Finished count: the summary to report.
class _Summary extends ConsumerWidget {
  const _Summary({required this.count});

  final GardenCount count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final lines = gardenSummaryLines(
      l10n,
      count,
      // French on purpose: the summary feeds the French garden database.
      names: (sci) => taxonomy?.lookup(sci)?.commonNameForLocale('fr') ?? sci,
      now: DateTime.now(),
    );
    final text = lines.join('\n');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        BirdySpace.s,
        BirdySpace.page,
        BirdySpace.xxxl,
      ),
      children: [
        Text(
          l10n.forkGardenSummaryIntro,
          style: BirdyText.body.copyWith(color: c.text1),
        ),
        const SizedBox(height: BirdySpace.m),
        BirdyBlock(
          tone: BirdyBlockTone.tonal,
          child: SelectableText(
            text,
            style: BirdyText.body.copyWith(color: c.text1),
          ),
        ),
        const SizedBox(height: BirdySpace.l),
        Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.s,
          children: [
            Pressable(
              child: FilledButton.icon(
                style: BirdyButtonStyles.primary(context),
                icon: const Icon(AppIcons.contentCopy),
                label: Text(l10n.forkLpoCopy),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: text));
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.forkGardenCopied)),
                  );
                },
              ),
            ),
            Pressable(
              child: OutlinedButton.icon(
                style: BirdyButtonStyles.secondary(context),
                icon: const Icon(AppIcons.openInNew),
                label: Text(l10n.forkGardenOpenSite),
                onPressed:
                    () => openExternalUrl(context, LpoConfig.oiseauxDesJardins),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(BirdySizes.target, BirdySizes.target),
                textStyle: BirdyText.labelCompact,
              ),
              onPressed: () => ref.read(gardenCountProvider.notifier).clear(),
              child: Text(l10n.forkGardenNew),
            ),
          ],
        ),
      ],
    );
  }
}
