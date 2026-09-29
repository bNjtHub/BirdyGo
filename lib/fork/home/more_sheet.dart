/// « Plus » sheet of the home screen (J6g-c): the old flat menu, redone as
/// big tactile tiles for what a family uses every day, a collapsed
/// « Outils avancés » section for the field modes, then Réglages and À propos.
///
/// Every entry opens the same screen as the old menu entry did.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/about/about_screen.dart';
import '../../features/aru/aru_active_screen.dart';
import '../../features/aru/aru_controller.dart';
import '../../features/aru/aru_providers.dart';
import '../../features/aru/aru_setup_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/file_analysis/file_analysis_screen.dart';
import '../../features/history/session_library_screen.dart';
import '../../features/home/help_screen.dart';
import '../../features/live/live_screen.dart';
import '../../features/live/live_session.dart';
import '../../features/point_count/point_count_setup_screen.dart';
import '../../features/survey/survey_setup_screen.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/session_type_visuals.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_sheet.dart';
import '../garden/garden_count_screen.dart';
import '../map/contact_map_screen.dart';
import '../ranking/ranking_screen.dart';
import '../reliability/quick_review_screen.dart';
import '../settings/simple_settings_screen.dart';
import '../sound_library/sound_library_screen.dart';

/// Width from which the tiles go on three columns.
const double _threeColumnsFrom = 520;

/// Minimum height of a tile: a big target with room for two label lines.
const double _tileMinHeight = 104;

/// Opens the « Plus » sheet. Entries push onto the navigator that [context]
/// belongs to, like the old menu did.
Future<void> showMoreSheet(BuildContext context, WidgetRef ref) {
  final navigator = Navigator.of(context);
  return showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (sheetContext) => MoreSheet(
          onOpen: (screen) {
            Navigator.of(sheetContext).pop();
            navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
          },
          aruScreen: () {
            final session = ref.read(aruSessionProvider);
            final state = ref.read(aruStateProvider);
            final running =
                session != null &&
                state != AruControllerState.completed &&
                state != AruControllerState.idle;
            return running ? const AruActiveScreen() : const AruSetupScreen();
          },
        ),
  );
}

/// One entry: icon, label and the screen it opens.
class _Entry {
  const _Entry(this.icon, this.label, this.screen);

  final IconData icon;
  final String label;
  final Widget Function() screen;
}

/// Content of the « Plus » sheet. [onOpen] closes the sheet and opens a
/// screen; [aruScreen] picks the ARU screen (setup, or the running one).
class MoreSheet extends StatefulWidget {
  const MoreSheet({super.key, required this.onOpen, required this.aruScreen});

  final void Function(Widget screen) onOpen;
  final Widget Function() aruScreen;

  @override
  State<MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends State<MoreSheet> {
  bool _advancedOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tiles = <_Entry>[
      _Entry(
        AppIcons.leaderboard,
        l10n.forkRanking,
        () => const RankingScreen(),
      ),
      _Entry(AppIcons.mapSheet, l10n.forkMap, () => const ContactMapScreen()),
      _Entry(
        AppIcons.verifiedRounded,
        l10n.forkQuickReview,
        () => const QuickReviewScreen(),
      ),
      _Entry(
        AppIcons.graphicEqRounded,
        l10n.forkSoundLibrary,
        () => const SoundLibraryScreen(),
      ),
      _Entry(
        AppIcons.parkRounded,
        l10n.forkGardenTitle,
        () => const GardenCountScreen(),
      ),
      _Entry(
        AppIcons.searchRounded,
        l10n.exploreMode,
        () => const ExploreScreen(),
      ),
      _Entry(
        AppIcons.libraryMusic,
        l10n.sessionLibraryTitle,
        () => const SessionLibraryScreen(),
      ),
      _Entry(
        AppIcons.helpOutlineRounded,
        l10n.helpTitle,
        () => const HelpScreen(),
      ),
    ];
    final tools = <_Entry>[
      _Entry(
        sessionTypeIcon(SessionType.pointCount),
        l10n.pointCountMode,
        () => const PointCountSetupScreen(),
      ),
      _Entry(
        sessionTypeIcon(SessionType.survey),
        l10n.surveyMode,
        () => const SurveySetupScreen(),
      ),
      _Entry(sessionTypeIcon(SessionType.aru), l10n.aruMode, widget.aruScreen),
      _Entry(
        AppIcons.musicNote,
        l10n.forkPracticeMenu,
        () => const LiveScreen(forkPractice: true),
      ),
      _Entry(
        sessionTypeIcon(SessionType.fileUpload),
        l10n.fileAnalysisMode,
        () => const FileAnalysisScreen(),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        0,
        BirdySpace.page,
        BirdySpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: BirdySpace.l),
            child: Semantics(
              header: true,
              child: Text(
                l10n.forkMoreTitle,
                style: BirdyText.title.copyWith(color: c.text1),
              ),
            ),
          ),
          _TileGrid(
            key: const ValueKey('more-tiles'),
            entries: tiles,
            onTap: (e) => widget.onOpen(e.screen()),
          ),
          const SizedBox(height: BirdySpace.l),
          _AdvancedSection(
            open: _advancedOpen,
            onToggle: () => setState(() => _advancedOpen = !_advancedOpen),
            tools: tools,
            onTap: (e) => widget.onOpen(e.screen()),
          ),
          const SizedBox(height: BirdySpace.block),
          _LinkRow(
            key: const ValueKey('more-settings'),
            icon: AppIcons.tuneRounded,
            label: l10n.forkSettingsTitle,
            onTap: () => widget.onOpen(const SimpleSettingsScreen()),
          ),
          const SizedBox(height: BirdySpace.block),
          _LinkRow(
            key: const ValueKey('more-about'),
            icon: AppIcons.infoOutline,
            label: l10n.about,
            onTap: () => widget.onOpen(const AboutScreen()),
          ),
        ],
      ),
    );
  }
}

