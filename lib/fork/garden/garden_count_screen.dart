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
      appBar: AppBar(title: Text(l10n.forkGardenTitle)),
      body: switch (count) {
        null => _Intro(
          onStart:
              () =>
                  ref.read(gardenCountProvider.notifier).start(DateTime.now()),
        ),
        GardenCount(finished: false) => _Running(count: count),
        _ => _Summary(count: count),
      },
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
    final theme = Theme.of(context);
    final national = isNationalGardenWeekend(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(l10n.forkGardenIntro, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Text(l10n.forkGardenRule, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Text(l10n.forkGardenSoundHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Text(
          national ? l10n.forkGardenNational : l10n.forkGardenFree,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(AppIcons.timerRounded),
          label: Text(l10n.forkGardenStart),
          onPressed: onStart,
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
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          gardenDuration(l10n, elapsed),
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          planned == null
              ? l10n.forkGardenFreeRunning
              : elapsed >= planned
              ? l10n.forkGardenHourDone
              : l10n.forkGardenOf(gardenDuration(l10n, planned)),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.forkGardenRule, style: theme.textTheme.bodyMedium),
        if (heard.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.forkGardenHeardTitle, style: theme.textTheme.titleMedium),
          Text(l10n.forkGardenHeardHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final sci in heard)
                ActionChip(
                  avatar: const Icon(AppIcons.add, size: 18),
                  label: Text(name(sci)),
                  onPressed: () => controller.addSpecies(sci),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (count.counts.isEmpty)
          Text(l10n.forkGardenEmpty, style: theme.textTheme.bodyLarge)
        else
          for (final e in count.counts.entries)
            _CounterRow(
              name: name(e.key),
              value: e.value,
              onChanged: (v) => controller.setCount(e.key, v),
            ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(AppIcons.add),
          label: Text(l10n.forkGardenAddSpecies),
          onPressed:
              () => _pickSpecies(context, taxonomy, locale).then((sci) {
                if (sci != null) controller.addSpecies(sci);
              }),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(AppIcons.check),
          label: Text(l10n.forkGardenFinish),
          onPressed: () => controller.finish(DateTime.now()),
        ),
      ],
    );
  }

  Future<String?> _pickSpecies(
    BuildContext context,
    TaxonomyService? taxonomy,
    String locale,
  ) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
        IconButton(
          tooltip: l10n.forkLpoCountLess,
          icon: const Icon(AppIcons.remove),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.forkLpoCountMore,
          icon: const Icon(AppIcons.add),
          onPressed:
              value < LpoConfig.gardenMaxCount
                  ? () => onChanged(value + 1)
                  : null,
        ),
      ],
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                    minTileHeight: 48,
                    title: Text(name(sci)),
                    subtitle: Text(
                      sci,
                      style: const TextStyle(fontStyle: FontStyle.italic),
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
    final theme = Theme.of(context);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final lines = gardenSummaryLines(
      l10n,
      count,
      names: (sci) => taxonomy?.lookup(sci)?.commonNameForLocale('fr') ?? sci,
      now: DateTime.now(),
    );
    final text = lines.join('\n');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(l10n.forkGardenSummaryIntro, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SelectableText(text, style: theme.textTheme.bodyLarge),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(AppIcons.openInNew),
              label: Text(l10n.forkGardenOpenSite),
              onPressed:
                  () => openExternalUrl(context, LpoConfig.oiseauxDesJardins),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => ref.read(gardenCountProvider.notifier).clear(),
              child: Text(l10n.forkGardenNew),
            ),
          ],
        ),
      ],
    );
  }
}
