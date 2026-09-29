/// « Fais sa connaissance » (J6h): the species sheet as six round discs,
/// one content card under them, and the link to the quiz. Replaces the old
/// chip row. State is ephemeral: it resets each time the page opens.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../game/game_widgets.dart' show SegmentedBar;
import '../game/quiz_entry_row.dart';
import '../species_sheet/species_sheet.dart';
import '../species_sheet/species_sheet_section.dart' show sheetSectionTitle;
import 'section_title.dart';

/// The six sections, in display order (a subset of [SheetSection]).
const List<SheetSection> kMeetSections = [
  SheetSection.byEar,
  SheetSection.size,
  SheetSection.behaviour,
  SheetSection.migration,
  SheetSection.enemies,
  SheetSection.anecdote,
];

/// Sections of [sheet] that have content, in display order.
List<SheetSection> meetAvailable(SpeciesSheet sheet) => [
  for (final s in kMeetSections)
    if (sheet.sections.containsKey(s)) s,
];

/// Discs per row of the grid.
const int _kMeetColumns = 3;

/// Meaning of the tint of a section (DESIGN.md: tonal learn, sure acquired,
/// oriole reward).
enum _Tone { tonal, sure, probable, oriole }

const Map<SheetSection, _Tone> _tones = {
  SheetSection.byEar: _Tone.tonal,
  SheetSection.size: _Tone.sure,
  SheetSection.behaviour: _Tone.tonal,
  SheetSection.migration: _Tone.sure,
  SheetSection.enemies: _Tone.probable,
  SheetSection.anecdote: _Tone.oriole,
};

IconData _iconOf(SheetSection s) => switch (s) {
  SheetSection.byEar => AppIcons.hearing,
  SheetSection.size => AppIcons.straighten,
  SheetSection.behaviour => AppIcons.visibility,
  SheetSection.migration => AppIcons.flight,
  SheetSection.enemies => AppIcons.pets,
  _ => AppIcons.lightbulbOutline,
};

String _labelOf(AppLocalizations l10n, SheetSection s) => switch (s) {
  SheetSection.byEar => l10n.forkMeetByEar,
  SheetSection.size => l10n.forkMeetSize,
  SheetSection.behaviour => l10n.forkSheetHabits,
  SheetSection.migration => l10n.forkMeetMigration,
  SheetSection.enemies => l10n.forkSheetEnemies,
  _ => l10n.forkMeetAnecdote,
};

String _hookOf(AppLocalizations l10n, SheetSection s) => switch (s) {
  SheetSection.byEar => l10n.forkMeetHookByEar,
  SheetSection.size => l10n.forkMeetHookSize,
  SheetSection.behaviour => l10n.forkMeetHookBehaviour,
  SheetSection.migration => l10n.forkMeetHookMigration,
  SheetSection.enemies => l10n.forkSheetEnemiesKicker,
  _ => l10n.forkMeetHookAnecdote,
};

/// Sections outside the five discs, shown as their own tinted blocks so
/// nothing of the sheet is lost (J6h fix).
const List<SheetSection> kMeetExtras = [
  SheetSection.whyHere,
  SheetSection.confusions,
];

IconData _extraIcon(SheetSection s) =>
    s == SheetSection.whyHere ? AppIcons.locationOn : AppIcons.swapHoriz;

/// A section of the sheet as a tonal block: species-tint icon disc, 20
/// title, then the text.
class _MeetExtraBlock extends StatelessWidget {
  const _MeetExtraBlock({super.key, required this.section, required this.text});

  final SheetSection section;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return BirdyBlock(
      tone: BirdyBlockTone.tonal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            icon: _extraIcon(section),
            text: sheetSectionTitle(l10n, section),
          ),
          const SizedBox(height: BirdySpace.m),
          Text(text, style: BirdyText.body.copyWith(color: c.text1)),
        ],
      ),
    );
  }
}