/// Everyday entries as tinted tiles, two columns on a phone.
class _TileGrid extends StatelessWidget {
  const _TileGrid({super.key, required this.entries, required this.onTap});

  final List<_Entry> entries;
  final void Function(_Entry entry) onTap;

  static const _tones = [
    BirdyBlockTone.tonal,
    BirdyBlockTone.sure,
    BirdyBlockTone.oriole,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= _threeColumnsFrom ? 3 : 2;
        final rows = <Widget>[];
        for (var start = 0; start < entries.length; start += columns) {
          if (start > 0) rows.add(const SizedBox(height: BirdySpace.block));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: BirdySpace.block),
                    Expanded(
                      child:
                          i < entries.length
                              ? _Tile(
                                entry: entries[i],
                                tone: _tones[i % _tones.length],
                                onTap: () => onTap(entries[i]),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry, required this.tone, required this.onTap});

  final _Entry entry;
  final BirdyBlockTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyBlock(
      key: ValueKey('more-tile-${entry.label}'),
      tone: tone,
      onTap: onTap,
      semanticLabel: entry.label,
      padding: const EdgeInsets.all(BirdySpace.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _tileMinHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: BirdySizes.blockIconDisc,
              height: BirdySizes.blockIconDisc,
              decoration: BoxDecoration(
                color: birdyTrackOnTint(c),
                shape: BoxShape.circle,
              ),
              child: Icon(entry.icon, size: 22, color: c.text1),
            ),
            const SizedBox(height: BirdySpace.s),
            Text(
              entry.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BirdyText.bodyCompact.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Outils avancés »: collapsed by default, opens the field modes.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.open,
    required this.onToggle,
    required this.tools,
    required this.onTap,
  });

  final bool open;
  final VoidCallback onToggle;
  final List<_Entry> tools;
  final void Function(_Entry entry) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    final Widget body =
        open
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tool in tools)
                  _ToolRow(entry: tool, onTap: () => onTap(tool)),
                const SizedBox(height: BirdySpace.xs),
              ],
            )
            : const SizedBox(width: double.infinity);
    return BirdyBlock(
      key: const ValueKey('more-advanced'),
      color: c.background,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: l10n.forkMoreAdvancedTools,
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('more-advanced-toggle'),
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BirdySizes.row),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BirdySpace.l,
                    vertical: BirdySpace.s,
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.tuneRounded, color: c.text1),
                      const SizedBox(width: BirdySpace.m),
                      Expanded(
                        child: Text(
                          l10n.forkMoreAdvancedTools,
                          style: BirdyText.body.copyWith(
                            color: c.text1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        open ? AppIcons.expandLess : AppIcons.expandMore,
                        color: c.text2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // A zero-duration AnimatedSize re-dirties itself: reduced motion
          // skips it altogether.
          if (reduced)
            body
          else
            AnimatedSize(
              duration: BirdyMotion.enter,
              curve: BirdyMotion.standard,
              alignment: Alignment.topCenter,
              child: body,
            ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.entry, required this.onTap});

  final _Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Semantics(
      button: true,
      label: entry.label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('more-tool-${entry.label}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BirdySpace.l,
              vertical: BirdySpace.s,
            ),
            child: Row(
              children: [
                Icon(entry.icon, size: 22, color: c.text2),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Text(
                    entry.label,
                    style: BirdyText.bodyCompact.copyWith(color: c.text1),
                  ),
                ),
                Icon(AppIcons.chevronRight, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width row (Réglages, À propos).
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyBlock(
      color: c.background,
      onTap: onTap,
      semanticLabel: label,
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BirdySizes.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BirdySpace.l,
            vertical: BirdySpace.s,
          ),
          child: Row(
            children: [
              Icon(icon, color: c.text1),
              const SizedBox(width: BirdySpace.m),
              Expanded(
                child: Text(
                  label,
                  style: BirdyText.body.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(AppIcons.chevronRight, color: c.text2),
            ],
          ),
        ),
      ),
    );
  }
}
