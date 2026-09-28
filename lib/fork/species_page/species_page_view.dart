/// Blocks of the species page (J6c « Fiche espèce »,
/// fork/maquette/SPEC.md 9.13). Widgets only, no providers: the screen
/// wires them to the index, the geo-model and the other screens.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../design/activity_scale.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/clip_play_button.dart';
import '../ranking/activity_bars.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import '../reliability/reliability_screen.dart';
import '../species_sheet/species_sheet.dart';
import '../species_sheet/species_sheet_section.dart';
import 'species_page_model.dart';
import 'species_page_text.dart';

/// Widest column on tablets and in landscape.
const double kSpeciesPageMaxWidth = 600;

/// Tinted header: photo edge to edge, then the names.
class SpeciesPageHeader extends StatelessWidget {
  const SpeciesPageHeader({
    super.key,
    required this.name,
    required this.latin,
    required this.tint,
    required this.photo,
    required this.onShare,
    this.onBack,
  });

  final String name;

  /// Null when the user hides scientific names.
  final String? latin;
  final SpeciesTint tint;

  /// Fills a 3:2 frame.
  final Widget photo;
  final VoidCallback onShare;

  /// Null inside a sheet (the sheet has its drag handle).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final background = c.isDark ? tint.tintDark : tint.tintLight;
    final ink = c.isDark ? c.text1 : BirdyBrand.ink;
    const radius = BorderRadius.vertical(
      bottom: Radius.circular(BirdyRadii.hero),
    );
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo,
                  Positioned(
                    top: BirdySpace.l + MediaQuery.paddingOf(context).top,
                    left: BirdySpace.l,
                    right: BirdySpace.l,
                    child: Row(
                      children: [
                        if (onBack != null)
                          BirdyIconButton(
                            icon: AppIcons.arrowBackRounded,
                            semanticLabel:
                                MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                            onPressed: onBack,
                          ),
                        const Spacer(),
                        BirdyIconButton(
                          icon: AppIcons.share,
                          semanticLabel: l10n.forkSummaryShare,
                          onPressed: onShare,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.gutter,
                BirdySpace.m,
                BirdySpace.gutter,
                BirdySpace.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      name,
                      style: BirdyText.display.copyWith(color: ink),
                    ),
                  ),
                  if (latin != null)
                    Text(
                      latin!,
                      style: BirdyText.latin.copyWith(
                        color: c.isDark ? c.text2 : BirdyBrand.bark,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Entendu 142 fois sur 38 jours… », then the level and the reviews.
class HeardBlock extends StatelessWidget {
  const HeardBlock({super.key, required this.record, required this.heard});

  final SpeciesRecord record;

  /// The sentence, null when never heard.
  final String? heard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final precision = precisionLine(l10n, record.confirmed, record.reviewed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capped so its loading skeleton (HeardBlock.skeleton below) can
        // reserve a fixed number of lines instead of however many contacts
        // and days happen to wrap to.
        Text(
          heard ?? l10n.forkFicheNeverHeard,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: BirdyText.body.copyWith(color: c.text1),
        ),
        if (record.verified || precision != null) ...[
          const SizedBox(height: BirdySpace.s),
          Wrap(
            spacing: BirdySpace.s,
            runSpacing: BirdySpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (record.verified)
                const ReliabilityBadge(level: ReliabilityLevel.sure),
              if (precision != null)
                Text(
                  precision,
                  style: BirdyText.caption.copyWith(color: c.text2),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Same first line as the real block (capped at 2 lines), a placeholder
  /// for the level badge and review count while [record] is still loading:
  /// whether that second row will show at all depends on data not in yet,
  /// so it is shown for real once the record lands, even if that means the
  /// block settles a little shorter.
  static Widget skeleton(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BirdySkeleton.text(
          BirdyText.body.copyWith(color: c.text1),
          placeholder:
              '00000000000000000000000000000000000000000000000000000000',
          maxLines: 2,
        ),
        const SizedBox(height: BirdySpace.s),
        Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BirdySkeleton.box(width: 88, height: 26, radius: BirdyRadii.pill),
            BirdySkeleton.text(
              BirdyText.caption,
              placeholder: '00000000000000000000000',
            ),
          ],
        ),
      ],
    );
  }
}

/// « Ici en ce moment »: the geo-model's sentence and twelve month bars.
class HereNowCard extends StatelessWidget {
  const HereNowCard({
    super.key,
    required this.year,
    required this.sentence,
    required this.monthsCaption,
    required this.currentMonth,
    this.rareNote,
  });

  final YearPresence year;
  final String sentence;
  final String monthsCaption;

  /// 1 to 12, highlighted.
  final int currentMonth;

  /// Why a detection is « Rare ici · à confirmer », shown when the species
  /// is unexpected here this week (J3b).
  final String? rareNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final bars = year.bars;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BirdySpace.l,
          vertical: BirdySpace.m,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.forkFicheHereNow,
                    style: BirdyText.label.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    sentence,
                    style: BirdyText.bodyCompact.copyWith(color: c.text1),
                  ),
                  if (rareNote != null) ...[
                    const SizedBox(height: BirdySpace.s),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            AppIcons.diamond,
                            size: 14,
                            fill: 1,
                            color: c.orioleText,
                          ),
                        ),
                        const SizedBox(width: BirdySpace.xs),
                        Expanded(
                          child: Text(
                            rareNote!,
                            style: BirdyText.bodyCompact.copyWith(
                              color: c.orioleText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: BirdySpace.m),
            Semantics(
              label: l10n.forkFichePresenceChart,
              excludeSemantics: true,
              child: Column(
                children: [
                  SizedBox(
                    height: 36,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var m = 0; m < 12; m++) ...[
                          if (m > 0) const SizedBox(width: 3),
                          Container(
                            key: ValueKey('month-bar-$m'),
                            width: 6,
                            height: (36 * bars[m]).clamp(3, 36).toDouble(),
                            decoration: BoxDecoration(
                              color:
                                  m + 1 == currentMonth
                                      ? BirdyBrand.kingfisher
                                      : c.line,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    monthsCaption,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Mes sons »: the reference song and the best recordings.
class MySoundsBlock extends StatelessWidget {
  const MySoundsBlock({
    super.key,
    required this.clips,
    required this.favorites,
    required this.playing,
    required this.lineOf,
    required this.onPlay,
    required this.onFavorite,
    this.onReference,
    this.moreCount = 0,
    this.onMore,
  });

  final List<IndexedDetection> clips;
  final Set<String> favorites;

  /// Path of the clip playing, or null.
  final String? playing;
  final String Function(IndexedDetection clip) lineOf;
  final ValueChanged<IndexedDetection> onPlay;
  final void Function(IndexedDetection clip, bool favorite) onFavorite;

  /// Opens the reference song (eBird). Null without one.
  final VoidCallback? onReference;

  /// Every recording of the species, for the « Voir les N » link.
  final int moreCount;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.forkFicheMySounds,
                style: BirdyText.heading.copyWith(color: c.text1),
              ),
            ),
            if (onReference != null)
              FilledButton.icon(
                style: BirdyButtonStyles.tonal(context),
                onPressed: onReference,
                icon: const Icon(AppIcons.openInNew, size: 18),
                label: Text(l10n.forkFicheReference),
              ),
          ],
        ),
        for (final clip in clips)
          Padding(
            padding: const EdgeInsets.only(top: BirdySpace.s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  ClipPlayButton(
                    state:
                        playing == clip.clipPath
                            ? ClipPlayState.playing
                            : ClipPlayState.idle,
                    semanticLabel:
                        playing == clip.clipPath
                            ? l10n.forkReplayStop
                            : l10n.forkReplay,
                    onPressed: () => onPlay(clip),
                  ),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: Text(
                      lineOf(clip),
                      style: BirdyText.bodyCompact.copyWith(
                        color: c.text1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _FavoriteButton(
                    favorite: favorites.contains(clip.key),
                    onPressed:
                        () => onFavorite(clip, !favorites.contains(clip.key)),
                  ),
                ],
              ),
            ),
          ),
        if (onMore != null && moreCount > clips.length)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onMore,
              child: Text(l10n.forkFicheAllSounds(moreCount)),
            ),
          ),
      ],
    );
  }

  /// Title row (real, static text) then [rows] placeholder recordings at
  /// the real row's own minimum height: how many recordings there really
  /// are is exactly what is still loading.
  static Widget skeleton(BuildContext context, {int rows = 2}) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.forkFicheMySounds,
          style: BirdyText.heading.copyWith(color: c.text1),
        ),
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(top: BirdySpace.s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  BirdySkeleton.box(
                    width: BirdySizes.target,
                    height: BirdySizes.target,
                    radius: BirdySizes.target / 2,
                  ),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: BirdySkeleton.text(
                      BirdyText.bodyCompact,
                      placeholder: '00000000000000000000000000',
                    ),
                  ),
                  BirdySkeleton.box(
                    width: BirdySizes.target,
                    height: BirdySizes.target,
                    radius: 8,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.favorite, required this.onPressed});

  final bool favorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip:
          favorite
              ? l10n.forkSoundLibraryUnfavorite
              : l10n.forkSoundLibraryFavorite,
      isSelected: favorite,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(BirdySizes.target),
      ),
      icon: Icon(
        AppIcons.star,
        fill: favorite ? 1 : 0,
        color: favorite ? BirdyBrand.oriole : c.text2,
      ),
    );
  }
}

