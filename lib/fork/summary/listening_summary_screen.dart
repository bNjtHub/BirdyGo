/// « Bilan de l'écoute »: opens after « Arrêter » when the session was saved
/// (fork/PLAN.md J6c). Wires [ListeningSummaryView] to the index, the
/// geo-model and the other screens.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../features/history/session_review_screen.dart';
import '../../features/live/live_providers.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/share_sheet.dart';
import '../lpo/lpo_send_button.dart';
import '../map/contact_map_screen.dart';
import '../reliability/quick_review_screen.dart';
import 'listening_summary.dart';
import 'listening_summary_loader.dart';
import 'listening_summary_view.dart';
import 'summary_text.dart';

class ListeningSummaryScreen extends ConsumerStatefulWidget {
  const ListeningSummaryScreen({super.key, required this.session});

  /// The session just stopped, already saved.
  final LiveSession session;

  @override
  ConsumerState<ListeningSummaryScreen> createState() =>
      _ListeningSummaryScreenState();
}

class _ListeningSummaryScreenState
    extends ConsumerState<ListeningSummaryScreen> {
  late LiveSession _session = widget.session;
  ListeningSummary? _summary;
  String? _place;

  @override
  void initState() {
    super.initState();
    _place = _session.locationName;
    unawaited(_load());
    if (_place == null) unawaited(_resolvePlace());
  }

  Future<void> _load() async {
    final session = _session;
    ListeningSummary summary;
    try {
      summary = await ref.read(listeningSummaryLoaderProvider)(session);
    } catch (error) {
      debugPrint('Listening summary without the index: $error');
      // Without the index, no species can be called a first.
      summary = ListeningSummary.of(
        session,
        verifiedBefore: {for (final d in session.detections) d.scientificName},
      );
    }
    if (mounted) setState(() => _summary = summary);
  }

  /// Same place name as the session review, which also keeps it.
  Future<void> _resolvePlace() async {
    final lat = _session.latitude;
    final lon = _session.longitude;
    if (lat == null || lon == null) return;
    final name = await reverseGeocode(
      latitude: lat,
      longitude: lon,
      localeName: ref.read(effectiveAppLocaleProvider),
    );
    if (name == null || !mounted) return;
    setState(() => _place = name);
    _session.locationName = name;
    await ref.read(sessionRepositoryProvider).save(_session);
  }

  /// Reloads the session after a review changed it.
  Future<void> _reload() async {
    final saved = await ref.read(sessionRepositoryProvider).load(_session.id);
    if (!mounted) return;
    if (saved == null) {
      // Deleted from the session review: nothing left to sum up.
      _done();
      return;
    }
    _session = saved;
    await _load();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _reload();
  }

  void _done() => Navigator.of(context).popUntil((route) => route.isFirst);

  Future<void> _share(
    ListeningSummary summary,
    String Function(SummarySpecies) nameOf,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await reportShareFailure(
      context,
      SharePlus.instance.share(
        ShareParams(
          text: summaryShareText(l10n, summary, nameOf: nameOf),
          sharePositionOrigin: shareOriginFrom(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    String nameOf(SummarySpecies s) =>
        taxonomy
            ?.lookup(s.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        s.commonName;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: ListeningSummaryView(
        summary: summary,
        place: _place,
        nameOf: nameOf,
        imageFor: (name) {
          final path = taxonomy?.assetImagePath(name);
          return path == null ? null : AssetImage(path);
        },
        onDone: _done,
        onMap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContactMapScreen()),
            ),
        onShare: () => _share(summary, nameOf),
        onOpenSpecies:
            (s) => SpeciesInfoOverlay.show(
              context,
              ref,
              scientificName: s.scientificName,
              commonName: nameOf(s),
            ),
        onCheck: (keys) => _push(QuickReviewScreen(onlyKeys: keys)),
        onDetails: () => _push(SessionReviewScreen(session: _session)),
        footer: LpoSendButton(session: _session),
      ),
    );
  }
}
