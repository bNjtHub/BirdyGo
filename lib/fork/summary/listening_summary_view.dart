/// End-of-listening summary, drawn from a [ListeningSummary] (J6c,
/// fork/maquette/Resume.dc.html, SPEC.md 9.8).
///
/// Pure widgets: the screen wires data and navigation. The status card and
/// the badge pill of the mockup come with the game (J6e).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import 'listening_summary.dart';
import 'summary_text.dart';

/// Widest the column gets in landscape and on tablets.
const double _maxWidth = 560;

class ListeningSummaryView extends StatelessWidget {
  const ListeningSummaryView({
    super.key,
    required this.summary,
    required this.nameOf,
    this.imageFor,
    this.place,
    this.onDone,
    this.onMap,
    this.onShare,
    this.onOpenSpecies,
    this.onCheck,
    this.onDetails,
    this.footer,
  });

  final ListeningSummary summary;

  /// Species name in the user's language.
  final String Function(SummarySpecies species) nameOf;

  /// Species photo, if any.
  final ImageProvider? Function(String scientificName)? imageFor;

  /// Place name for the caption, when known.
  final String? place;

  final VoidCallback? onDone;
  final VoidCallback? onMap;
  final VoidCallback? onShare;
  final void Function(SummarySpecies species)? onOpenSpecies;

  /// Opens the quick review on these detection keys.
  final void Function(Set<String> keys)? onCheck;

  /// Opens the full session review.
  final VoidCallback? onDetails;

  /// Below the actions: the Faune-France button.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final toCheck = summary.keysToCheck;
    final blocks = <Widget>[
      _Hero(
        headline: summaryHeadline(l10n, summary),
        caption: summaryCaption(l10n, summary, place: place),
        body: summary.isEmpty ? l10n.forkSummaryQuietBody : null,
      ),
      if (!summary.isEmpty) _Numbers(summary: summary),
      if (summary.firstTimes.isNotEmpty || summary.maybeFirsts.isNotEmpty)
        _Novelties(
          summary: summary,
          nameOf: nameOf,
          imageFor: imageFor,
          onOpenSpecies: onOpenSpecies,
          onCheck: onCheck,
        ),
      if (!summary.isEmpty)
        _SpeciesStrip(
          summary: summary,
          nameOf: nameOf,
          imageFor: imageFor,
          onOpen: onOpenSpecies,
        ),
      _Actions(
        toCheck: toCheck,
        onCheck: onCheck == null ? null : () => onCheck!(toCheck),
        onDetails: onDetails,
      ),
    ];
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          tooltip: l10n.forkSummaryDone,
          onPressed: onDone,
        ),
        title: Text(l10n.forkSummaryTitle, style: BirdyText.heading),
        actions: [
          if (onMap != null)
            IconButton(
              icon: const Icon(AppIcons.mapSheet),
              tooltip: l10n.forkSummaryOnMap,
              onPressed: onMap,
            ),
          if (onShare != null && !summary.isEmpty)
            IconButton(
              icon: const Icon(AppIcons.share),
              tooltip: l10n.forkSummaryShare,
              onPressed: onShare,
            ),
          const SizedBox(width: BirdySpace.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              padding: const EdgeInsets.only(
                top: BirdySpace.xs,
                bottom: BirdySpace.xxl,
              ),
              children: [
                for (var i = 0; i < blocks.length; i++)
                  BirdyEntrance.staggered(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BirdySpace.gutter,
                        0,
                        BirdySpace.gutter,
                        BirdySpace.m,
                      ),
                      child: blocks[i],
                    ),
                  ),
                if (footer != null) footer!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.headline, required this.caption, this.body});

  final String headline;
  final String caption;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: BirdyText.display.copyWith(color: c.text1),
          semanticsLabel: headline,
        ),
        const SizedBox(height: BirdySpace.xs),
        Text(caption, style: BirdyText.caption.copyWith(color: c.text2)),
        if (body != null) ...[
          const SizedBox(height: BirdySpace.l),
          Text(body!, style: BirdyText.body.copyWith(color: c.text1)),
        ],
      ],
    );
  }
}

/// Three big numbers, no card: species, contacts, duration.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.summary});

  final ListeningSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget cell(String value, String label) => Expanded(
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: BirdyText.numberL.copyWith(color: c.text1),
              ),
            ),
            Text(label, style: BirdyText.caption.copyWith(color: c.text2)),
          ],
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          '${summary.species.length}',
          l10n.forkSummarySpeciesLabel(summary.species.length),
        ),
        const SizedBox(width: BirdySpace.s),
        cell(
          '${summary.contacts}',
          l10n.forkSummaryContactsLabel(summary.contacts),
        ),
        const SizedBox(width: BirdySpace.s),
        cell(
          summaryDuration(l10n, summary.duration),
          l10n.forkSummaryDurationLabel,
        ),
      ],
    );
  }
}

/// Heading for the novelties: « Une nouvelle, peut-être deux ».
String noveltiesHeading(AppLocalizations l10n, ListeningSummary summary) {
  final firsts = summary.firstTimes.length;
  final maybes = summary.maybeFirsts.length;
  if (maybes == 0) return l10n.forkSummaryNewOnly(firsts);
  if (firsts == 0) return l10n.forkSummaryMaybeOnly(maybes);
  return l10n.forkSummaryNewAndMaybe(firsts, firsts + maybes);
}

class _Novelties extends StatelessWidget {
  const _Novelties({
    required this.summary,
    required this.nameOf,
    this.imageFor,
    this.onOpenSpecies,
    this.onCheck,
  });

