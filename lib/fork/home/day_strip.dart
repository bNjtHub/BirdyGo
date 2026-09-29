/// « Ta journée » strip of the home screen (J6h): five pills, centered, that
/// never wrap (they scale down instead). Touching one opens the day sheet.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../day/day_times.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/birdygo_silhouette.dart';
import '../design/widgets/pressable.dart';
import '../summary/summary_text.dart';

/// The moments of the listening day, in the order of the strip.
enum DayMoment { morningBirds, sunrise, goldenHour, eveningBirds, sunset }

/// Time a [DayMoment] is announced at (the start of its span).
DateTime dayMomentTime(DayTimes times, DayMoment moment) => switch (moment) {
  DayMoment.morningBirds => times.morningBirds.start,
  DayMoment.sunrise => times.sunrise,
  DayMoment.goldenHour => times.goldenHour,
  DayMoment.eveningBirds => times.eveningBirds.start,
  DayMoment.sunset => times.sunset,
};

/// Name of a [DayMoment] in the strip.
String dayMomentLabel(AppLocalizations l10n, DayMoment moment) =>
    switch (moment) {
      DayMoment.morningBirds => l10n.forkDayMorningBirds,
      DayMoment.sunrise => l10n.forkDaySunrise,
      DayMoment.goldenHour => l10n.forkDayGoldenHour,
      DayMoment.eveningBirds => l10n.forkDayEveningBirds,
      DayMoment.sunset => l10n.forkDaySunset,
    };

class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.times, required this.onMoment});

  final DayTimes times;

  /// A pill was touched.
  final ValueChanged<DayMoment> onMoment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l10n.forkDayStripLabel,
      child: SizedBox(
        // Room for the 48 dp tap targets around the 26 dp pills.
        height: BirdySizes.target,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, moment) in DayMoment.values.indexed) ...[
                if (i > 0) const SizedBox(width: BirdySpace.xs),
                _DayPill(
                  key: ValueKey('day-pill-${moment.name}'),
                  moment: moment,
                  time: summaryTime(l10n, dayMomentTime(times, moment)),
                  label: dayMomentLabel(l10n, moment),
                  onTap: () => onMoment(moment),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    super.key,
    required this.moment,
    required this.time,
    required this.label,
    required this.onTap,
  });

  final DayMoment moment;
  final String time;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final (background, foreground, icon) = switch (moment) {
      DayMoment.morningBirds || DayMoment.eveningBirds => (
        c.tonal,
        c.accentText,
        BirdyGoSilhouetteIcon.glyph(size: _iconSize, color: c.accentText),
      ),
      DayMoment.sunrise => (
        c.surface1,
        c.text1,
        Icon(AppIcons.wbSunny, size: _iconSize, color: c.orioleText, fill: 1),
      ),
      DayMoment.goldenHour => (
        c.orioleContainer,
        c.orioleText,
        Icon(
          AppIcons.autoAwesome,
          size: _iconSize,
          color: c.orioleText,
          fill: 1,
        ),
      ),
      DayMoment.sunset => (
        c.surface1,
        c.text1,
        Icon(
          AppIcons.wbTwilight,
          size: _iconSize,
          color: c.probable.foreground,
        ),
      ),
    };
    return Semantics(
      button: true,
      label: '$label $time',
      excludeSemantics: true,
      child: Pressable(
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BirdySizes.target),
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: background,
                  shape: const StadiumBorder(),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BirdySizes.pill),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(5, 4, 7, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(width: BirdySpace.tight),
                        Text(
                          time,
                          style: BirdyText.badge.copyWith(
                            color: foreground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _iconSize = 15;
}
