/// Blocks of the species page (J6c « Fiche espèce »,
/// fork/maquette/SPEC.md 9.13). Widgets only, no providers: the screen
/// wires them to the index, the geo-model and the other screens.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../design/activity_scale.dart';
import '../design/birdy_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/clip_play_button.dart';
import '../design/widgets/dashed_border.dart';
import '../licenses/description_credit.dart';
import '../ranking/activity_bars.dart';
import '../species_photo/species_photo_config.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
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
    this.summary,
    this.heardLine,
    this.heardLoading = false,
    this.verified = false,
    this.precision,
    this.tags = const [],
  });

  /// Tag pills under the latin name (J7), in this order.
  final List<SpeciesTag> tags;

  /// The reliability badge and the « 37 bonnes sur 38 vérifiées » line that
  /// sit in the heard inset, under the heard line.
  final bool verified;
  final String? precision;

  final String name;

  /// One-sentence summary of the AI sheet, under the names; null without a
  /// sheet (J7 order: « Qui est-ce ? »).
  final String? summary;

  /// « Entendu 12 fois, dernière fois hier à 7 h 42 »: the user's own tally,
  /// first line of the heard inset. Null (and hidden) when never heard.
  final String? heardLine;

  /// The index has not answered yet: a one-line skeleton inset holds the
  /// place of [heardLine] from the first frame.
  final bool heardLoading;

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

  /// Placeholder of the heard inset: one line. Whether the level row shows
  /// under it depends on data not in yet, so the inset may settle a little
  /// taller once the record lands.
  static Widget _heardSkeleton() => BirdySkeleton.text(
    BirdyText.labelCompact,
    placeholder: '000000000000000000000000000000',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final background = c.isDark ? tint.tintDark : tint.tintLight;
    final ink = c.isDark ? c.text1 : BirdyBrand.ink;
    const radius = BorderRadius.vertical(
      bottom: Radius.circular(BirdyRadii.hero),
    );
    // FORK: J7 light status bar icons over the photo (indentation of the
    // body left as it was, to keep the merge diff small).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: BirdyBrand.clear,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ClipRRect(
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
                  // FORK: J7 scrim, so the status bar and the buttons read on
                  // any photo (light icons while the header is on screen).
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height:
                        MediaQuery.paddingOf(context).top + kPhotoTopScrimExtra,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const ValueKey('fiche-photo-top-scrim'),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              BirdyBrand.black.withValues(
                                alpha: BirdyAlpha.photoTopScrim,
                              ),
                              BirdyBrand.clear,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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
                                    ? BirdyIcons.close
                                    : BirdyIcons.back,
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
                            width: BirdyGlyph.disc40,
                            height: BirdySpace.xs,
                            decoration: BoxDecoration(
                              // Readable on any photo, light or dark.
                              color: BirdyBrand.white,
                              borderRadius: BorderRadius.circular(BirdyRadii.xs),
                              border: Border.all(
                                color: BirdyBrand.black38,
                                width: BirdyStroke.hairline / 2,
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
                  // The row is reserved from the first frame (one skeleton pill
                  // until the record says « Dans ton carnet » or not).
                  if (tags.isNotEmpty || heardLoading) ...[
                    const SizedBox(height: BirdySpace.s),
                    Wrap(
                      key: const ValueKey('fiche-tags'),
                      spacing: BirdySpace.xs + 2,
                      runSpacing: BirdySpace.xs + 2,
                      children: [
                        for (final tag in tags) _TagPill(tag: tag),
                        if (heardLoading && tags.isEmpty)
                          BirdySkeleton.box(
                            width: BirdySizes.skeletonTagM,
                            height: _kTagHeight,
                            radius: BirdyRadii.pill,
                          ),
                      ],
                    ),
                  ],
                  if (summary != null) ...[
                    const SizedBox(height: BirdySpace.s),
                    Text(
                      summary!,
                      style: BirdyText.bodyCompact.copyWith(color: ink),
                    ),
                  ],
                  // The heard inset (J7): in place from the first frame as a
                  // one-line skeleton; gone when never heard.
                  if (heardLoading || heardLine != null) ...[
                    const SizedBox(height: BirdySpace.m),
                    _HeardInset(
                      key: const ValueKey('fiche-heard'),
                      line: heardLine,
                      loading: heardLoading,
                      verified: verified,
                      precision: precision,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// What a tag pill of the header says (J7).
enum SpeciesTag { inBook, toDiscover, migrant, allYear, rare, uncommon }

/// Height of a tag pill.
const double _kTagHeight = 28;

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final SpeciesTag tag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final ink = c.isDark ? c.text1 : BirdyBrand.ink;
    final (label, icon, fill, fore, text) = switch (tag) {
      SpeciesTag.inBook => (
        l10n.forkFicheTagInBook,
        BirdyIcons.notebook,
        c.sure.background,
        c.sure.foreground,
        c.sure.foreground,
      ),
      SpeciesTag.toDiscover => (
        l10n.forkFicheTagToDiscover,
        BirdyIcons.heard,
        c.headerChip,
        c.toCheck.foreground,
        ink,
      ),
      SpeciesTag.migrant => (
        l10n.forkFicheTagMigrant,
        AppIcons.flight,
        c.headerChip,
        ink,
        ink,
      ),
      SpeciesTag.allYear => (
        l10n.forkFicheTagAllYear,
        AppIcons.home,
        c.headerChip,
        ink,
        ink,
      ),
      SpeciesTag.rare => (
        l10n.forkFicheTagRare,
        AppIcons.diamond,
        c.orioleContainer,
        c.orioleText,
        c.orioleText,
      ),
      SpeciesTag.uncommon => (
        l10n.forkFicheTagUncommon,
        AppIcons.visibility,
        c.headerChip,
        ink,
        ink,
      ),
    };
    final pill = Container(
      height: _kTagHeight,
      padding: const EdgeInsets.symmetric(horizontal: BirdySpace.s + 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(BirdyRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: BirdyGlyph.s, color: fore),
          const SizedBox(width: BirdySpace.xs),
          // Shrinks with an ellipsis rather than overflowing at large text.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BirdyText.badge.copyWith(color: text),
            ),
          ),
        ],
      ),
    );
    if (tag != SpeciesTag.toDiscover) return pill;
    // Dashed outline: not in the notebook yet (same mark as « À vérifier »).
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: c.toCheck.foreground,
        radius: _kTagHeight / 2,
      ),
      child: pill,
    );
  }
}

