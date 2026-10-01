/// « Dans le monde » block of the species page (J7): the seasonal range of
/// the species on a world map, from the geo-model. Widgets only: the screen
/// wires the data (see `WorldMapSection`).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../species_page/section_title.dart';
import '../species_page/species_page_text.dart';
import '../species_sheet/species_sheet.dart';
import 'gbif_map.dart';
import 'land_outline.dart';
import 'season_legend.dart';
import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';
import 'world_map_painter.dart';
import 'world_map_text.dart';

class WorldMapBlock extends StatefulWidget {
  const WorldMapBlock({
    super.key,
    required this.outline,
    required this.presence,
    required this.currentMonth,
    this.user,
    this.nesting,
    this.source = WorldMapSource.geomodel,
    this.onGbifTap,
    this.onLicenseTap,
    this.onOnlineHintTap,
  });

  final LandOutline outline;
  final SeasonPresence presence;

  /// GBIF observations or the geo-model estimate: sets the key and the
  /// mention under the map.
  final WorldMapSource source;

  /// Open GBIF's site, and the licenses page that cites it.
  final VoidCallback? onGbifTap;
  final VoidCallback? onLicenseTap;

  /// Shown under the geo-model map when the online map is off: opens the
  /// setting. Null hides the line.
  final VoidCallback? onOnlineHintTap;

  /// 1 to 12: the season shown first.
  final int currentMonth;

  /// Where the user is, when known.
  final GridCell? user;

  /// From the AI sheet, when there is one.
  final NestingPeriod? nesting;

  /// Same shape as the loaded block: title, season chips, map, legend.
  static Widget skeleton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BirdyBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: AppIcons.public, text: l10n.forkWorldTitle),
          const SizedBox(height: BirdySpace.m),
          Wrap(
            spacing: BirdySpace.s,
            runSpacing: BirdySpace.s,
            children: [
              for (var i = 0; i < Season.values.length; i++)
                BirdySkeleton.bar(
                  width: _skeletonChipWidth,
                  height: BirdySizes.target,
                ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          AspectRatio(
            aspectRatio: WorldMapConfig.aspect,
            child: BirdySkeleton.box(
              width: double.infinity,
              height: double.infinity,
              radius: BirdyRadii.chip,
            ),
          ),
          const SizedBox(height: BirdySpace.m),
          BirdySkeleton.text(
            BirdyText.bodyCompact,
            placeholder: l10n.forkWorldLegendSeasons(
              l10n.forkWorldRegionNorthernEurope,
              l10n.forkWorldRegionWestAfrica,
            ),
            maxLines: null,
          ),
        ],
      ),
    );
  }

  static const double _skeletonChipWidth = 88;

  @override
  State<WorldMapBlock> createState() => _WorldMapBlockState();
}

class _WorldMapBlockState extends State<WorldMapBlock> {
  late Season _season = Season.ofMonth(widget.currentMonth);

  /// Computed once: four seasons are already in [WorldMapBlock.presence].
  late final SeasonLegend _legend = buildLegend(widget.presence);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final colors = WorldMapColors.of(c);
    final legend = legendText(l10n, language, _legend);
    final season = seasonName(l10n, _season);
    final nesting = widget.nesting;
    return BirdyBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: AppIcons.public, text: l10n.forkWorldTitle),
          const SizedBox(height: BirdySpace.m),
          Wrap(
            spacing: BirdySpace.s,
            runSpacing: BirdySpace.s,
            children: [
              for (final s in Season.values)
                BirdyFilterChip(
                  label: seasonName(l10n, s),
                  selected: s == _season,
                  selectedColors: BirdyChipColors.ink(c),
                  unselectedColor: c.background,
                  onSelected: () => setState(() => _season = s),
                ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          // One label for the map and its legend: it changes with the season,
          // and a live region announces it.
          Semantics(
            container: true,
            liveRegion: true,
            label: l10n.forkWorldMapLabel(season, legend),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BirdyRadii.chip),
              child: AspectRatio(
                aspectRatio: WorldMapConfig.aspect,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: WorldMapPainter(
                      outline: widget.outline,
                      presence: widget.presence,
                      season: _season,
                      colors: colors,
                      user: widget.user,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: BirdySpace.s),
          _Key(
            colors: colors,
            showYou: widget.user != null,
            gbif: widget.source == WorldMapSource.gbif,
          ),
          const SizedBox(height: BirdySpace.s),
          Text(legend, style: BirdyText.bodyCompact.copyWith(color: c.text1)),
          if (nesting != null) ...[
            const SizedBox(height: BirdySpace.xs),
            Text(
              nestingLegend(l10n, language, nesting),
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
          ],
          const SizedBox(height: BirdySpace.s),
          _SourceNote(
            source: widget.source,
            onGbifTap: widget.onGbifTap,
            onLicenseTap: widget.onLicenseTap,
            onOnlineHintTap: widget.onOnlineHintTap,
          ),
        ],
      ),
    );
  }
}

