/// « Plus » sheet of the home screen (J6g-c, reworked in M): the old flat menu,
/// sorted from what matters to what is technical. Three titled groups (Jouer,
/// Mon suivi, Découvrir) of list rows, then a quiet block with Réglages, Aide,
/// À propos and, last, the collapsed « Outils avancés » for the field modes.
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
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_list_row.dart';
import '../design/widgets/birdy_sheet.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/pressable.dart';
import '../game/fine_ear_quiz_screen.dart';
import '../garden/garden_count_screen.dart';
import '../ranking/ranking_screen.dart';
import '../reliability/quick_review_screen.dart';
import '../settings/simple_settings_screen.dart';
import '../sound_library/sound_library_screen.dart';

/// Opens the « Plus » sheet. Entries push onto the navigator that [context]
/// belongs to, like the old menu did.
Future<void> showMoreSheet(
  BuildContext context,
  WidgetRef ref, {
  int toVerify = 0,
}) {
  final navigator = Navigator.of(context);
  return showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight:
          MediaQuery.sizeOf(context).height * BirdySizes.moreSheetMaxShare,
    ),
    builder:
        (sheetContext) => MoreSheet(
          toVerify: toVerify,
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

/// One entry: icon, label, optional subtitle and the screen it opens.
class _Entry {
  const _Entry(
    this.icon,
    this.label,
    this.screen, {
    this.subtitle,
    this.tone = BirdyBlockTone.plain,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget Function() screen;

  /// Tint of the row's disc.
  final BirdyBlockTone tone;
}

/// Content of the « Plus » sheet. [onOpen] closes the sheet and opens a
/// screen; [aruScreen] picks the ARU screen (setup, or the running one).
class MoreSheet extends StatefulWidget {
  const MoreSheet({
    super.key,
    required this.onOpen,
    required this.aruScreen,
    this.toVerify = 0,
  });

  /// Detections waiting in the review queue (Revue rapide's subtitle).
  final int toVerify;

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
    final play = <_Entry>[
      _Entry(
        AppIcons.headphones,
        l10n.forkQuizTitle,
        () => const FineEarQuizScreen(),
        subtitle: l10n.forkMoreQuizSub,
        tone: BirdyBlockTone.oriole,
      ),
      _Entry(
        AppIcons.leaderboard,
        l10n.forkRanking,
        () => const RankingScreen(),
        subtitle: l10n.forkMoreRankingSub,
        tone: BirdyBlockTone.oriole,
      ),
    ];
    final mine = <_Entry>[
      _Entry(
        AppIcons.verifiedRounded,
        l10n.forkQuickReview,
        () => const QuickReviewScreen(),
        subtitle:
            widget.toVerify > 0
                ? l10n.forkMoreReviewSub(widget.toVerify)
                : l10n.forkMoreReviewDone,
        tone: BirdyBlockTone.toCheck,
      ),
      _Entry(
        AppIcons.graphicEqRounded,
        l10n.forkSoundLibrary,
        () => const SoundLibraryScreen(),
        subtitle: l10n.forkMoreSoundsSub,
        tone: BirdyBlockTone.tonal,
      ),
      _Entry(
        AppIcons.libraryMusic,
        l10n.sessionLibraryTitle,
        () => const SessionLibraryScreen(),
        subtitle: l10n.forkMoreSessionsSub,
        tone: BirdyBlockTone.tonal,
      ),
    ];
    final discover = <_Entry>[
      _Entry(
        AppIcons.parkRounded,
        l10n.forkGardenTitle,
        () => const GardenCountScreen(),
        subtitle: l10n.forkMoreGardenSub,
        tone: BirdyBlockTone.sure,
      ),
      _Entry(
        AppIcons.searchRounded,
        l10n.exploreMode,
        () => const ExploreScreen(),
        subtitle: l10n.forkMoreExploreSub,
        tone: BirdyBlockTone.tonal,
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
          _Group(
            key: const ValueKey('more-group-play'),
            title: l10n.forkMoreGroupPlay,
            entries: play,
            onOpen: widget.onOpen,
          ),
          const SizedBox(height: BirdySpace.l),
          _Group(
            key: const ValueKey('more-group-mine'),
            title: l10n.forkMoreGroupMine,
            entries: mine,
            onOpen: widget.onOpen,
          ),
          const SizedBox(height: BirdySpace.l),
          _Group(
            key: const ValueKey('more-group-discover'),
            title: l10n.forkMoreGroupDiscover,
            entries: discover,
            onOpen: widget.onOpen,
          ),
          const SizedBox(height: BirdySpace.l),
          Divider(
            height: BirdyStroke.hairline,
            thickness: BirdyStroke.hairline,
            color: c.line,
          ),
          const SizedBox(height: BirdySpace.l),
          _UtilityBlock(
            advancedOpen: _advancedOpen,
            onToggle: () => setState(() => _advancedOpen = !_advancedOpen),
            tools: tools,
            onOpen: widget.onOpen,
          ),
        ],
      ),
    );
  }
}

/// A titled group: caption header, then one Brume block of list rows.
class _Group extends StatelessWidget {
  const _Group({
    super.key,
    required this.title,
    required this.entries,
    required this.onOpen,
  });

  final String title;
  final List<_Entry> entries;
  final void Function(Widget screen) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BirdySpace.xs,
            0,
            BirdySpace.xs,
            BirdySpace.s,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: BirdyText.caption.copyWith(
                color: c.text2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        BirdyListBlock(
          color: c.background,
          children: [
            for (final e in entries)
              _EntryRow(entry: e, onTap: () => onOpen(e.screen())),
          ],
        ),
      ],
    );
  }
}

