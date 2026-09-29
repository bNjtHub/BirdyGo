/// Blocks of the species page (J6c « Fiche espèce »,
/// fork/maquette/SPEC.md 9.13). Widgets only, no providers: the screen
/// wires them to the index, the geo-model and the other screens.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../design/activity_scale.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/clip_play_button.dart';
import '../ranking/activity_bars.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import '../reliability/reliability_screen.dart';
import 'section_title.dart';
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
    this.inSheet = false,
  });

  final String name;

  /// Null when the user hides scientific names.
  final String? latin;
  final SpeciesTint tint;

  /// Fills a 3:2 frame.
  final Widget photo;
  final VoidCallback onShare;

  /// Closes the page: back arrow on the full page, X inside a sheet, same
  /// place either way (J6g-e).
  final VoidCallback? onBack;

  /// Inside a sheet over a listening: adds the grab handle and swaps the
  /// back arrow for a close X.
  final bool inSheet;

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
                            icon:
                                inSheet
                                    ? AppIcons.close
                                    : AppIcons.arrowBackRounded,
                            semanticLabel:
                                inSheet
                                    ? MaterialLocalizations.of(
                                      context,
                                    ).closeButtonTooltip
                                    : MaterialLocalizations.of(
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
                  if (inSheet)
                    Positioned(
                      top: BirdySpace.xs,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ExcludeSemantics(
                          child: Container(
                            key: const ValueKey('fiche-grab-handle'),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              // Readable on any photo, light or dark.
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: Colors.black38,
                                width: 0.5,
                              ),
                            ),
                          ),
                        ),
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
    final tally = record.tally;
    return BirdyBlock(
      tone: BirdyBlockTone.sure,
      radius: BirdyRadii.hero,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tally != null) ...[
          Row(
            children: [
              Expanded(
                child: _HeardTile(
                  value: tally.contacts,
                  label: l10n.forkSummaryContactsLabel(tally.contacts),
                ),
              ),
              const SizedBox(width: BirdySpace.s),
              Expanded(
                child: _HeardTile(
                  value: tally.days,
                  label: l10n.forkRankingUnitDays(tally.days),
                ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
        ],
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
    ),
    );
  }

  /// Same first line as the real block (capped at 2 lines), a placeholder
  /// for the level badge and review count while [record] is still loading:
  /// whether that second row will show at all depends on data not in yet,
  /// so it is shown for real once the record lands, even if that means the
  /// block settles a little shorter.
  static Widget skeleton(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyBlock(
      tone: BirdyBlockTone.sure,
      radius: BirdyRadii.hero,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: BirdySpace.s),
              // Same height as the real tile at any text scale.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(BirdySpace.m),
                  child: _HeardTile._tileLine(
                    context,
                    BirdySkeleton.text(BirdyText.numberXL, placeholder: '00'),
                    BirdySkeleton.text(BirdyText.caption, placeholder: '000'),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: BirdySpace.m),
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
              placeholder: '00000000000000',
            ),
          ],
        ),
      ],
    ),
    );
  }
}

/// White tile of the hero: a number and its unit on one baseline.
class _HeardTile extends StatelessWidget {
  const _HeardTile({required this.value, required this.label});

  final int value;
  final String label;

  /// Number and unit on one baseline; stacked with large text, where the
  /// tile is too narrow for both on a line.
  static Widget _tileLine(BuildContext context, Widget number, Widget unit) {
    if (MediaQuery.textScalerOf(context).scale(1) > 1.15) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [number, const SizedBox(height: BirdySpace.xs), unit],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [number, const SizedBox(width: BirdySpace.s), Flexible(child: unit)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.inset),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.m),
        child: _tileLine(
          context,
          Text('$value', style: BirdyText.numberXL.copyWith(color: c.text1)),
          Text(label, style: BirdyText.caption.copyWith(color: c.text2)),
        ),
      ),
    );
  }
}

/// « Ici en ce moment »: the geo-model's sentence and the seasons chart
/// (twelve month bars, J6f-b fix: colored on the same sequential
/// Martin-pêcheur scale as the activity-by-hour chart, the current month
/// marked, and a peak/detail caption).
class HereNowCard extends StatefulWidget {
  const HereNowCard({
    super.key,
    required this.year,
    required this.sentence,
    required this.currentMonth,
    this.rareNote,
  });

  final YearPresence year;
  final String sentence;

  /// 1 to 12, marked on the chart.
  final int currentMonth;

  /// Why a detection is « Rare ici · à confirmer », shown when the species
  /// is unexpected here this week (J3b).
  final String? rareNote;

  @override
  State<HereNowCard> createState() => _HereNowCardState();
}