/// The AI sheet: summary as lead, one chip per section, the chosen
/// paragraph, and the AI notice.
class SheetChipsBlock extends StatefulWidget {
  const SheetChipsBlock({super.key, required this.sheet});

  final SpeciesSheet sheet;

  @override
  State<SheetChipsBlock> createState() => _SheetChipsBlockState();
}

class _SheetChipsBlockState extends State<SheetChipsBlock> {
  SheetSection? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final chips = sheetChips(widget.sheet);
    final selected = chips.contains(_selected) ? _selected! : chips.firstOrNull;
    final summary = widget.sheet.sections[SheetSection.summary];
    final text = selected == null ? null : widget.sheet.sections[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null) ...[
          Text(summary, style: BirdyText.body.copyWith(color: c.text1)),
          const SizedBox(height: BirdySpace.m),
        ],
        if (chips.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Cut at the edge on purpose: it tells the row scrolls.
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final section in chips) ...[
                  if (section != chips.first)
                    const SizedBox(width: BirdySpace.s),
                  _SheetChip(
                    label: sheetSectionTitle(l10n, section),
                    selected: section == selected,
                    onPressed: () => setState(() => _selected = section),
                  ),
                ],
              ],
            ),
          ),
        if (text != null) ...[
          const SizedBox(height: BirdySpace.m),
          AnimatedSwitcher(
            duration:
                BirdyMotion.reduced(context) ? Duration.zero : BirdyMotion.exit,
            layoutBuilder:
                (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, if (current != null) current],
                ),
            child: Text(
              text,
              key: ValueKey(selected),
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
          ),
        ],
        const SizedBox(height: BirdySpace.s),
        Text(
          l10n.forkSheetFooter,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
      ],
    );
  }
}