/// Icon color on the tinted disc of [tone].
Color _iconColor(BirdyColors c, BirdyBlockTone tone) => switch (tone) {
  BirdyBlockTone.oriole => c.orioleText,
  BirdyBlockTone.sure => c.sure.foreground,
  BirdyBlockTone.toCheck => c.toCheck.foreground,
  BirdyBlockTone.tonal => c.accentText,
  _ => c.text1,
};

/// A group row: the shared [BirdyListRow] with the entry's tinted disc.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final _Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final toCheck = entry.tone == BirdyBlockTone.toCheck;
    final semantic =
        entry.subtitle == null
            ? entry.label
            : '${entry.label}, ${entry.subtitle}';
    return BirdyListRow(
      key: ValueKey('more-row-${entry.label}'),
      // The to-check disc is white with a dashed outline: drawn here, the
      // shared row only paints plain discs.
      icon: toCheck ? null : entry.icon,
      avatar: toCheck ? _DashedDisc(icon: entry.icon) : null,
      iconColor: _iconColor(c, entry.tone),
      discColor: birdyBlockColor(c, entry.tone),
      title: entry.label,
      subtitle: entry.subtitle,
      semanticLabel: semantic,
      onTap: onTap,
    );
  }
}

/// White disc with the dashed « À vérifier » outline.
class _DashedDisc extends StatelessWidget {
  const _DashedDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: c.toCheck.foreground,
        radius: BirdySizes.rowDisc / 2,
      ),
      child: Container(
        width: BirdySizes.rowDisc,
        height: BirdySizes.rowDisc,
        decoration: BoxDecoration(color: c.surface1, shape: BoxShape.circle),
        child: Icon(
          icon,
          size: BirdyGlyph.xxl,
          color: c.toCheck.foreground,
          fill: 1,
        ),
      ),
    );
  }
}

/// The quiet block under the groups: Réglages, Aide, À propos, then the
/// collapsible « Outils avancés » (always last).
class _UtilityBlock extends StatelessWidget {
  const _UtilityBlock({
    required this.advancedOpen,
    required this.onToggle,
    required this.tools,
    required this.onOpen,
  });

  final bool advancedOpen;
  final VoidCallback onToggle;
  final List<_Entry> tools;
  final void Function(Widget screen) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    final body =
        advancedOpen
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tool in tools)
                  _ToolRow(entry: tool, onTap: () => onOpen(tool.screen())),
                const SizedBox(height: BirdySpace.xs),
              ],
            )
            : const SizedBox(width: double.infinity);
    Widget line() => Divider(
      height: BirdyStroke.hairline,
      thickness: BirdyStroke.hairline,
      color: c.line,
    );
    return DecoratedBox(
      key: const ValueKey('more-utility'),
      decoration: BoxDecoration(
        color: c.surface1,
        border: Border.all(color: c.line, width: BirdyStroke.hairline),
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BirdyRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompactRow(
              key: const ValueKey('more-settings'),
              icon: AppIcons.tuneRounded,
              label: l10n.forkSettingsTitle,
              onTap: () => onOpen(const SimpleSettingsScreen()),
            ),
            line(),
            _CompactRow(
              key: const ValueKey('more-help'),
              icon: AppIcons.helpOutlineRounded,
              label: l10n.helpTitle,
              onTap: () => onOpen(const HelpScreen()),
            ),
            line(),
            _CompactRow(
              key: const ValueKey('more-about'),
              icon: AppIcons.infoOutline,
              label: l10n.about,
              onTap: () => onOpen(const AboutScreen()),
            ),
            line(),
            _CompactRow(
              key: const ValueKey('more-advanced-toggle'),
              icon: AppIcons.handyman,
              label: l10n.forkMoreAdvancedTools,
              labelColor: c.text2,
              expanded: advancedOpen,
              trailingIcon:
                  advancedOpen ? AppIcons.expandLess : AppIcons.expandMore,
              onTap: onToggle,
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
      ),
    );
  }
}

/// Compact row of the utility block: icon without disc, 15 bold label,
/// chevron (or the expand arrow of « Outils avancés »).
class _CompactRow extends StatelessWidget {
  const _CompactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.expanded,
    this.trailingIcon,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  /// Non-null for an expandable row.
  final bool? expanded;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Pressable(
      child: Semantics(
        button: true,
        expanded: expanded,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: BirdySizes.moreCompactRow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BirdySpace.l),
              child: Row(
                children: [
                  Icon(icon, size: BirdyGlyph.xxl, color: c.text2),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: Text(
                      label,
                      style: BirdyText.bodyCompact.copyWith(
                        color: labelColor ?? c.text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    trailingIcon ?? AppIcons.chevronRight,
                    size: BirdyGlyph.xxl,
                    color: c.text2,
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

/// One advanced tool: indented row under the « Outils avancés » toggle.
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.entry, required this.onTap});

  final _Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Pressable(
      child: Semantics(
        button: true,
        label: entry.label,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('more-tool-${entry.label}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: BirdySizes.moreToolRow,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: BirdySpace.l + BirdySizes.moreToolIndent,
                right: BirdySpace.l,
              ),
              child: Row(
                children: [
                  Icon(entry.icon, size: BirdyGlyph.xxl, color: c.text2),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: Text(
                      entry.label,
                      style: BirdyText.bodyCompact.copyWith(color: c.text1),
                    ),
                  ),
                  Icon(
                    AppIcons.chevronRight,
                    size: BirdyGlyph.xxl,
                    color: c.text2,
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