class _HereNowCardState extends State<HereNowCard> {
  int? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final months = widget.year.months;
    final percents = [for (final b in widget.year.bars) (b * 100).round()];
    final scale = ActivityScale.kingfisher(c.surface1);
    final initials = DateFormat.MMMM(language).dateSymbols.NARROWMONTHS;
    final crowded = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final labels = {
      for (final m in crowded ? const [0, 3, 6, 9] : List.generate(12, (i) => i))
        m: initials[m],
    };
    final selected = _selectedMonth;
    final caption =
        selected == null
            ? peakMonthCaption(l10n, language, months)
            : monthDetailCaption(l10n, language, selected + 1, percents[selected]);
    return BirdyBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: AppIcons.calendarToday, text: l10n.forkFicheHereNow),
          const SizedBox(height: BirdySpace.m),
          Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sentence,
                    style: BirdyText.bodyCompact.copyWith(color: c.text1),
                  ),
                  if (widget.rareNote != null) ...[
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
                            widget.rareNote!,
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
            SizedBox(
              width: 150,
              child: Column(
                children: [
                  ActivityBars(
                    values: percents,
                    // 36 px of bars plus the current month's dot strip.
                    height: 45,
                    colorForValue: scale.of,
                    trackColor: c.line,
                    labels: labels,
                    labelStyle: BirdyText.axisLabel,
                    highlightIndex: widget.currentMonth - 1,
                    highlightColor: c.text1,
                    semanticLabel: seasonsChartSemanticLabel(
                      l10n,
                      language,
                      months,
                    ),
                    onSelect:
                        (index, _) => setState(() => _selectedMonth = index),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: BirdyText.caption.copyWith(color: c.text2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ],
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
    return BirdyBlock(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionTitle(icon: AppIcons.hearing, text: l10n.forkFicheMySounds),
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
    ),
    );
  }

  /// Title row (real, static text) then [rows] placeholder recordings at
  /// the real row's own minimum height: how many recordings there really
  /// are is exactly what is still loading.
  static Widget skeleton(BuildContext context, {int rows = 2}) {
    final l10n = AppLocalizations.of(context)!;
    return BirdyBlock(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(icon: AppIcons.hearing, text: l10n.forkFicheMySounds),
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
    ),
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

/// Activity by hour and the mini map: two white blocks titled 20, stacked
/// (J6h).
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
    final mapBlock =
        map == null
            ? null
            : BirdyBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(icon: AppIcons.locationOn, text: l10n.forkFicheMapLabel),
                  const SizedBox(height: BirdySpace.m),
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
              ),
            );
    if (activity == null && mapBlock == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activity != null) activity,
        if (activity != null && mapBlock != null)
          const SizedBox(height: BirdySpace.block),
        if (mapBlock != null) mapBlock,
      ],
    );
  }

  /// Both blocks, like the real layout: whether the species turns out to
  /// have activity data or positioned contacts at all is exactly what is
  /// still loading, so this reserves the fuller case and settles down if
  /// the real content turns out smaller or absent.
  static Widget skeleton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BirdyBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: AppIcons.schedule, text: l10n.forkActivityByHour),
              const SizedBox(height: BirdySpace.m),
              BirdySkeleton.box(
                width: double.infinity,
                height: 52,
                radius: BirdyRadii.thumb,
              ),
              const SizedBox(height: BirdySpace.xs),
              // Reserves the peak-hour caption's line: whether one shows at
              // all depends on data not in yet.
              BirdySkeleton.text(
                BirdyText.caption,
                placeholder: '00000000000000000',
              ),
            ],
          ),
        ),
        const SizedBox(height: BirdySpace.block),
        BirdyBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: AppIcons.locationOn, text: l10n.forkFicheMapLabel),
              const SizedBox(height: BirdySpace.m),
              BirdySkeleton.box(
                width: double.infinity,
                height: 96,
                radius: BirdyRadii.inset,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: BirdySkeleton.text(
                  BirdyText.label,
                  placeholder: l10n.forkFicheSeeOnMap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Activity-by-hour block: bars colored on a sequential Martin-pêcheur
/// scale, hour labels every 6 h, the peak hour named in a caption, and a
/// tap/long-press on a bar showing its hour and count instead.
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
    return BirdyBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: AppIcons.schedule, text: l10n.forkActivityByHour),
          const SizedBox(height: BirdySpace.m),
          ActivityBars(
            values: widget.hours,
            height: 52,
            colorForValue: scale.of,
            trackColor: c.line,
            labels: const {0: '0 h', 6: '6 h', 12: '12 h', 18: '18 h'},
            labelStyle: BirdyText.axisLabel,
            semanticLabel: activityByHourSemanticLabel(l10n, widget.hours),
            onSelect: (index, _) => setState(() => _selectedHour = index),
          ),
          if (caption != null) ...[
            const SizedBox(height: BirdySpace.xs),
            Text(caption, style: BirdyText.caption.copyWith(color: c.text2)),
          ],
        ],
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Cut at the edge on purpose (J6f-b fix): it tells the row
          // scrolls, same treatment as the sheet chips above.
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final link in links) ...[
                if (link != links.first) const SizedBox(width: BirdySpace.s),
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
                      Text(link.label, maxLines: 1),
                      const SizedBox(width: BirdySpace.xs),
                      Icon(AppIcons.openInNew, size: 14, color: c.text2),
                    ],
                  ),
                  onPressed: () => onOpen(link.url),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
