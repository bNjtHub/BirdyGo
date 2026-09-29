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
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import 'listening_summary.dart';
import 'summary_actions_sheet.dart';
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
    this.onAddObservation,
    this.savingObservation = false,
    this.onMarkRecording,
    this.onSendToFauneFrance,
    this.notice,
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

  /// Adds a bird observed during this session, even without a recording.
  /// Hidden from the actions sheet when null.
  final VoidCallback? onAddObservation;

  /// An observation is being saved: the sheet row is disabled.
  final bool savingObservation;

  /// « C'était un enregistrement ? » (J5c): marks the session as a
  /// recording (true) or back as real birds (false). Hidden when null.
  final void Function(bool recording)? onMarkRecording;

  /// Above the hero: the « non enregistrée » note of an unsaved listening
  /// (J6g-e).
  final Widget? notice;

  /// « Envoyer à Faune-France »: opens the LPO sheet. Hidden when null
  /// (unsaved listening, or a recording that is no observation).
  final VoidCallback? onSendToFauneFrance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final toCheck = summary.keysToCheck;
    final blocks = <Widget>[
      if (notice != null) notice!,
      _Hero(
        headline: summaryHeadline(l10n, summary),
        caption: summaryCaption(l10n, summary, place: place),
        body: summary.isEmpty ? l10n.forkSummaryQuietBody : null,
        summary: summary.isEmpty ? null : summary,
      ),
      if (summary.firstTimes.isNotEmpty || summary.maybeFirsts.isNotEmpty)
        _Novelties(
          summary: summary,
          nameOf: nameOf,
          imageFor: imageFor,
          onOpenSpecies: onOpenSpecies,
          onCheck: onCheck,
        ),
      if (summary.heardSpecies.isNotEmpty)
        _SpeciesStrip(
          species: summary.heardSpecies,
          heading: l10n.forkSummarySpeciesHeard(summary.heardSpecies.length),
          nameOf: nameOf,
          imageFor: imageFor,
          onOpen: onOpenSpecies,
        ),
      if (summary.otherObservedSpecies.isNotEmpty)
        _SpeciesStrip(
          species: summary.otherObservedSpecies,
          heading: l10n.forkSummarySpeciesObserved(
            summary.otherObservedSpecies.length,
          ),
          nameOf: nameOf,
          imageFor: imageFor,
          onOpen: onOpenSpecies,
        ),
      _Actions(
        toCheck: toCheck,
        isRecording: summary.isRecording,
        onCheck: onCheck == null ? null : () => onCheck!(toCheck),
        onDetails: onDetails,
        onMore:
            hasSummaryActions(
                  onSend: onSendToFauneFrance,
                  onAddObservation: onAddObservation,
                  onDetails: onDetails,
                  onMarkRecording: onMarkRecording,
                )
                ? () => showSummaryActionsSheet(
                  context,
                  isRecording: summary.isRecording,
                  savingObservation: savingObservation,
                  onSend: onSendToFauneFrance,
                  onAddObservation: onAddObservation,
                  onDetails: onDetails,
                  onMarkRecording: onMarkRecording,
                )
                : null,
      ),
    ];
    // Guards the button (never falls back to a bare pop) while a save is
    // in flight: `onDone` is null then, same as the former disabled icon.
    void back() => onDone?.call();
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BirdySpace.page,
                    BirdySpace.xs,
                    BirdySpace.page,
                    0,
                  ),
                  child: BirdyOverlayHeader(
                    title: l10n.forkSummaryTitle,
                    onBack: back,
                    closing: true,
                    enabled: onDone != null,
                    actions: [
                      if (onMap != null)
                        BirdyIconButton(
                          icon: AppIcons.mapSheet,
                          semanticLabel: l10n.forkSummaryOnMap,
                          onPressed: onMap,
                        ),
                      if (onShare != null && !summary.isEmpty)
                        BirdyIconButton(
                          icon: AppIcons.share,
                          semanticLabel: l10n.forkSummaryShare,
                          onPressed: onShare,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: BirdySpace.m,
                      bottom: BirdySpace.xxl,
                    ),
                    children: [
                      for (var i = 0; i < blocks.length; i++)
                        BirdyEntrance.staggered(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              BirdySpace.page,
                              0,
                              BirdySpace.page,
                              BirdySpace.block,
                            ),
                            child: blocks[i],
                          ),
                        ),
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

/// Tonal hero: the title, its caption and, when there is something to
/// count, the three numbers on white tiles.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.headline,
    required this.caption,
    this.body,
    this.summary,
  });

  final String headline;
  final String caption;
  final String? body;

  /// Null for a quiet listening: no tiles.
  final ListeningSummary? summary;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyBlock(
      tone: BirdyBlockTone.tonal,
      radius: BirdyRadii.hero,
      padding: const EdgeInsets.all(BirdySpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: BirdyText.display.copyWith(color: c.text1),
            semanticsLabel: headline,
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(caption, style: BirdyText.badge.copyWith(color: c.accentText)),
          if (body != null) ...[
            const SizedBox(height: BirdySpace.l),
            Text(body!, style: BirdyText.body.copyWith(color: c.text1)),
          ],
          if (summary != null) ...[
            const SizedBox(height: BirdySpace.l),
            _Numbers(summary: summary!),
          ],
        ],
      ),
    );
  }
}

