/// Design system gallery (J6a): every BirdyGo component in light and dark,
/// to check them on a phone. Debug and profile builds only.
///
/// Species names and colors below are sample data (SPEC.md 2.5).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../game/game_widgets.dart';
import '../live/live_expected.dart';
import '../listening_mode/listening_mode.dart';
import '../live/listening_options.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import 'birdy_motion.dart';
import 'birdy_theme.dart';
import 'birdy_tokens.dart';
import 'birdy_typography.dart';
import 'species_tint.dart';
import 'widgets/animated_count.dart';
import 'widgets/birdy_animated_icon.dart';
import 'widgets/birdy_block.dart';
import 'widgets/birdy_buttons.dart';
import 'widgets/birdy_filter_chip.dart';
import 'widgets/birdy_headers.dart';
import 'widgets/birdy_pill.dart';
import 'widgets/clip_play_button.dart';
import 'widgets/empty_state.dart';
import 'widgets/entrance.dart';
import 'widgets/species_avatar.dart';
import 'widgets/species_card.dart';
import 'widgets/species_tile.dart';
import 'widgets/tip_card.dart';

/// Settings entry to the gallery. Hidden (and tree-shaken) in release.
class DesignGalleryTile extends StatelessWidget {
  const DesignGalleryTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(AppIcons.sparkle),
      title: Text(l10n.forkDesignGallery),
      subtitle: Text(l10n.forkDesignGallerySubtitle),
      trailing: const Icon(AppIcons.chevronRight),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DesignGalleryScreen(),
            ),
          ),
    );
  }
}

class _Sample {
  const _Sample(this.name, this.latin, this.accent, this.level);

  final String name;
  final String latin;
  final Color accent;
  final ReliabilityLevel level;
}

const _samples = [
  _Sample(
    'Rougegorge familier',
    'Erithacus rubecula',
    Color(0xFFEC7A3C),
    ReliabilityLevel.sure,
  ),
  _Sample(
    'Mésange bleue',
    'Cyanistes caeruleus',
    Color(0xFF3B8FDB),
    ReliabilityLevel.sure,
  ),
  _Sample(
    'Pic épeiche',
    'Dendrocopos major',
    Color(0xFFD8343A),
    ReliabilityLevel.probable,
  ),
  _Sample(
    'Martin-pêcheur d\'Europe',
    'Alcedo atthis',
    Color(0xFF29A9D6),
    ReliabilityLevel.probable,
  ),
  _Sample(
    'Huppe fasciée',
    'Upupa epops',
    Color(0xFFE3A07A),
    ReliabilityLevel.toCheck,
  ),
];

