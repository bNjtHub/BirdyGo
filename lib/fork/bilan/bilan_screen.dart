/// Bilan of a listening session (J6c, fork/maquette/Resume.dc.html and
/// SPEC.md 9.8), opened when the listening stops.
///
/// The status, badge and « Ta 24e espèce » blocks of the mockup come with
/// the game (J6e).
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../features/history/session_review_screen.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/share_sheet.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';
import '../lpo/lpo_send_button.dart';
import '../map/contact_map_screen.dart';
import '../reliability/quick_review_screen.dart';
import 'bilan_loader.dart';
import 'bilan_model.dart';
import 'bilan_text.dart';
import 'bilan_widgets.dart';

/// Widest column on tablets and in landscape.
const double _maxWidth = 600;

class BilanScreen extends ConsumerStatefulWidget {
  const BilanScreen({super.key, required this.session});

  /// The session that just ended, already saved.
  final LiveSession session;

  @override
  ConsumerState<BilanScreen> createState() => _BilanScreenState();
}

class _BilanScreenState extends ConsumerState<BilanScreen> {
  late LiveSession _session = widget.session;
  BilanInputs? _inputs;
  String? _place;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_reload(withPlace: true));
  }

  /// Reads the session again (reviews made meanwhile) and its context.
  Future<void> _reload({bool withPlace = false}) async {
    final generation = ++_generation;
    final loader = ref.read(bilanLoaderProvider);
    final inputs = await loader.load(_session);
    if (!mounted || generation != _generation) return;
    setState(() {
      _inputs = inputs;
      _session = inputs.session;
      _place ??= inputs.session.locationName;
    });
    if (withPlace && _place == null) {
      final place = await loader.placeName(inputs.session);
      if (mounted && place != null) setState(() => _place = place);
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _reload();
  }

  void _openSheet(BilanSpecies species) => SpeciesInfoOverlay.show(
    context,
    ref,
    scientificName: species.scientificName,
    commonName: species.commonName,
  );

  Future<void> _share(BilanSummary summary, Rect origin) {
    final l10n = AppLocalizations.of(context)!;
    final text = bilanShareText(
      l10n,
      Localizations.localeOf(context).toString(),
      summary,
      place: _place,
    );
    return reportShareFailure(
      context,
      SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    ImageProvider? imageOf(String name) {
      final path = taxonomy?.assetImagePath(name);
      return path == null ? null : AssetImage(path);
    }

    final inputs = _inputs;
    final summary = buildBilan(
      session: _session,
      presence: inputs?.presence ?? const {},
      heardBefore: inputs?.heardBefore,
      skippedKeys: inputs?.skippedKeys ?? const {},
      localizedName:
          (record) =>
              taxonomy
                  ?.lookup(record.scientificName)
                  ?.commonNameForLocale(speciesLocale) ??
              record.commonName,
    );
    final ready = inputs != null;
    final lat = _session.latitude;
    final lon = _session.longitude;
    final noveltyHeading = ready ? bilanNoveltyHeading(l10n, summary) : null;
    final toVerify = summary.toVerifyKeys;

    // Blocks that depend on the loaded context (levels, novelties) appear
    // once it is there, with their own entrance: no badge changes under
    // the finger.
    final blocks = <(String, Widget)>[
      (
        'hero',
        BilanHero(
          title: bilanTitle(l10n, summary),
          dateLine: bilanDateLine(l10n, localeName, summary, place: _place),
        ),
      ),
      if (summary.isEmpty)
        (
          'empty',
          Text(
            l10n.forkBilanEmptyBody,
            style: BirdyText.body.copyWith(color: c.text2),
          ),
        )
      else
        (
          'numbers',
          BilanNumbers(
            figures: [
              BilanFigure(
                '${summary.species.length}',
                l10n.forkLiveSpeciesStat(summary.species.length),
              ),
              BilanFigure(
                '${summary.contacts}',
                l10n.forkLiveContactsStat(summary.contacts),
              ),
              BilanFigure(
                bilanDuration(l10n, summary.duration),
                l10n.forkLiveDuration,
              ),
            ],
          ),
        ),
      if (noveltyHeading != null)
        (
          'novelties',
          _Novelties(
            heading: noveltyHeading,
            summary: summary,
            imageOf: imageOf,
            onOpen: _openSheet,
            onVerify:
                (species) =>
                    _push(QuickReviewScreen(keys: species.toVerifyKeys)),
          ),
        ),
      if (ready && !summary.isEmpty)
        (
          'strip',
          BilanSpeciesStrip(
            species: summary.species,
            imageOf: imageOf,
            onTap: _openSheet,
          ),
        ),
      if (ready && toVerify.isNotEmpty)
        (
          'verify',
          Pressable(
            child: FilledButton.icon(
              style: BirdyButtonStyles.primary(context),
              onPressed: () => _push(QuickReviewScreen(keys: toVerify)),
              icon: const Icon(AppIcons.check),
              label: Text(l10n.forkBilanVerify(toVerify.length)),
            ),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              padding: const EdgeInsets.only(
                top: BirdySpace.l,
                bottom: BirdySpace.xxl,
              ),
              children: [
                _gutter(
                  BilanTopBar(
                    onClose: () => Navigator.of(context).maybePop(),
                    onMap:
                        lat == null || lon == null
                            ? null
                            : () => _push(
                              ContactMapScreen(focus: LatLng(lat, lon)),
                            ),
                    onShare: (origin) => _share(summary, origin),
                  ),
                ),
                for (var i = 0; i < blocks.length; i++)
                  Padding(
                    key: ValueKey('bilan-${blocks[i].$1}'),
                    padding: const EdgeInsets.fromLTRB(
                      BirdySpace.xl,
                      BirdySpace.m,
                      BirdySpace.xl,
                      0,
                    ),
                    child: BirdyEntrance.staggered(
                      index: i,
                      child: blocks[i].$2,
                    ),
                  ),
                // Its own padding and caption (J5b).
                if (!summary.isEmpty) LpoSendButton(session: _session),
                _gutter(
                  Center(
                    child: TextButton(
                      onPressed:
                          () => _push(
                            SessionReviewScreen(
                              session: _session,
                              autoSaved: true,
                            ),
                          ),
                      child: Text(l10n.forkBilanDetails),
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

  Widget _gutter(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: BirdySpace.xl),
    child: child,
  );
}

/// « Une nouvelle, peut-être deux », the « Première fois » cards and the new
/// species still to check.
class _Novelties extends StatelessWidget {
  const _Novelties({
    required this.heading,
    required this.summary,
    required this.imageOf,
    required this.onOpen,
    required this.onVerify,
  });

  final String heading;
  final BilanSummary summary;
  final SpeciesImageOf imageOf;
  final ValueChanged<BilanSpecies> onOpen;
  final ValueChanged<BilanSpecies> onVerify;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            heading,
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
        ),
        for (final species in summary.newVerified) ...[
          const SizedBox(height: BirdySpace.s),
          BilanFirstTimeCard(
            species: species,
            caption: l10n.forkBilanFirstHeardAt(
              bilanClock(l10n, species.firstHeard),
            ),
            image: imageOf(species.scientificName),
            onTap: () => onOpen(species),
          ),
        ],
        for (final species in summary.newPending) ...[
          const SizedBox(height: BirdySpace.s),
          BilanPendingRow(
            species: species,
            image: imageOf(species.scientificName),
            onTap:
                () =>
                    species.toVerifyKeys.isEmpty
                        ? onOpen(species)
                        : onVerify(species),
          ),
        ],
      ],
    );
  }
}
