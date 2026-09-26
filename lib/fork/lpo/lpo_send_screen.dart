/// « Envoyer à la LPO »: guided, never automatic, reporting of confirmed
/// observations on Faune-France (fork/PLAN.md J5b).
///
/// Nothing leaves the phone from here except what the observer copies,
/// shares or opens: no network call, no account, no password.
library;

import 'dart:io';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/announcements/geo_commonness_provider.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/history/services/share_file_params.dart';
import '../../features/inference/geo_model.dart';
import '../../features/live/live_session.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/share_sheet.dart';
import '../reliability/geo_presence_service.dart';
import 'atlas_codes.dart';
import 'lpo_config.dart';
import 'lpo_observation.dart';
import 'lpo_report.dart';

/// Lists the confirmed observations of [session] as cards to report.
class LpoSendScreen extends ConsumerStatefulWidget {
  const LpoSendScreen({super.key, required this.session, this.detections});

  final LiveSession session;

  /// Current detections when they differ from the saved session (the
  /// review screen's working copy). Defaults to the session's.
  final List<DetectionRecord>? detections;

  @override
  ConsumerState<LpoSendScreen> createState() => _LpoSendScreenState();
}

class _LpoSendScreenState extends ConsumerState<LpoSendScreen> {
  late final List<LpoObservation> _observations;
  late final int _notConfirmed;
  final Map<int, LpoGeoStatus?> _geoAtPlace = {};

  @override
  void initState() {
    super.initState();
    final detections = widget.detections ?? widget.session.detections;
    _observations = lpoObservations(widget.session, detections: detections);
    _notConfirmed = detections.where((d) => !lpoEligible(d)).length;
    _loadGeoAtPlace();
  }