/// « Entendu 12 fois, dernière fois hier » with the reliability badge and
/// the precision line, in a translucent inset of the header.
class _HeardInset extends StatelessWidget {
  const _HeardInset({
    super.key,
    required this.line,
    required this.loading,
    required this.verified,
    required this.precision,
  });

  final String? line;
  final bool loading;
  final bool verified;
  final String? precision;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final ink = c.isDark ? c.text1 : BirdyBrand.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.m,
        vertical: BirdySpace.s + 2,
      ),
      decoration: BoxDecoration(
        color: c.headerInset,
        borderRadius: BorderRadius.circular(BirdyRadii.inset),
      ),
      child:
          loading
              ? KeyedSubtree(
                key: const ValueKey('fiche-heard-skeleton'),
                child: SpeciesPageHeader._heardSkeleton(),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: BirdySpace.xxs),
                        child: Icon(
                          BirdyIcons.heard,
                          size: BirdyGlyph.l,
                          color: c.sure.foreground,
                        ),
                      ),
                      const SizedBox(width: BirdySpace.s),
                      Expanded(
                        child: Text(
                          line!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BirdyText.labelCompact.copyWith(color: ink),
                        ),
                      ),
                    ],
                  ),
                  if (verified || precision != null) ...[
                    const SizedBox(height: BirdySpace.s),
                    Wrap(
                      spacing: BirdySpace.s,
                      runSpacing: BirdySpace.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (verified)
                          const ReliabilityBadge(level: ReliabilityLevel.sure),
                        if (precision != null)
                          Text(
                            precision!,
                            style: BirdyText.caption.copyWith(
                              color: c.isDark ? c.text2 : BirdyBrand.bark,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
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
    this.migration,
  });

  final YearPresence year;
  final String sentence;

  /// 1 to 12, marked on the chart.
  final int currentMonth;

  /// Why a detection is « Rare ici · à confirmer », shown when the species
  /// is unexpected here this week (J3b).
  final String? rareNote;

  /// Migration text of the AI sheet (J7): under the chart, after a rule.
  final String? migration;

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
    final scale = ActivityScale.kingfisher(c.surface1, hue: c.accent);
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
          SectionTitle(
            icon: AppIcons.calendarToday,
            text: l10n.forkFicheWhenToSee,
          ),
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
                          padding: const EdgeInsets.only(top: BirdySpace.xxs),
                          child: Icon(
                            AppIcons.diamond,
                            size: BirdyGlyph.s,
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
              width: BirdySizes.activityBarsWidth,
              child: Column(
                children: [
                  ActivityBars(
                    values: percents,
                    // 36 px of bars plus the current month's dot strip.
                    height: BirdySizes.activityBarsHeight,
                    colorForValue: scale.of,
                    trackColor: c.line,
                    labels: labels,
                    labelStyle: BirdyText.axisLabel,
                    highlightIndex: widget.currentMonth - 1,
                    highlightColor: c.text1,
                    selectedIndex: selected,
                    dimUnselected: true,
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
          if (widget.migration != null) ...[
            const SizedBox(height: BirdySpace.m),
            Divider(
              key: const ValueKey('fiche-migration-rule'),
              height: BirdyStroke.hairline,
              thickness: BirdyStroke.hairline,
              color: c.line,
            ),
            const SizedBox(height: BirdySpace.m),
            Row(
              key: const ValueKey('fiche-migration'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: BirdySpace.xxs),
                  child: Icon(
                    AppIcons.flight,
                    size: BirdyGlyph.l,
                    color: c.accentText,
                  ),
                ),
                const SizedBox(width: BirdySpace.s),
                Expanded(
                  child: Text(
                    widget.migration!,
                    style: BirdyText.bodyCompact.copyWith(color: c.text1),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// « Son chant » (J7): the reference song, the « À l'oreille » text and the
/// best recordings, in one block.
class SongBlock extends StatelessWidget {
  const SongBlock({
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
    this.byEar,
  });

  /// « À l'oreille » text of the AI sheet, under the title.
  final String? byEar;

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
    return BirdyBlock(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionTitle(
                icon: BirdyIcons.song,
                text: l10n.forkFicheGroupSong,
              ),
            ),
            if (onReference != null)
              FilledButton.icon(
                style: BirdyButtonStyles.tonal(context),
                onPressed: onReference,
                icon: const Icon(AppIcons.openInNew, size: BirdyGlyph.l),
                label: Text(l10n.forkFicheReferenceShort),
              ),
          ],
        ),
        if (byEar != null) ...[
          const SizedBox(height: BirdySpace.s),
          Text(
            byEar!,
            key: const ValueKey('fiche-by-ear'),
            style: BirdyText.bodyCompact.copyWith(
              color: BirdyColors.of(context).text1,
            ),
          ),
        ],
        for (var i = 0; i < clips.length; i++)
          _clipRow(context, clips[i], featured: i == 0),
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

  /// One recording. The first one leads the page (J7): the big play button
  /// of the cards where a replay is the main action, and a larger line.
  Widget _clipRow(
    BuildContext context,
    IndexedDetection clip, {
    required bool featured,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final isPlaying = playing == clip.clipPath;
    return Padding(
      padding: const EdgeInsets.only(top: BirdySpace.s),
      child: ConstrainedBox(
        key: featured ? const ValueKey('fiche-sounds-featured') : null,
        constraints: BoxConstraints(
          minHeight: featured ? BirdySizes.mainAction : 56,
        ),
        child: Row(
          children: [
            ClipPlayButton(
              size: featured ? BirdySizes.mainAction : BirdySizes.target,
              state: isPlaying ? ClipPlayState.playing : ClipPlayState.idle,
              semanticLabel: isPlaying ? l10n.forkReplayStop : l10n.forkReplay,
              onPressed: () => onPlay(clip),
            ),
            const SizedBox(width: BirdySpace.m),
            Expanded(
              child: Text(
                lineOf(clip),
                style: (featured ? BirdyText.body : BirdyText.bodyCompact)
                    .copyWith(
                      color: c.text1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
            _FavoriteButton(
              favorite: favorites.contains(clip.key),
              onPressed: () => onFavorite(clip, !favorites.contains(clip.key)),
            ),
          ],
        ),
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
        SectionTitle(icon: BirdyIcons.song, text: l10n.forkFicheGroupSong),
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
                    radius: BirdyRadii.chip,
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
        BirdyIcons.favorite,
        fill: favorite ? 1 : 0,
        color: favorite ? BirdyBrand.oriole : c.text2,
      ),
    );
  }
}

/// Upstream description when there is no AI sheet (other languages, or a
/// species without one), with its source.
class DescriptionBlock extends StatelessWidget {
  const DescriptionBlock({
    super.key,
    required this.text,
    this.source,
    this.wikipediaUrl,
  });

  final String text;
  final String? source;

  /// Wikipedia page of the species, linked in the credit.
  final String? wikipediaUrl;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: BirdyText.bodyCompact.copyWith(color: c.text1)),
        if (source != null) ...[
          const SizedBox(height: BirdySpace.xs),
          DescriptionCredit(source: source!, wikipediaUrl: wikipediaUrl),
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
                  SectionTitle(icon: BirdyIcons.map, text: l10n.forkFicheMapLabel),
                  const SizedBox(height: BirdySpace.m),
                  SizedBox(height: BirdyGlyph.disc96, child: map),
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
                height: BirdySizes.hourBarsHeight,
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
              SectionTitle(icon: BirdyIcons.map, text: l10n.forkFicheMapLabel),
              const SizedBox(height: BirdySpace.m),
              BirdySkeleton.box(
                width: double.infinity,
                height: BirdyGlyph.disc96,
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
    final scale = ActivityScale.kingfisher(c.surface1, hue: c.accent);
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
            height: BirdySizes.hourBarsHeight,
            colorForValue: scale.of,
            trackColor: c.line,
            labels: const {0: '0 h', 6: '6 h', 12: '12 h', 18: '18 h'},
            labelStyle: BirdyText.axisLabel,
            selectedIndex: selected,
            dimUnselected: true,
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

/// « Pour aller plus loin » (J7): one block, one title, the links as
/// 48 dp pills.
class GoFurtherBlock extends StatelessWidget {
  const GoFurtherBlock({super.key, required this.links, required this.onOpen});

  final List<SpeciesLink> links;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BirdyBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            icon: BirdyIcons.world,
            text: l10n.forkFicheGroupGoFurther,
          ),
          const SizedBox(height: BirdySpace.m),
          LinksBlock(links: links, onOpen: onOpen, showLabel: false),
        ],
      ),
    );
  }
}

/// One pill per page (eBird, iNaturalist, Wikipédia), 48 dp high.
class LinksBlock extends StatelessWidget {
  const LinksBlock({
    super.key,
    required this.links,
    required this.onOpen,
    this.showLabel = true,
  });

  /// False when a block title above already says it (J7).
  final bool showLabel;

  final List<SpeciesLink> links;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    // Mist on light; the raised surface on dark (Mist would glare there).
    final fill = c.isDark ? c.surface2 : BirdyBrand.mist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            // Short on purpose: on one line even at 130 % text (J6f-b fix).
            l10n.forkFicheLearnMore,
            maxLines: 1,
            style: BirdyText.label.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.s),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Cut at the edge on purpose (J6f-b fix): it tells the row scrolls.
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final link in links) ...[
                if (link != links.first) const SizedBox(width: BirdySpace.s),
                _LinkPill(link: link, fill: fill, onOpen: onOpen),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({
    required this.link,
    required this.fill,
    required this.onOpen,
  });

  final SpeciesLink link;
  final Color fill;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Material(
      color: fill,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(link.url),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BirdySpace.m),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  link.iconAsset,
                  width: BirdySpace.roomy,
                  height: BirdySpace.roomy,
                  errorBuilder: (_, _, _) => const Icon(BirdyIcons.world),
                ),
                const SizedBox(width: BirdySpace.s),
                Text(
                  link.label,
                  maxLines: 1,
                  style: BirdyText.label.copyWith(
                    color: c.text1,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: BirdySpace.xs),
                Icon(AppIcons.openInNew, size: BirdyGlyph.s, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