/// Three big numbers on white tiles: species, contacts, duration.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.summary});

  final ListeningSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget cell(String value, String label, {String? unit}) => Expanded(
      child: BirdyBlock(
        padding: const EdgeInsets.symmetric(
          horizontal: BirdySpace.m,
          vertical: BirdySpace.m,
        ),
        semanticLabel: '${unit == null ? value : '$value $unit'} $label',
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                // One line, two sizes: the spans share their baseline.
                child: Text.rich(
                  TextSpan(
                    text: value,
                    style: BirdyText.numberL.copyWith(color: c.text1),
                    children: [
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: BirdyText.label.copyWith(
                            color: c.text1,
                            fontSize: BirdyText.emphasisSize,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: BirdySpace.xs),
              Text(label, style: BirdyText.caption.copyWith(color: c.text2)),
            ],
          ),
        ),
      ),
    );
    final minutes = (summary.duration.inSeconds / 60).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          '${summary.species.length}',
          l10n.forkSummarySpeciesLabel(summary.species.length),
        ),
        const SizedBox(width: BirdySpace.block),
        cell(
          '${summary.contacts}',
          l10n.forkSummaryContactsLabel(summary.contacts),
        ),
        const SizedBox(width: BirdySpace.block),
        minutes < 60
            ? cell(
              '$minutes',
              l10n.forkSummaryDurationLabel,
              unit: l10n.forkSummaryMinutesUnit,
            )
            : cell(
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
    return BirdyListBlock(
      title: noveltiesHeading(l10n, summary),
      children: [
        for (final first in summary.firstTimes)
          _NoveltyRow(
            species: first.species,
            name: nameOf(first.species),
            image: imageFor?.call(first.species.scientificName),
            pill: const NoveltyPill(kind: NoveltyKind.firstTime),
            detail: Text(
              first.species.hasPreciseVerifiedTime
                  ? l10n.forkSummaryRank(
                    first.rank,
                    summaryTime(l10n, first.species.verifiedAt!),
                  )
                  : l10n.forkSummaryRankWithoutTime(first.rank),
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
            onTap:
                onOpenSpecies == null
                    ? null
                    : () => onOpenSpecies!(first.species),
          ),
        for (final maybe in summary.maybeFirsts)
          _NoveltyRow(
            species: maybe,
            name: nameOf(maybe),
            image: imageFor?.call(maybe.scientificName),
            muted: true,
            detail: ReliabilityBadge(
              level: maybe.level,
              unexpected: maybe.unexpected,
              score: maybe.bestScore,
            ),
            onTap:
                maybe.keysToCheck.isEmpty || onCheck == null
                    ? null
                    : () => onCheck!(maybe.keysToCheck),
          ),
      ],
    );
  }
}

/// One species of the novelties block: avatar 48, name, an optional pill
/// and a detail line, chevron when it opens something. Same metrics as
/// [BirdyListRow], which only takes plain-text subtitles.
class _NoveltyRow extends StatelessWidget {
  const _NoveltyRow({
    required this.species,
    required this.name,
    required this.detail,
    this.image,
    this.pill,
    this.muted = false,
    this.onTap,
  });

  final SummarySpecies species;
  final String name;
  final Widget detail;
  final ImageProvider? image;
  final Widget? pill;

  /// « Peut-être une première »: grey avatar.
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.row),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BirdySpace.l,
          vertical: BirdySpace.s,
        ),
        child: Row(
          children: [
            SpeciesAvatar(
              image: image,
              tint: SpeciesAccents.tintOf(species.scientificName),
              size: BirdyGlyph.disc48,
              muted: muted,
            ),
            const SizedBox(width: BirdySpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pill != null) ...[
                    pill!,
                    const SizedBox(height: BirdySpace.xs),
                  ],
                  Text(
                    name,
                    style: BirdyText.species.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  detail,
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: BirdySpace.s),
              Icon(AppIcons.chevronRight, size: BirdyGlyph.x3l, color: c.text2),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    row = Semantics(button: true, child: InkWell(onTap: onTap, child: row));
    return Pressable(child: row);
  }
}