  final ListeningSummary summary;
  final String Function(SummarySpecies species) nameOf;
  final ImageProvider? Function(String scientificName)? imageFor;
  final void Function(SummarySpecies species)? onOpenSpecies;
  final void Function(Set<String> keys)? onCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          noveltiesHeading(l10n, summary),
          style: BirdyText.heading.copyWith(color: c.text1),
        ),
        for (final first in summary.firstTimes) ...[
          const SizedBox(height: BirdySpace.s),
          _FirstTimeCard(
            first: first,
            name: nameOf(first.species),
            image: imageFor?.call(first.species.scientificName),
            onTap:
                onOpenSpecies == null
                    ? null
                    : () => onOpenSpecies!(first.species),
          ),
        ],
        for (final maybe in summary.maybeFirsts) ...[
          const SizedBox(height: BirdySpace.s),
          _MaybeFirstRow(
            species: maybe,
            name: nameOf(maybe),
            image: imageFor?.call(maybe.scientificName),
            onTap:
                maybe.keysToCheck.isEmpty || onCheck == null
                    ? null
                    : () => onCheck!(maybe.keysToCheck),
          ),
        ],
      ],
    );
  }
}

/// « Première fois » card, in the bird's light tint.
class _FirstTimeCard extends StatelessWidget {
  const _FirstTimeCard({
    required this.first,
    required this.name,
    this.image,
    this.onTap,
  });

  final FirstTime first;
  final String name;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(first.species.scientificName);
    final radius = BorderRadius.circular(BirdyRadii.hero);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: c.isDark ? tint.tintDark : tint.tintLight,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SpeciesAvatar(image: image, tint: tint, size: 80),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NoveltyPill(kind: NoveltyKind.firstTime),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          name,
                          style: BirdyText.title.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          l10n.forkSummaryRank(
                            first.rank,
                            summaryTime(l10n, first.species.verifiedAt!),
                          ),
                          style: BirdyText.body.copyWith(color: c.text1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Peut-être une première »: grey look, level badge, chevron to check it.
class _MaybeFirstRow extends StatelessWidget {
  const _MaybeFirstRow({
    required this.species,
    required this.name,
    this.image,
    this.onTap,
  });

  final SummarySpecies species;
  final String name;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final radius = BorderRadius.circular(BirdyRadii.card);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: c.surface1,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SpeciesAvatar(
                    image: image,
                    tint: SpeciesAccents.tintOf(species.scientificName),
                    size: 40,
                    muted: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: BirdyText.species.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        ReliabilityBadge(
                          level: species.level,
                          unexpected: species.unexpected,
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(AppIcons.chevronRight, color: c.text2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All species of the session, most heard first, with a dot on those that
/// wait for a check.
class _SpeciesStrip extends StatelessWidget {
  const _SpeciesStrip({
    required this.summary,
    required this.nameOf,
    this.imageFor,
    this.onOpen,
  });

  final ListeningSummary summary;
  final String Function(SummarySpecies species) nameOf;
  final ImageProvider? Function(String scientificName)? imageFor;
  final void Function(SummarySpecies species)? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final dot = c.level(ReliabilityLevel.toCheck).foreground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.forkSummarySpeciesHeard(summary.species.length),
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
        const SizedBox(height: BirdySpace.s),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in summary.species)
                _StripItem(
                  species: s,
                  label: l10n.forkSummaryStripItem(nameOf(s), s.count),
                  pendingLabel: reliabilityLabel(l10n, s.level),
                  image: imageFor?.call(s.scientificName),
                  dotColor: dot,
                  onTap: onOpen == null ? null : () => onOpen!(s),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.species,
    required this.label,
    required this.pendingLabel,
    required this.dotColor,
    this.image,
    this.onTap,
  });

  final SummarySpecies species;
  final String label;
  final String pendingLabel;
  final Color dotColor;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(species.scientificName);
    return Semantics(
      button: onTap != null,
      label: species.pending ? '$label, $pendingLabel' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: SizedBox(
            width: BirdySizes.target,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.isDark ? tint.tintDark : tint.tintLight,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: BirdySizes.target,
                        child: Center(
                          child: SpeciesAvatar(
                            image: image,
                            tint: tint,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    if (species.pending)
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: BirdySpace.xs),
                Text(
                  '×${species.count}',
                  maxLines: 1,
                  style: BirdyText.labelCompact.copyWith(
                    color: c.text1,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

/// « Vérifier 3 détections », or the session details when nothing waits.
class _Actions extends StatelessWidget {
  const _Actions({required this.toCheck, this.onCheck, this.onDetails});

  final Set<String> toCheck;
  final VoidCallback? onCheck;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = l10n.forkSummaryDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (toCheck.isNotEmpty) ...[
          Pressable(
            enabled: onCheck != null,
            child: FilledButton.icon(
              style: BirdyButtonStyles.primary(context),
              icon: const Icon(AppIcons.check),
              label: Text(l10n.forkSummaryToCheck(toCheck.length)),
              onPressed: onCheck,
            ),
          ),
          const SizedBox(height: BirdySpace.xs),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(BirdySizes.target),
            ),
            onPressed: onDetails,
            child: Text(details),
          ),
        ] else
          Pressable(
            enabled: onDetails != null,
            child: FilledButton(
              style: BirdyButtonStyles.primary(context),
              onPressed: onDetails,
              child: Text(details),
            ),
          ),
      ],
    );
  }
}