/// Small key under the map: expected, other seasons, the user.
class _Key extends StatelessWidget {
  const _Key({
    required this.colors,
    required this.showYou,
    required this.gbif,
  });

  final WorldMapColors colors;
  final bool showYou;
  final bool gbif;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: BirdySpace.xs),
        Flexible(
          child: Text(label, style: BirdyText.caption.copyWith(color: c.text2)),
        ),
      ],
    );
    Widget square(Color color) => Container(
      width: WorldMapConfig.keySwatch,
      height: WorldMapConfig.keySwatch,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(
          WorldMapConfig.keySwatch * WorldMapConfig.cellRadius,
        ),
      ),
    );
    return Wrap(
      spacing: BirdySpace.l,
      runSpacing: BirdySpace.xs,
      children: [
        item(
          square(colors.present),
          gbif ? l10n.forkWorldKeyObserved : l10n.forkWorldKeyPresent,
        ),
        item(square(colors.other), l10n.forkWorldKeyOther),
        if (showYou)
          item(
            Container(
              width: WorldMapConfig.userDot,
              height: WorldMapConfig.userDot,
              decoration: BoxDecoration(
                color: colors.user,
                shape: BoxShape.circle,
              ),
            ),
            l10n.forkWorldKeyYou,
          ),
      ],
    );
  }
}

/// Mention under the map: the geo-model estimate (with, when the online map
/// is off, a line that opens the setting), or the GBIF credit with two
/// links: GBIF's site and the licenses page (48 dp targets).
class _SourceNote extends StatelessWidget {
  const _SourceNote({
    required this.source,
    this.onGbifTap,
    this.onLicenseTap,
    this.onOnlineHintTap,
  });

  final WorldMapSource source;
  final VoidCallback? onGbifTap;
  final VoidCallback? onLicenseTap;
  final VoidCallback? onOnlineHintTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    if (source == WorldMapSource.geomodel) {
      final hint = onOnlineHintTap;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.forkWorldEstimate, style: caption),
          if (hint != null)
            _LinkTarget(
              key: const ValueKey('world-map-online-hint'),
              label: l10n.forkWorldOnlineHint,
              style: BirdyText.caption.copyWith(color: c.accentText),
              onTap: hint,
            ),
        ],
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LinkTarget(
          key: const ValueKey('world-map-source'),
          label: l10n.forkWorldSourceGbif,
          style: caption,
          onTap: onGbifTap,
        ),
        Text(' · ', style: caption),
        _LinkTarget(
          key: const ValueKey('world-map-license'),
          label: l10n.forkWorldSourceLicense,
          style: caption,
          onTap: onLicenseTap,
        ),
      ],
    );
  }
}

/// A line of text that is a button, at least 48 dp tall.
class _LinkTarget extends StatelessWidget {
  const _LinkTarget({
    super.key,
    required this.label,
    required this.style,
    this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: style);
    if (onTap == null) return text;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BirdyRadii.chip),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: text,
          ),
        ),
      ),
    );
  }
}
