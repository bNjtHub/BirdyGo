/// « Envoyer à la LPO »: guided, never automatic, reporting of confirmed
/// observations on Faune-France (fork/PLAN.md J5b).
///
/// Nothing leaves the phone from here except what the observer copies,
/// shares or opens: no network call, no account, no password.
/// Look of J6c: BirdyGo top bar, cards, alerts and buttons.
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
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/share_sheet.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_switch.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/species_avatar.dart';
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
  static ImageProvider? _imageOf(TaxonomyService? taxonomy, String name) {
    final path = taxonomy?.assetImagePath(name);
    return path == null ? null : AssetImage(path);
  }

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
    final c = BirdyColors.of(context);
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
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.s,
                BirdySpace.page,
                BirdySpace.xxxl,
              ),
              children: [
                BirdyOverlayHeader(title: l10n.forkLpoTitle),
                const SizedBox(height: BirdySpace.s),
                BirdyBlock(
                  tone: BirdyBlockTone.tonal,
                  radius: BirdyRadii.hero,
                  padding: const EdgeInsets.all(BirdySpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.forkLpoIntro,
                        style: BirdyText.body.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: BirdySpace.s),
                      _Note(
                        icon: AppIcons.lockOutline,
                        text: l10n.forkLpoNoPassword,
                      ),
                      if (_notConfirmed > 0)
                        _Note(
                          icon: AppIcons.infoOutline,
                          text: l10n.forkLpoNotConfirmed(_notConfirmed),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                if (_observations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: BirdySpace.m),
                    // Detections exist, none confirmed: a filter, not a void.
                    child: BirdyEmptyState.inline(
                      kind: BirdyEmptyKind.filtered,
                      icon: AppIcons.checkCircleOutline,
                      title: l10n.forkLpoEmptyTitle,
                      body: l10n.forkLpoEmpty,
                    ),
                  ),
                for (var i = 0; i < _observations.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: BirdySpace.block),
                    child: LpoObservationCard(
                      key: ValueKey(
                        'lpo-${_observations[i].scientificName}-$i',
                      ),
                      observation: _observations[i],
                      // French on purpose: the report feeds Faune-France, a
                      // French database. The card header uses displayName.
                      frenchName:
                          taxonomy
                              ?.lookup(_observations[i].scientificName)
                              ?.commonNameForLocale('fr') ??
                          _observations[i].commonName,
                      displayName:
                          taxonomy
                              ?.lookup(_observations[i].scientificName)
                              ?.commonNameForLocale(
                                ref.watch(effectiveSpeciesLocaleProvider),
                              ),
                      image: _imageOf(
                        taxonomy,
                        _observations[i].scientificName,
                      ),
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
          ),
        ),
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
    this.displayName,
    required this.alerts,
    this.image,
  });

  final LpoObservation observation;
  final String frenchName;

  /// Name in the user's locale, shown in the card header (the report keeps
  /// [frenchName]); falls back to [frenchName].
  final String? displayName;
  final Set<LpoAlert> alerts;

  /// Species photo from the bundle.
  final ImageProvider? image;

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
    final c = BirdyColors.of(context);
    final o = widget.observation;
    final time = TimeOfDay.fromDateTime(o.time.toLocal()).format(context);

    return BirdyBlock(
      padding: const EdgeInsets.all(BirdySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SpeciesAvatar(
                image: widget.image,
                tint: SpeciesAccents.tintOf(o.scientificName),
                size: BirdySizes.target,
              ),
              const SizedBox(width: BirdySpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.displayName ?? widget.frenchName,
                      style: BirdyText.species.copyWith(color: c.text1),
                    ),
                    Text(
                      o.scientificName,
                      style: BirdyText.latin.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
              Text(time, style: BirdyText.numberM.copyWith(color: c.text1)),
            ],
          ),
          if (widget.alerts.contains(LpoAlert.sensitive)) ...[
            const SizedBox(height: BirdySpace.m),
            _Alert(
              icon: AppIcons.lockOutline,
              text: l10n.forkLpoAlertSensitive,
              background: c.probable.background,
              foreground: c.probable.foreground,
            ),
            const SizedBox(height: BirdySpace.xs),
            _SwitchRow(
              label: l10n.forkLpoHideData,
              value: _hideData,
              onChanged: (v) => setState(() => _hideData = v),
            ),
          ],
          if (widget.alerts.contains(LpoAlert.rare)) ...[
            const SizedBox(height: BirdySpace.s),
            _Alert(
              icon: AppIcons.diamond,
              text: l10n.forkLpoAlertRare,
              background: c.orioleContainer,
              foreground: c.orioleText,
            ),
          ],
          if (widget.alerts.contains(LpoAlert.outOfSeason)) ...[
            const SizedBox(height: BirdySpace.s),
            _Alert(
              icon: AppIcons.calendarTodayRounded,
              text: l10n.forkLpoAlertOutOfSeason,
              background: c.orioleContainer,
              foreground: c.orioleText,
            ),
          ],
          const SizedBox(height: BirdySpace.l),
          _Question(
            label: l10n.forkLpoQuestionSeen,
            yes: l10n.forkLpoYes,
            no: l10n.forkLpoNo,
            value: _seen,
            onChanged: (v) => setState(() => _seen = v),
          ),
          const SizedBox(height: BirdySpace.m),
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
              style: TextButton.styleFrom(
                minimumSize: const Size(BirdySizes.target, BirdySizes.target),
                foregroundColor: c.accentText,
              ),
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
            Text(
              l10n.forkLpoCompareFirst,
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
            const SizedBox(height: BirdySpace.s),
            FilledButton(
              style: BirdyButtonStyles.tonal(context),
              onPressed: () => setState(() => _compared = true),
              child: Text(l10n.forkLpoCompared),
            ),
          ],
          if (_ready) ...[
            Divider(height: BirdySpace.xxxl, color: c.line),
            _buildReadyCard(context, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildReadyCard(BuildContext context, AppLocalizations l10n) {
    final c = BirdyColors.of(context);
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
              child: Text(
                l10n.forkLpoCount,
                style: BirdyText.label.copyWith(color: c.text1),
              ),
            ),
            BirdyIconButton(
              semanticLabel: l10n.forkLpoCountLess,
              icon: AppIcons.remove,
              onPressed: _count > 1 ? () => setState(() => _count--) : null,
            ),
            SizedBox(
              width: BirdySizes.target,
              child: Text(
                '$_count',
                textAlign: TextAlign.center,
                style: BirdyText.numberM.copyWith(color: c.text1),
              ),
            ),
            BirdyIconButton(
              semanticLabel: l10n.forkLpoCountMore,
              icon: AppIcons.add,
              onPressed:
                  _count < LpoConfig.lpoMaxCount
                      ? () => setState(() => _count++)
                      : null,
            ),
          ],
        ),
        if (_atlasCodes.isNotEmpty) ...[
          const SizedBox(height: BirdySpace.s),
          Text(
            l10n.forkLpoAtlasTitle,
            style: BirdyText.label.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.s),
          Wrap(
            spacing: BirdySpace.s,
            runSpacing: BirdySpace.s,
            children: [
              for (final code in _atlasCodes)
                BirdyFilterChip(
                  label: atlasCodeLabel(l10n, code),
                  selected: _atlasCode == code,
                  onSelected: () => setState(() => _atlasCode = code),
                ),
              BirdyFilterChip(
                label: l10n.forkLpoAtlasNone,
                selected: _atlasCode == null,
                onSelected: () => setState(() => _atlasCode = null),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkLpoAtlasHint,
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
        ],
        const SizedBox(height: BirdySpace.m),
        SizedBox(
          width: double.infinity,
          child: BirdyBlock(
            tone: BirdyBlockTone.tonal,
            radius: BirdyRadii.inset,
            padding: const EdgeInsets.all(BirdySpace.m),
            child: SelectableText(
              lines.join('\n'),
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
          ),
        ),
        const SizedBox(height: BirdySpace.m),
        Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.s,
          children: [
            FilledButton.icon(
              style: BirdyButtonStyles.primary(context),
              icon: const Icon(AppIcons.contentCopy),
              label: Text(l10n.forkLpoCopy),
              onPressed: () => _copy(context, l10n),
            ),
            if (o.clipPath != null)
              Builder(
                builder:
                    (buttonContext) => OutlinedButton.icon(
                      style: BirdyButtonStyles.secondary(context),
                      icon: const Icon(AppIcons.share),
                      label: Text(l10n.forkLpoShareClip),
                      onPressed: () => _shareClip(buttonContext, l10n),
                    ),
              ),
            OutlinedButton.icon(
              style: BirdyButtonStyles.secondary(context),
              icon: const Icon(AppIcons.openInNew),
              label: Text(l10n.forkLpoOpenNaturaList),
              onPressed:
                  () => openExternalUrl(
                    context,
                    LpoConfig.naturaList(defaultTargetPlatform),
                  ),
            ),
            OutlinedButton.icon(
              style: BirdyButtonStyles.secondary(context),
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

/// Yes / no question with two chips; nothing selected at first.
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
        Text(
          label,
          style: BirdyText.label.copyWith(color: BirdyColors.of(context).text1),
        ),
        const SizedBox(height: BirdySpace.s),
        Wrap(
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.s,
          children: [
            BirdyFilterChip(
              label: yes,
              selected: value == true,
              onSelected: () => onChanged(true),
            ),
            BirdyFilterChip(
              label: no,
              selected: value == false,
              onSelected: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

/// A label and a [BirdySwitch]; the whole row toggles.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: BirdyText.bodyCompact.copyWith(color: c.text1),
                ),
              ),
              const SizedBox(width: BirdySpace.m),
              // The row's InkWell owns the tap: the switch only paints.
              IgnorePointer(
                child: BirdySwitch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tinted warning line.
class _Alert extends StatelessWidget {
  const _Alert({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BirdySpace.m),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: BirdySizes.blockIcon, fill: 1, color: foreground),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Text(
              text,
              style: BirdyText.bodyCompact.copyWith(color: foreground),
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
    final c = BirdyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: BirdySpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: BirdySizes.tipIcon, color: c.text2),
          const SizedBox(width: BirdySpace.s),
          Expanded(
            child: Text(
              text,
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
          ),
        ],
      ),
    );
  }
}