/// All species of the session, most heard first, with a dot on those that
/// wait for a check, in a white titled block.
class _SpeciesStrip extends StatelessWidget {
  const _SpeciesStrip({
    required this.species,
    required this.heading,
    required this.nameOf,
    this.imageFor,
    this.onOpen,
  });

  final List<SummarySpecies> species;
  final String heading;
  final String Function(SummarySpecies species) nameOf;
  final ImageProvider? Function(String scientificName)? imageFor;
  final void Function(SummarySpecies species)? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final dot = c.level(ReliabilityLevel.toCheck).foreground;
    return BirdyListBlock(
      title: heading,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BirdySpace.l,
            BirdySpace.xs,
            BirdySpace.l,
            BirdySpace.l,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in species)
                  _StripItem(
                    species: s,
                    label: l10n.forkSummaryStripItem(nameOf(s), s.count),
                    pendingLabel: reliabilityLabel(l10n, s.level),
                    evidenceLabel:
                        s.seen
                            ? s.heard
                                ? l10n.detectionEvidenceHeardAndSeen
                                : l10n.detectionEvidenceSeen
                            : null,
                    image: imageFor?.call(s.scientificName),
                    dotColor: dot,
                    onTap: onOpen == null ? null : () => onOpen!(s),
                  ),
              ],
            ),
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
    this.evidenceLabel,
    this.image,
    this.onTap,
  });

  final SummarySpecies species;
  final String label;
  final String pendingLabel;
  final Color dotColor;
  final String? evidenceLabel;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(species.scientificName);
    return Semantics(
      button: onTap != null,
      label: [
        label,
        if (evidenceLabel != null) evidenceLabel!,
        if (species.pending) pendingLabel,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: BirdySpace.cozy),
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
                            size: BirdyGlyph.disc40,
                          ),
                        ),
                      ),
                    ),
                    if (species.pending)
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: Container(
                          width: BirdySpace.s,
                          height: BirdySpace.s,
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
                if (evidenceLabel != null)
                  Text(
                    evidenceLabel!,
                    textAlign: TextAlign.center,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Vérifier 3 détections », or the session details when nothing waits,
/// then « Autres actions » (the sheet holds every other action).
class _Actions extends StatelessWidget {
  const _Actions({
    required this.toCheck,
    required this.isRecording,
    this.onCheck,
    this.onDetails,
    this.onMore,
  });

  final Set<String> toCheck;
  final bool isRecording;
  final VoidCallback? onCheck;
  final VoidCallback? onDetails;

  /// Null when the sheet would be empty.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRecording) ...[
          Text(
            l10n.forkPracticeMarked,
            textAlign: TextAlign.center,
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
          const SizedBox(height: BirdySpace.s),
        ],
        if (toCheck.isNotEmpty)
          Pressable(
            enabled: onCheck != null,
            child: FilledButton.icon(
              style: BirdyButtonStyles.primary(context),
              icon: const Icon(AppIcons.check),
              label: Text(l10n.forkSummaryToCheck(toCheck.length)),
              onPressed: onCheck,
            ),
          )
        else
          Pressable(
            enabled: onDetails != null,
            child: FilledButton(
              style: BirdyButtonStyles.primary(context),
              onPressed: onDetails,
              child: Text(l10n.forkSummaryDetails),
            ),
          ),
        if (onMore != null) ...[
          const SizedBox(height: BirdySpace.s),
          Pressable(
            child: OutlinedButton.icon(
              style: BirdyButtonStyles.secondary(context),
              icon: const Icon(AppIcons.moreHoriz),
              label: Text(l10n.forkSummaryMoreActions),
              onPressed: onMore,
            ),
          ),
        ],
      ],
    );
  }
}

/// « Écoute non enregistrée » with a save button (J6g-e): shown while the
/// listening is not in the library yet.
class UnsavedListeningNotice extends StatelessWidget {
  const UnsavedListeningNotice({super.key, required this.onSave});

  /// Null while a save is in flight.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(BirdySpace.l),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.forkSummaryUnsavedTitle,
                style: BirdyText.heading.copyWith(color: c.text1),
              ),
            ),
            const SizedBox(height: BirdySpace.xs),
            Text(
              l10n.forkSummaryUnsavedBody,
              style: BirdyText.body.copyWith(color: c.text2),
            ),
            const SizedBox(height: BirdySpace.m),
            Pressable(
              enabled: onSave != null,
              child: FilledButton(
                style: BirdyButtonStyles.primary(context),
                onPressed: onSave,
                child: Text(l10n.sessionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