/// The extra sections of [sheet] that have content, each with a gap above.
List<Widget> _extraBlocks(SpeciesSheet sheet) => [
  for (final s in kMeetExtras)
    if (sheet.sections[s] != null) ...[
      const SizedBox(height: BirdySpace.block),
      _MeetExtraBlock(
        key: ValueKey('meet-extra-${s.key}'),
        section: s,
        text: sheet.sections[s]!,
      ),
    ],
];

/// Fill and foreground of a tone on the current theme.
({Color fill, Color fore}) _colors(BirdyColors c, _Tone t) => switch (t) {
  _Tone.tonal => (fill: c.tonal, fore: c.accentText),
  _Tone.sure => (fill: c.sure.background, fore: c.sure.foreground),
  _Tone.probable => (fill: c.probable.background, fore: c.probable.foreground),
  _Tone.oriole => (fill: c.orioleContainer, fore: c.orioleText),
};

class MeetSpeciesBlock extends StatefulWidget {
  const MeetSpeciesBlock({super.key, required this.sheet, this.onQuizTap});

  final SpeciesSheet sheet;

  /// Overrides opening the quiz (tests).
  final VoidCallback? onQuizTap;

  @override
  State<MeetSpeciesBlock> createState() => _MeetSpeciesBlockState();
}

class _MeetSpeciesBlockState extends State<MeetSpeciesBlock> {
  int _index = 0;
  final Set<SheetSection> _read = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final sections = meetAvailable(widget.sheet);
    final summary = widget.sheet.sections[SheetSection.summary];
    if (sections.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary != null)
            BirdyBlock(
              child: Text(
                summary,
                style: BirdyText.bodyCompact.copyWith(color: c.text2),
              ),
            ),
          ..._extraBlocks(widget.sheet),
          const SizedBox(height: BirdySpace.block),
          QuizEntryRow(
            subtitle: l10n.forkMeetQuizSubtitle,
            onTap: widget.onQuizTap,
          ),
        ],
      );
    }
    final index = _index.clamp(0, sections.length - 1);
    final current = sections[index];
    // The section on show counts as read as soon as it is shown.
    final read = {..._read, current};
    final last = index == sections.length - 1;
    final colors = _colors(c, _tones[current]!);
    final reduced = BirdyMotion.reduced(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BirdyBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l10n.forkMeetTitle,
                      style: BirdyText.heading.copyWith(color: c.text1),
                    ),
                  ),
                  const SizedBox(width: BirdySpace.s),
                  Text(
                    l10n.forkMeetCount(read.length, sections.length),
                    style: BirdyText.badge.copyWith(color: c.accentText),
                  ),
                ],
              ),
              if (summary != null) ...[
                const SizedBox(height: BirdySpace.s),
                Text(
                  summary,
                  style: BirdyText.bodyCompact.copyWith(color: c.text2),
                ),
              ],
              const SizedBox(height: BirdySpace.l),
              // 3 columns: six sections make a 3 x 2 grid.
              for (var r = 0; r < sections.length; r += _kMeetColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = r; i < r + _kMeetColumns; i++)
                      Expanded(
                        child:
                            i < sections.length
                                ? _MeetDisc(
                                  key: ValueKey('meet-disc-${sections[i].key}'),
                                  section: sections[i],
                                  selected: i == index,
                                  read: read.contains(sections[i]),
                                  onTap:
                                      () => setState(() {
                                        _read.add(current);
                                        _index = i;
                                      }),
                                )
                                : const SizedBox.shrink(),
                      ),
                  ],
                ),
              const SizedBox(height: BirdySpace.l),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.fill,
                  borderRadius: BorderRadius.circular(BirdyRadii.card),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BirdyRadii.card),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -BirdySpace.s,
                        bottom: -BirdySpace.s,
                        child: ExcludeSemantics(
                          child: Icon(
                            _iconOf(current),
                            size: BirdySizes.knowledgeWatermark,
                            fill: 1,
                            color: colors.fore.withValues(
                              alpha: BirdyAlpha.knowledgeWatermark,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(BirdySpace.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSwitcher(
                              duration:
                                  reduced ? Duration.zero : BirdyMotion.exit,
                              layoutBuilder:
                                  (cur, prev) => Stack(
                                    alignment: Alignment.topLeft,
                                    children: [...prev, if (cur != null) cur],
                                  ),
                              child: Column(
                                key: ValueKey(current),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _hookOf(l10n, current),
                                    style: BirdyText.badge.copyWith(
                                      color: colors.fore,
                                    ),
                                  ),
                                  const SizedBox(height: BirdySpace.s),
                                  Text(
                                    widget.sheet.sections[current]!,
                                    style: BirdyText.body.copyWith(
                                      color: c.text1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: BirdySpace.l),
                            SegmentedBar(
                              count: sections.length,
                              filled: index + 1,
                              color: colors.fore,
                              track: birdyTrackOnTint(c),
                              height: BirdySizes.knowledgeSegment,
                            ),
                            const SizedBox(height: BirdySpace.m),
                            _MeetButton(
                              key: const ValueKey('meet-next'),
                              label:
                                  last
                                      ? l10n.forkMeetReplay
                                      : l10n.forkMeetNext,
                              trailing:
                                  last ? null : AppIcons.arrowForwardRounded,
                              onPressed:
                                  () => setState(() {
                                    _read.add(current);
                                    _index = last ? 0 : index + 1;
                                  }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BirdySpace.m),
              Text(
                l10n.forkSheetFooter,
                style: BirdyText.caption.copyWith(color: c.text2),
              ),
            ],
          ),
        ),
        ..._extraBlocks(widget.sheet),
        const SizedBox(height: BirdySpace.block),
        QuizEntryRow(
          subtitle: l10n.forkMeetQuizSubtitle,
          onTap: widget.onQuizTap,
        ),
      ],
    );
  }
}