/// Filter chip of SPEC.md 5.10: ink fill and check when selected.
class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final background = selected ? c.text1 : c.surface1;
    final foreground = selected ? c.background : c.text1;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? c.text1 : c.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BirdySizes.target),
            child: Padding(
              padding: EdgeInsets.only(
                left: selected ? BirdySpace.m : BirdySpace.l,
                right: BirdySpace.l,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(AppIcons.check, size: 18, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: BirdyText.label.copyWith(color: foreground),
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

/// Upstream description when there is no AI sheet (other languages, or a
/// species without one), with its source.
class DescriptionBlock extends StatelessWidget {
  const DescriptionBlock({super.key, required this.text, this.source});

  final String text;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: BirdyText.bodyCompact.copyWith(color: c.text1)),
        if (source != null) ...[
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.speciesDescriptionSource(source!),
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
        ],
      ],
    );
  }
}

/// Activity by hour and the mini map, side by side (or stacked when narrow
/// or with large text).
class ActivityAndMap extends StatelessWidget {
  const ActivityAndMap({super.key, required this.hours, this.map, this.onSeeOnMap});

  /// 24 values, or empty.
  final List<int> hours;

  /// The mini map, null without positioned contacts.
  final Widget? map;
  final VoidCallback? onSeeOnMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activity = hours.any((h) => h > 0) ? _HourActivityCard(hours: hours) : null;
    final mapColumn =
        map == null
            ? null
            : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 96, child: map),
                if (onSeeOnMap != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onSeeOnMap,
                      child: Text(l10n.forkFicheSeeOnMap),
                    ),
                  ),
              ],
            );
    if (activity == null && mapColumn == null) return const SizedBox.shrink();
    if (activity == null) return mapColumn!;
    if (mapColumn == null) return activity;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (large || constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              activity,
              const SizedBox(height: BirdySpace.m),
              mapColumn,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: activity),
            const SizedBox(width: BirdySpace.m),
            Expanded(child: mapColumn),
          ],
        );
      },
    );
  }

  /// Both the chart and the map area, side by side like the real layout:
  /// whether the species turns out to have activity data or positioned
  /// contacts at all is exactly what is still loading, so this reserves the
  /// fuller case and settles down if the real content turns out smaller or
  /// absent (see `ActivityAndMap`'s own `null` cases).
  static Widget skeleton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final activity = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BirdySkeleton.text(
              BirdyText.caption,
              placeholder: l10n.forkActivityByHour,
            ),
            const SizedBox(height: BirdySpace.s),
            BirdySkeleton.box(
              width: double.infinity,
              height: 52,
              radius: BirdyRadii.thumb,
            ),
            const SizedBox(height: BirdySpace.xs),
            // Reserves the peak-hour caption's line (J6f-b fix): whether
            // one shows at all depends on data not in yet.
            BirdySkeleton.text(
              BirdyText.caption,
              placeholder: '00000000000000000',
            ),
          ],
        ),
      ),
    );
    final mapColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BirdySkeleton.box(
          width: double.infinity,
          height: 96,
          radius: BirdyRadii.card,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: BirdySkeleton.text(
            BirdyText.label,
            placeholder: l10n.forkFicheSeeOnMap,
          ),
        ),
      ],
    );
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (large || constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              activity,
              const SizedBox(height: BirdySpace.m),
              mapColumn,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: activity),
            const SizedBox(width: BirdySpace.m),
            Expanded(child: mapColumn),
          ],
        );
      },
    );
  }
}

