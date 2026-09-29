/// « Ta journée d'écoute » sheet (J6h): when the birds sing and where the
/// sun is, with the moment touched in the strip highlighted. The one strong
/// action, « Écouter », starts listening like the home button.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../day/day_times.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/birdygo_silhouette.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_sheet.dart';
import '../summary/summary_text.dart';
import 'day_strip.dart';

/// Opens the sheet. [caption] is the date line (« Mardi 29 septembre ·
/// Lieu »); [onListen] runs once the sheet is closed.
Future<void> showDaySheet(
  BuildContext context, {
  required DayTimes times,
  required String caption,
  required VoidCallback onListen,
  DayMoment? highlighted,
}) {
  return showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (sheetContext) => DaySheet(
          times: times,
          caption: caption,
          highlighted: highlighted,
          onListen: () {
            Navigator.of(sheetContext).pop();
            onListen();
          },
        ),
  );
}

class DaySheet extends StatefulWidget {
  const DaySheet({
    super.key,
    required this.times,
    required this.caption,
    required this.onListen,
    this.highlighted,
  });

  final DayTimes times;
  final String caption;
  final VoidCallback onListen;

  /// Moment shown with a 2 px accent border.
  final DayMoment? highlighted;

  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // The touched moment can sit below the fold on a small phone.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target, alignment: 0.3);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final times = widget.times;
    String at(DateTime t) => summaryTime(l10n, t);
    String range(TimeSpan span) => '${at(span.start)} → ${at(span.end)}';

    Widget row({
      required DayMoment moment,
      required Widget icon,
      required String title,
      required String time,
      required String text,
    }) => _MomentRow(
      key: widget.highlighted == moment ? _highlightKey : null,
      highlighted: widget.highlighted == moment,
      icon: icon,
      title: title,
      time: time,
      text: text,
    );

    final birds = _TintedGroup(
      color: c.tonal,
      headerColor: c.accentText,
      headerIcon: AppIcons.musicNote,
      header: l10n.forkDayBirdsHeader,
      rows: [
        row(
          moment: DayMoment.morningBirds,
          icon: BirdyGoSilhouetteIcon(size: 24, color: c.accentText),
          title: l10n.forkDayMorningTitle,
          time: range(times.morningBirds),
          text: l10n.forkDayMorningText,
        ),
        row(
          moment: DayMoment.eveningBirds,
          icon: BirdyGoSilhouetteIcon(size: 24, color: c.accentText),
          title: l10n.forkDayEveningTitle,
          time: range(times.eveningBirds),
          text: l10n.forkDayEveningText,
        ),
      ],
    );
    final sun = _TintedGroup(
      color: c.orioleContainer,
      headerColor: c.orioleText,
      headerIcon: AppIcons.wbSunny,
      header: l10n.forkDaySunHeader,
      rows: [
        row(
          moment: DayMoment.sunrise,
          icon: Icon(AppIcons.wbSunny, size: 22, color: c.orioleText, fill: 1),
          title: l10n.forkDaySunriseTitle,
          time: at(times.sunrise),
          text: l10n.forkDaySunriseText,
        ),
        row(
          moment: DayMoment.goldenHour,
          icon: Icon(
            AppIcons.autoAwesome,
            size: 22,
            color: c.orioleText,
            fill: 1,
          ),
          title: l10n.forkDayGoldenTitle,
          time: '${at(times.goldenHour)} → ${at(times.sunset)}',
          text: l10n.forkDayGoldenText,
        ),
        row(
          moment: DayMoment.sunset,
          icon: Icon(
            AppIcons.wbTwilight,
            size: 22,
            color: c.probable.foreground,
          ),
          title: l10n.forkDaySunsetTitle,
          time: at(times.sunset),
          text: l10n.forkDaySunsetText,
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.xs,
                BirdySpace.page,
                BirdySpace.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.forkDaySheetTitle,
                      style: BirdyText.title.copyWith(color: c.text1),
                    ),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    widget.caption,
                    style: BirdyText.bodyCompact.copyWith(color: c.text2),
                  ),
                  const SizedBox(height: BirdySpace.l),
                  birds,
                  const SizedBox(height: BirdySpace.block),
                  sun,
                ],
              ),
            ),
          ),
          Padding(
            // Room for the button's glow.
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.page,
              BirdySpace.s,
              BirdySpace.page,
              BirdySpace.m,
            ),
            child: ListenButton(onPressed: widget.onListen),
          ),
        ],
      ),
    );
  }
}

/// A tinted block: a 13 bold header with its icon, then the rows.
class _TintedGroup extends StatelessWidget {
  const _TintedGroup({
    required this.color,
    required this.headerColor,
    required this.headerIcon,
    required this.header,
    required this.rows,
  });

  final Color color;
  final Color headerColor;
  final IconData headerIcon;
  final String header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.s,
          BirdySpace.m,
          BirdySpace.s,
          BirdySpace.s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: BirdySpace.s,
                bottom: BirdySpace.xs,
              ),
              child: Row(
                children: [
                  Icon(headerIcon, size: 18, color: headerColor, fill: 1),
                  const SizedBox(width: BirdySpace.s),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        header,
                        style: BirdyText.badge.copyWith(color: headerColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

/// One moment: a white disc, the name and time on one baseline, the text.
class _MomentRow extends StatelessWidget {
  const _MomentRow({
    super.key,
    required this.highlighted,
    required this.icon,
    required this.title,
    required this.time,
    required this.text,
  });

  final bool highlighted;
  final Widget icon;
  final String title;
  final String time;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BirdyRadii.inset),
        border:
            highlighted
                ? Border.all(color: c.accent, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.s,
        vertical: BirdySpace.s,
      ),
      child: Semantics(
        container: true,
        label: '$title, $time. $text',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: BirdySizes.rowDisc,
              height: BirdySizes.rowDisc,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface1,
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            const SizedBox(width: BirdySpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: BirdyText.label.copyWith(color: c.text1),
                        ),
                      ),
                      const SizedBox(width: BirdySpace.s),
                      Text(
                        time,
                        style: BirdyText.labelCompact.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(text, style: BirdyText.caption.copyWith(color: c.text2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