/// Round disc of a section with its label; a ring when chosen, a Lichen
/// check in the corner when read.
class _MeetDisc extends StatelessWidget {
  const _MeetDisc({
    super.key,
    required this.section,
    required this.selected,
    required this.read,
    required this.onTap,
  });

  final SheetSection section;
  final bool selected;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final colors = _colors(c, _tones[section]!);
    const ring = BirdySizes.knowledgeRing;
    final label = _labelOf(l10n, section);
    return Semantics(
      button: true,
      selected: selected,
      label: read ? '$label, ${l10n.forkMeetRead}' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Same footprint chosen or not: the ring only changes color.
                  Container(
                    padding: const EdgeInsets.all(ring),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? colors.fore : Colors.transparent,
                        width: ring,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(ring),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? c.surface1 : Colors.transparent,
                      ),
                      child: Container(
                        width: BirdySizes.knowledgeDisc,
                        height: BirdySizes.knowledgeDisc,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? colors.fill : c.background,
                        ),
                        child: Icon(
                          _iconOf(section),
                          color: colors.fore,
                          fill: selected ? 1 : 0,
                        ),
                      ),
                    ),
                  ),
                  if (read)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        key: ValueKey('meet-read-${section.key}'),
                        width: BirdySizes.knowledgeCheck,
                        height: BirdySizes.knowledgeCheck,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.sure.foreground,
                          border: Border.all(color: c.surface1, width: 1.5),
                        ),
                        child: Icon(
                          AppIcons.check,
                          size: BirdySizes.knowledgeCheck - 6,
                          color: c.surface1,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: BirdySpace.xs),
              // A long label shrinks to fit its column at 13 and large text scales.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: BirdyText.caption.copyWith(
                    color: c.text1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White button on the tinted card.
class _MeetButton extends StatelessWidget {
  const _MeetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
  });

  final String label;
  final IconData? trailing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: c.surface1,
        foregroundColor: c.text1,
        minimumSize: const Size.fromHeight(BirdySizes.target),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: BirdyText.labelCompact),
          if (trailing != null) ...[
            const SizedBox(width: BirdySpace.s),
            Icon(trailing, size: 20),
          ],
        ],
      ),
    );
  }
}