/// Activity-by-hour card (J6f-b fix): bars colored on a sequential
/// Martin-pêcheur scale, hour labels every 6 h, the peak hour named in a
/// caption, and a tap/long-press on a bar showing its hour and count
/// instead.
class _HourActivityCard extends StatefulWidget {
  const _HourActivityCard({required this.hours});

  /// 24 values, at least one above zero.
  final List<int> hours;

  @override
  State<_HourActivityCard> createState() => _HourActivityCardState();
}

class _HourActivityCardState extends State<_HourActivityCard> {
  int? _selectedHour;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final scale = ActivityScale.kingfisher(c.surface1);
    final selected = _selectedHour;
    final caption =
        selected == null
            ? peakHourCaption(l10n, widget.hours)
            : hourDetailCaption(l10n, selected, widget.hours[selected]);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.forkActivityByHour,
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
            const SizedBox(height: BirdySpace.s),
            ActivityBars(
              values: widget.hours,
              height: 52,
              colorForValue: scale.of,
              trackColor: c.line,
              labels: const {0: '0 h', 6: '6 h', 12: '12 h', 18: '18 h'},
              semanticLabel: activityByHourSemanticLabel(l10n, widget.hours),
              onSelect: (index, _) => setState(() => _selectedHour = index),
            ),
            if (caption != null) ...[
              const SizedBox(height: BirdySpace.xs),
              Text(caption, style: BirdyText.caption.copyWith(color: c.text2)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Last lines: the ethics reminder.
class SpeciesPageFooter extends StatelessWidget {
  const SpeciesPageFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Text(
      l10n.forkFicheEthics,
      style: BirdyText.caption.copyWith(color: c.text2),
    );
  }
}

/// An external page about the species (eBird, iNaturalist, Wikipédia).
typedef SpeciesLink = ({String label, String iconAsset, String url});

/// « En savoir plus sur cette espèce » and one chip per page.
class LinksBlock extends StatelessWidget {
  const LinksBlock({super.key, required this.links, required this.onOpen});

  final List<SpeciesLink> links;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // Short on purpose: on one line even at 130 % text (J6f-b fix).
          l10n.forkFicheLearnMore,
          maxLines: 1,
          style: BirdyText.label.copyWith(color: c.text1),
        ),
        const SizedBox(height: BirdySpace.s),
        Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.s,
          children: [
            for (final link in links)
              ActionChip(
                avatar: Image.asset(
                  link.iconAsset,
                  width: 18,
                  height: 18,
                  errorBuilder: (_, _, _) => const Icon(AppIcons.public),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(link.label),
                    const SizedBox(width: BirdySpace.xs),
                    Icon(AppIcons.openInNew, size: 14, color: c.text2),
                  ],
                ),
                onPressed: () => onOpen(link.url),
              ),
          ],
        ),
      ],
    );
  }
}