class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  Brightness? _brightness;
  int _count = 3;
  int _replays = 0;
  bool _playing = false;
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness ?? Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data:
          brightness == Brightness.dark
              ? BirdyTheme.dark()
              : BirdyTheme.light(),
      child: Builder(
        builder: (context) {
          final c = BirdyColors.of(context);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.forkDesignGallery)),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.gutter,
                BirdySpace.s,
                BirdySpace.gutter,
                BirdySpace.xxxl,
              ),
              children: [
                SegmentedButton<Brightness>(
                  segments: [
                    ButtonSegment(
                      value: Brightness.light,
                      label: Text(l10n.settingsThemeLight),
                    ),
                    ButtonSegment(
                      value: Brightness.dark,
                      label: Text(l10n.settingsThemeDark),
                    ),
                  ],
                  selected: {brightness},
                  onSelectionChanged:
                      (value) => setState(() => _brightness = value.first),
                ),
                _Section(l10n.forkGalleryColors, [_colors(c)]),
                _Section(l10n.forkGalleryType, _type(c)),
                _Section(l10n.forkGalleryButtons, _buttons(context, l10n)),
                _Section(l10n.forkGalleryBadges, _badges()),
                _Section(l10n.forkGalleryCounters, _counters(l10n)),
                _Section(l10n.forkGallerySpecies, _species(context, l10n)),
                _Section(l10n.forkGalleryPlayer, [_player(l10n)]),
                _Section(l10n.forkGalleryMotion, _motion(l10n)),
                _Section(l10n.forkGalleryEmpty, _empty(l10n)),
                _Section(l10n.forkTipHeader, [_tips(l10n)]),
                _Section(l10n.forkBadges, [_medals()]),
                _Section(l10n.forkGalleryBlocks, _blocks(c, l10n)),
                _Section(l10n.forkGalleryHeaders, _headers(context, l10n)),
                _Section(l10n.forkGalleryFilters, _filters(l10n)),
                _Section(l10n.forkGalleryListeningMode, [_listeningMode(l10n)]),
                _Section(l10n.forkGalleryExpected, [_expected(l10n)]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _colors(BirdyColors c) {
    final swatches = <(String, Color)>[
      ('background', c.background),
      ('surface1', c.surface1),
      ('surface2', c.surface2),
      ('surface3', c.surface3),
      ('text1', c.text1),
      ('text2', c.text2),
      ('accent', c.accent),
      ('accentText', c.accentText),
      ('tonal', c.tonal),
      ('oriole', c.oriole),
      ('orioleText', c.orioleText),
      ('sure', c.sure.foreground),
      ('probable', c.probable.foreground),
      ('toCheck', c.toCheck.foreground),
    ];
    return Wrap(
      spacing: BirdySpace.m,
      runSpacing: BirdySpace.m,
      children: [
        for (final (name, color) in swatches)
          SizedBox(
            width: BirdyGlyph.disc72,
            child: Column(
              children: [
                Container(
                  height: BirdyGlyph.disc48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(BirdyRadii.thumb),
                    border: Border.all(color: c.line),
                  ),
                ),
                const SizedBox(height: BirdySpace.xs),
                Text(
                  name,
                  style: BirdyText.caption.copyWith(color: c.text2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _type(BirdyColors c) {
    final styles = <(String, TextStyle)>[
      ('display 34', BirdyText.display),
      ('title 26', BirdyText.title),
      ('heading 20', BirdyText.heading),
      ('species 17', BirdyText.species),
      ('latin 17', BirdyText.latin),
      ('body 17', BirdyText.body),
      ('body 15', BirdyText.bodyCompact),
      ('label 17', BirdyText.label),
      ('caption 13', BirdyText.caption),
      ('number XL 34', BirdyText.numberXL),
    ];
    return [
      for (final (name, style) in styles)
        Padding(
          padding: const EdgeInsets.only(bottom: BirdySpace.s),
          child: Text(
            name.startsWith('latin')
                ? _samples.first.latin
                : name.startsWith('number')
                ? '1 104  0,97  12:47'
                : '${_samples.first.name} · $name',
            style: style.copyWith(color: c.text1),
          ),
        ),
    ];
  }

  List<Widget> _buttons(BuildContext context, AppLocalizations l10n) {
    final dark = BirdyTheme.dark();
    return [
      ListenButton(onPressed: () {}),
      const SizedBox(height: BirdySpace.m),
      Wrap(
        spacing: BirdySpace.s,
        runSpacing: BirdySpace.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            style: BirdyButtonStyles.primary(context),
            onPressed: () {},
            child: Text(l10n.forkListen),
          ),
          OutlinedButton.icon(
            style: BirdyButtonStyles.secondary(context),
            onPressed: () {},
            icon: const Icon(AppIcons.playArrow),
            label: Text(l10n.forkReplay),
          ),
          FilledButton(
            style: BirdyButtonStyles.tonal(context),
            onPressed: () {},
            child: Text(l10n.forkGalleryReplay),
          ),
          BirdyIconButton(
            icon: AppIcons.close,
            semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () {},
          ),
        ],
      ),
      const SizedBox(height: BirdySpace.m),
      Theme(
        data: dark,
        child: Builder(
          builder:
              (context) => DecoratedBox(
                decoration: BoxDecoration(
                  color: BirdyColors.dark.backgroundDeep,
                  borderRadius: BorderRadius.circular(BirdyRadii.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(BirdySpace.m),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          style: BirdyButtonStyles.stop(context),
                          onPressed: () {},
                          icon: const Icon(AppIcons.stop, fill: 1),
                          label: Text(l10n.forkStop),
                        ),
                      ),
                      const SizedBox(width: BirdySpace.m),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: BirdyButtonStyles.pause(context),
                          onPressed: () {},
                          icon: const Icon(AppIcons.pause),
                          label: Text(l10n.forkPause),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    ];
  }

  List<Widget> _badges() => [
    Wrap(
      spacing: BirdySpace.s,
      runSpacing: BirdySpace.s,
      children: [
        for (final level in ReliabilityLevel.values)
          ReliabilityBadge(level: level),
        for (final level in ReliabilityLevel.values)
          ReliabilityBadge(level: level, compact: true),
        const ReliabilityBadge(
          level: ReliabilityLevel.toCheck,
          unexpected: true,
        ),
        const ReliabilityBadge(
          level: ReliabilityLevel.toCheck,
          unexpected: true,
          score: 0.9,
        ),
        for (final kind in NoveltyKind.values) NoveltyPill(kind: kind),
      ],
    ),
  ];

  List<Widget> _counters(AppLocalizations l10n) => [
    Row(
      children: [
        Expanded(
          child: StatTile.count(count: _count, label: l10n.forkGallerySpecies),
        ),
        const SizedBox(width: BirdySpace.m),
        AnimatedCount(value: _count, format: (v) => '×$v'),
        const SizedBox(width: BirdySpace.m),
        FilledButton.tonal(
          onPressed: () => setState(() => _count++),
          child: const Text('+1'),
        ),
      ],
    ),
  ];

  List<Widget> _species(BuildContext context, AppLocalizations l10n) {
    SpeciesTint tint(_Sample s) => SpeciesTint.fromAccent(s.accent);
    return [
      for (final (i, s) in _samples.indexed) ...[
        SpeciesTile(
          name: s.name,
          scientificName: i.isEven ? s.latin : null,
          avatar: SpeciesAvatar(
            tint: tint(s),
            muted: s.level == ReliabilityLevel.toCheck,
          ),
          meta: Wrap(
            spacing: BirdySpace.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ReliabilityBadge(level: s.level),
              Text('${142 - i * 31}'),
            ],
          ),
          count: AnimatedCount(value: _count + i, format: (v) => '×$v'),
          action: ClipPlayButton(
            state: ClipPlayState.idle,
            semanticLabel: '${l10n.forkReplay} : ${s.name}',
            onPressed: () {},
          ),
          onTap: () {},
        ),
        const SizedBox(height: BirdySpace.s),
      ],
      const SizedBox(height: BirdySpace.s),
      SpeciesCard(
        name: _samples.first.name,
        hero: true,
        tint: tint(_samples.first),
        visual: SpeciesAvatar(tint: tint(_samples.first), size: BirdyGlyph.disc96),
        caption: Text(_samples.first.latin),
        onTap: () {},
      ),
      const SizedBox(height: BirdySpace.m),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 20) / 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final card in <Widget>[
                SpeciesCard(
                  name: _samples[2].name,
                  tint: tint(_samples[2]),
                  visual: SpeciesAvatar(tint: tint(_samples[2]), size: BirdyGlyph.disc56),
                  corner: const NoveltyPill(kind: NoveltyKind.isNew),
                  onTap: () {},
                ),
                SpeciesCard(
                  name: _samples[3].name,
                  tint: tint(_samples[3]),
                  visual: SpeciesAvatar(tint: tint(_samples[3]), size: BirdyGlyph.disc56),
                  corner: Icon(
                    AppIcons.diamond,
                    size: BirdyGlyph.s,
                    fill: 1,
                    color: BirdyColors.of(context).orioleText,
                  ),
                  onTap: () {},
                ),
                SpeciesCard.toConfirm(
                  name: _samples[4].name,
                  visual: SpeciesAvatar(
                    tint: tint(_samples[4]),
                    size: BirdyGlyph.disc56,
                    muted: true,
                  ),
                  onTap: () {},
                ),
                SpeciesCard.mystery(
                  name: l10n.forkMystery,
                  visual: const SpeciesAvatar(size: BirdyGlyph.disc56, mystery: true),
                ),
              ])
                SizedBox(width: width, child: card),
            ],
          );
        },
      ),
    ];
  }

  Widget _player(AppLocalizations l10n) => Wrap(
    spacing: BirdySpace.l,
    children: [
      ClipPlayButton(
        state: _playing ? ClipPlayState.playing : ClipPlayState.idle,
        semanticLabel: _playing ? l10n.forkReplayStop : l10n.forkReplay,
        progress: _playing ? 0.4 : null,
        onPressed: () => setState(() => _playing = !_playing),
      ),
      ClipPlayButton(
        state: ClipPlayState.pending,
        semanticLabel: l10n.forkReplayPending,
      ),
    ],
  );

  /// Badge medals: locked, bronze, silver, gold (DESIGN.md « Jeu »).
  Widget _medals() => Wrap(
    spacing: BirdySpace.l,
    runSpacing: BirdySpace.m,
    children: [
      for (var tier = 0; tier <= 3; tier++)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeMedal(tier: tier, icon: AppIcons.star),
            const SizedBox(height: BirdySpace.xs),
            if (tier > 0) TierDots(filled: tier),
          ],
        ),
    ],
  );

  /// The three kinds of empty state (DESIGN.md « Écrans vides »).
  List<Widget> _empty(AppLocalizations l10n) => [
    BirdyEmptyState(
      icon: AppIcons.hearing,
      title: l10n.forkHomeEmptyDayTitle,
      body: l10n.forkHomeEmptyDay,
      action: l10n.forkListen,
      onAction: () {},
    ),
    const SizedBox(height: BirdySpace.m),
    BirdyEmptyState.inline(
      kind: BirdyEmptyKind.filtered,
      icon: AppIcons.searchOff,
      title: l10n.forkRankingEmptyTitle,
      body: l10n.forkRankingEmptyFiltered,
      action: l10n.forkRankingAllPeriods,
      onAction: () {},
    ),
    const SizedBox(height: BirdySpace.m),
    BirdyEmptyState.inline(
      kind: BirdyEmptyKind.done,
      icon: AppIcons.check,
      title: l10n.forkQuickReviewEmptyTitle,
      body: l10n.forkQuickReviewEmpty,
    ),
  ];

  /// Tip cards (DESIGN.md « Astuces »): tap for the next one.
  Widget _tips(AppLocalizations l10n) => BirdyTipCarousel(
    tips: [
      BirdyTip(
        icon: AppIcons.air,
        title: l10n.liveTipWindTitle,
        body: l10n.liveTipWindBody,
        motion: BirdyIconMotion.drift,
      ),
      BirdyTip(
        icon: AppIcons.graphicEq,
        title: l10n.liveTipSpectrogramTitle,
        body: l10n.liveTipSpectrogramBody,
        motion: BirdyIconMotion.pulse,
      ),
      BirdyTip(
        icon: AppIcons.batteryChargingFull,
        title: l10n.liveTipBatteryTitle,
        body: l10n.liveTipBatteryBody,
      ),
      BirdyTip(
        icon: AppIcons.saveAlt,
        title: l10n.liveTipSaveClipsTitle,
        body: l10n.liveTipSaveClipsBody,
        motion: BirdyIconMotion.drop,
      ),
    ],
  );

  List<Widget> _motion(AppLocalizations l10n) => [
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilledButton.tonal(
        onPressed: () => setState(() => _replays++),
        child: Text(l10n.forkGalleryReplay),
      ),
    ),
    const SizedBox(height: BirdySpace.m),
    for (final (i, s) in _samples.indexed)
      BirdyEntrance.staggered(
        key: ValueKey('$_replays-$i'),
        index: i,
        offset: const Offset(0, -BirdyMotion.maxOffset),
        child: Padding(
          padding: const EdgeInsets.only(bottom: BirdySpace.s),
          child: SpeciesTile(
            name: s.name,
            compact: true,
            avatar: SpeciesAvatar(
              tint: SpeciesTint.fromAccent(s.accent),
              size: BirdyGlyph.disc40,
            ),
          ),
        ),
      ),
  ];

  /// A [BirdyBlock] in each tone (DESIGN.md « App finale »), then its
  /// progress bar and ring.
  List<Widget> _blocks(BirdyColors c, AppLocalizations l10n) {
    final tones = <(BirdyBlockTone, String, String)>[
      (BirdyBlockTone.plain, '12', 'Espèces'),
      (BirdyBlockTone.tonal, '3', 'Objectif du jour'),
      (BirdyBlockTone.sure, '48', 'Découvertes'),
      (BirdyBlockTone.oriole, '2', 'Rares'),
      (BirdyBlockTone.toCheck, '5', 'À vérifier'),
    ];
    return [
      Wrap(
        spacing: BirdySpace.m,
        runSpacing: BirdySpace.m,
        children: [
          for (final (tone, number, label) in tones)
            SizedBox(
              width: BirdySizes.gallerySample,
              child: BirdyBlock(
                tone: tone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      number,
                      style: BirdyText.numberXL.copyWith(color: c.text1),
                    ),
                    Text(
                      label,
                      style: BirdyText.caption.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: BirdySpace.m),
      BirdyBlock(
        tone: BirdyBlockTone.tonal,
        child: BirdyProgressBar(
          value: 0.6,
          color: c.accent,
          track: birdyTrackOnTint(c),
        ),
      ),
      const SizedBox(height: BirdySpace.m),
      BirdyBlock(
        tone: BirdyBlockTone.sure,
        child: Center(
          child: BirdyProgressRing(
            value: 5 / 8,
            color: c.sure.foreground,
            track: birdyTrackOnTint(c),
            child: Text(
              '5/8',
              style: BirdyText.numberM.copyWith(color: c.text1),
            ),
          ),
        ),
      ),
    ];
  }

  /// Tab header and overlay header (DESIGN.md « App finale »).
  ///
  /// The « Fermer » (closing) variant of [BirdyOverlayHeader] lives on
  /// `feat/j6f-b-tabs-overlays`, not yet merged into this gallery's base
  /// branch (`feat/j6f-c-modes-wired`): skipped here, see the PR description.
  List<Widget> _headers(BuildContext context, AppLocalizations l10n) => [
    BirdyTabHeader(
      title: l10n.forkGallerySpecies,
      caption: '24 espèces découvertes',
      actions: [
        BirdyIconButton(
          icon: AppIcons.sparkle,
          semanticLabel: l10n.forkDesignGallery,
          onPressed: () {},
        ),
      ],
    ),
    const SizedBox(height: BirdySpace.m),
    BirdyOverlayHeader(title: _samples.first.name, onBack: () {}),
  ];

  /// Filter chips (Carnet: Toutes/Découvertes/À découvrir/Rares), one
  /// selected at a time, plus the floating variant over a map.
  List<Widget> _filters(AppLocalizations l10n) {
    final chips = <(String, BirdyChipColors Function(BirdyColors))>[
      (l10n.forkNotebookFilterAll, BirdyChipColors.ink),
      (l10n.forkNotebookFilterDiscovered, BirdyChipColors.sure),
      (l10n.forkNotebookFilterToDiscover, BirdyChipColors.tonal),
      (l10n.forkNotebookFilterRare, BirdyChipColors.oriole),
    ];
    Widget row({bool floating = false}) => Builder(
      builder: (context) {
        final c = BirdyColors.of(context);
        return Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.s,
          children: [
            for (final (i, chip) in chips.indexed)
              BirdyFilterChip(
                label: chip.$1,
                selected: _filter == i,
                selectedColors: chip.$2(c),
                floating: floating,
                onSelected: () => setState(() => _filter = i),
              ),
          ],
        );
      },
    );
    return [row(), const SizedBox(height: BirdySpace.m), row(floating: true)];
  }

  /// The live header's « Options d'écoute » button, one per mode plus
  /// Personnalisé, each already in its own color (J6f); a tap opens the
  /// options sheet via the [ProviderScope] the gallery already runs in
  /// (see `main.dart`). Help and settings do nothing here.
  Widget _listeningMode(AppLocalizations l10n) => Wrap(
    spacing: BirdySpace.s,
    children: [
      for (final mode in const [
        ListeningMode.normal,
        ListeningMode.wind,
        ListeningMode.boost,
        ListeningMode.city,
        null,
      ])
        Builder(
          builder:
              (context) => ListeningOptionsButton(
                mode: mode,
                onPressed:
                    () => showListeningOptionsSheet(
                      context,
                      onHelp: () {},
                      onSettings: () {},
                    ),
              ),
        ),
    ],
  );

  /// One [LiveExpectedRow], built from sample data only (no model needed).
  Widget _expected(AppLocalizations l10n) => const LiveExpectedRow(
    species: LiveExpectedSpecies(
      scientificName: 'Erithacus rubecula',
      commonName: 'Rougegorge familier',
      reason: LiveExpectedReason.frequent,
      goal: true,
    ),
    reason: 'Parmi les plus fréquents ici en septembre',
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: BirdySpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: BirdyText.heading.copyWith(color: c.text1)),
          const SizedBox(height: BirdySpace.m),
          ...children,
        ],
      ),
    );
  }
}