  /// Rarity at each observation's own place and week, for observations
  /// the current-place commonness map does not cover.
  Future<void> _loadGeoAtPlace() async {
    final service = ref.read(geoPresenceServiceProvider);
    for (var i = 0; i < _observations.length; i++) {
      final o = _observations[i];
      final presence = await service.presenceAt(
        o.scientificName,
        latitude: o.latitude,
        longitude: o.longitude,
        time: o.time,
      );
      if (!mounted) return;
      setState(() => _geoAtPlace[i] = geoStatusFromPresence(presence));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final now = DateTime.now();
    // The current-place map only applies to this week's observations: don't
    // wake the GPS for an old session.
    final thisWeek = GeoModel.dateTimeToWeek(now);
    final mayBeHere = _observations.any(
      (o) =>
          o.hasPosition &&
          GeoModel.dateTimeToWeek(o.time.toLocal()) == thisWeek,
    );
    final commonness =
        mayBeHere ? ref.watch(geoCommonnessProvider).value : null;
    final here = mayBeHere ? ref.watch(currentLocationProvider).value : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forkLpoTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.forkLpoIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          _Note(icon: AppIcons.lockOutline, text: l10n.forkLpoNoPassword),
          if (_notConfirmed > 0)
            _Note(
              icon: AppIcons.infoOutline,
              text: l10n.forkLpoNotConfirmed(_notConfirmed),
            ),
          const SizedBox(height: 12),
          if (_observations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                l10n.forkLpoEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          for (var i = 0; i < _observations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LpoObservationCard(
                key: ValueKey('lpo-${_observations[i].scientificName}-$i'),
                observation: _observations[i],
                frenchName:
                    taxonomy
                        ?.lookup(_observations[i].scientificName)
                        ?.commonNameForLocale('fr') ??
                    _observations[i].commonName,
                alerts: lpoAlerts(
                  _observations[i].scientificName,
                  (isHereAndNow(
                            _observations[i],
                            hereLatitude: here?.latitude,
                            hereLongitude: here?.longitude,
                            now: now,
                          )
                          ? geoStatusFromCommonness(
                            commonness,
                            _observations[i].scientificName,
                          )
                          : null) ??
                      _geoAtPlace[i],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One observation: the alerts, the two questions, then the card to report.
class LpoObservationCard extends StatefulWidget {
  const LpoObservationCard({
    super.key,
    required this.observation,
    required this.frenchName,
    required this.alerts,
  });

  final LpoObservation observation;
  final String frenchName;
  final Set<LpoAlert> alerts;

  @override
  State<LpoObservationCard> createState() => _LpoObservationCardState();
}

class _LpoObservationCardState extends State<LpoObservationCard>
    with AutomaticKeepAliveClientMixin {
  // Answers survive scrolling the card out of the list.
  @override
  bool get wantKeepAlive => true;

  bool? _seen;
  bool? _knowsSong;
  bool _compared = false;
  int _count = 1;
  late AtlasCode? _atlasCode;
  late bool _hideData;
  late final List<AtlasCode> _atlasCodes;

  @override
  void initState() {
    super.initState();
    _atlasCodes = atlasCodesFor(
      widget.observation.scientificName,
      widget.observation.time.toLocal(),
    );
    _atlasCode = _atlasCodes.isEmpty ? null : _atlasCodes.first;
    _hideData = widget.alerts.contains(LpoAlert.sensitive);
  }

  /// The card appears once both questions are answered, and a song the
  /// observer does not know has been compared with xeno-canto.
  bool get _ready => _seen != null && (_knowsSong == true || _compared);

  LpoCardChoices get _choices => LpoCardChoices(
    seen: _seen ?? false,
    count: _count,
    atlasCode: _atlasCode,
    hideData: _hideData,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final o = widget.observation;
    final time = TimeOfDay.fromDateTime(o.time.toLocal()).format(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.frenchName,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        o.scientificName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(time, style: theme.textTheme.titleMedium),
              ],
            ),
            if (widget.alerts.contains(LpoAlert.sensitive)) ...[
              const SizedBox(height: 12),
              _Alert(
                icon: AppIcons.lockOutline,
                text: l10n.forkLpoAlertSensitive,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.forkLpoHideData),
                value: _hideData,
                onChanged: (v) => setState(() => _hideData = v),
              ),
            ],
            if (widget.alerts.contains(LpoAlert.rare)) ...[
              const SizedBox(height: 8),
              _Alert(
                icon: AppIcons.warningAmberRounded,
                text: l10n.forkLpoAlertRare,
              ),
            ],
            if (widget.alerts.contains(LpoAlert.outOfSeason)) ...[
              const SizedBox(height: 8),
              _Alert(
                icon: AppIcons.calendarTodayRounded,
                text: l10n.forkLpoAlertOutOfSeason,
              ),
            ],
            const SizedBox(height: 16),
            _Question(
              label: l10n.forkLpoQuestionSeen,
              yes: l10n.forkLpoYes,
              no: l10n.forkLpoNo,
              value: _seen,
              onChanged: (v) => setState(() => _seen = v),
            ),
            const SizedBox(height: 12),
            _Question(
              label: l10n.forkLpoQuestionSong,
              yes: l10n.forkLpoYes,
              no: l10n.forkLpoNotSure,
              value: _knowsSong,
              onChanged: (v) => setState(() => _knowsSong = v),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(AppIcons.openInNew),
                label: Text(l10n.forkLpoCompareXenoCanto),
                onPressed:
                    () => openExternalUrl(
                      context,
                      LpoConfig.xenoCantoSearch(o.scientificName),
                    ),
              ),
            ),
            if (_knowsSong == false && !_compared) ...[
              Text(l10n.forkLpoCompareFirst, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => setState(() => _compared = true),
                child: Text(l10n.forkLpoCompared),
              ),
            ],
            if (_ready) ...[
              const Divider(height: 32),
              _buildReadyCard(context, l10n, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadyCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final o = widget.observation;
    final lines = lpoReportLines(
      l10n,
      o,
      frenchName: widget.frenchName,
      choices: _choices,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.forkLpoCount, style: theme.textTheme.titleSmall),
            ),
            IconButton(
              tooltip: l10n.forkLpoCountLess,
              icon: const Icon(AppIcons.remove),
              onPressed: _count > 1 ? () => setState(() => _count--) : null,
            ),
            Text(
              '$_count',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: l10n.forkLpoCountMore,
              icon: const Icon(AppIcons.add),
              onPressed:
                  _count < LpoConfig.lpoMaxCount
                      ? () => setState(() => _count++)
                      : null,
            ),
          ],
        ),
        if (_atlasCodes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.forkLpoAtlasTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final code in _atlasCodes)
                ChoiceChip(
                  label: Text(atlasCodeLabel(l10n, code)),
                  selected: _atlasCode == code,
                  onSelected: (_) => setState(() => _atlasCode = code),
                ),
              ChoiceChip(
                label: Text(l10n.forkLpoAtlasNone),
                selected: _atlasCode == null,
                onSelected: (_) => setState(() => _atlasCode = null),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.forkLpoAtlasHint, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            lines.join('\n'),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(AppIcons.contentCopy),
              label: Text(l10n.forkLpoCopy),
              onPressed: () => _copy(context, l10n),
            ),
            if (o.clipPath != null)
              Builder(
                builder:
                    (buttonContext) => OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(AppIcons.share),
                      label: Text(l10n.forkLpoShareClip),
                      onPressed: () => _shareClip(buttonContext, l10n),
                    ),
              ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(AppIcons.openInNew),
              label: Text(l10n.forkLpoOpenNaturaList),
              onPressed:
                  () => openExternalUrl(
                    context,
                    LpoConfig.naturaList(defaultTargetPlatform),
                  ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(AppIcons.openInNew),
              label: Text(l10n.forkLpoOpenFauneFrance),
              onPressed: () => openExternalUrl(context, LpoConfig.fauneFrance),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(
        text: lpoReportText(
          l10n,
          widget.observation,
          frenchName: widget.frenchName,
          choices: _choices,
        ),
      ),
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.forkLpoCopied)));
  }

  Future<void> _shareClip(BuildContext context, AppLocalizations l10n) async {
    final path = widget.observation.clipPath!;
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.forkLpoClipMissing)));
      return;
    }
    await reportShareFailure(
      context,
      SharePlus.instance.share(
        shareParamsForFile(
          path,
          text: '${widget.frenchName} (${widget.observation.scientificName})',
          sharePositionOrigin: shareOriginFrom(context),
        ),
      ),
    );
  }
}

/// Yes / no question with two segments; nothing selected at first.
class _Question extends StatelessWidget {
  const _Question({
    required this.label,
    required this.yes,
    required this.no,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String yes;
  final String no;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(yes)),
            ButtonSegment(value: false, label: Text(no)),
          ],
          selected: value == null ? const <bool>{} : {value!},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) onChanged(s.first);
          },
        ),
      ],
    );
  }
}

/// Tinted warning line.
class _Alert extends StatelessWidget {
  const _Alert({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet information line.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
