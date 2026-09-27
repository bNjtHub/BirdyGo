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
import '../game/game_loader.dart';
import '../game/status_celebration.dart';
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
  var _saving = false;
  var _savingObservation = false;
  var _loadVersion = 0;
  Future<void> _pendingSave = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _place = _session.locationName;
    unawaited(_load());
    if (_place == null) unawaited(_resolvePlace());
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
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
    if (mounted && version == _loadVersion && identical(session, _session)) {
      setState(() => _summary = summary);
    }
  }

  /// Serialize edits with place-name updates, and only adopt a changed
  /// session after it has been saved successfully.
  Future<void> _saveChanges(void Function(LiveSession session) change) async {
    final repository = ref.read(sessionRepositoryProvider);
    final save = _pendingSave.then((_) async {
      final updated = LiveSession.fromJson(_session.toJson());
      change(updated);
      await repository.save(updated);
      _session = updated;
      if (mounted) ref.invalidate(sessionListProvider);
    });
    _pendingSave = save.catchError((Object _) {});
    await save;
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
    try {
      await _saveChanges((session) => session.locationName = name);
      if (mounted) await _load();
    } catch (error) {
      debugPrint('Could not save the listening place: $error');
    }
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

  /// « C'était un enregistrement ? » (J5c). Saving re-indexes the session,
  /// which takes it out of (or back into) every count.
  Future<void> _markRecording(bool recording) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveChanges((session) => session.practice = recording);
      if (mounted) await _load();
    } catch (error) {
      debugPrint('Could not save the listening type: $error');
      if (mounted) _showSaveFailure();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addObservation() async {
    if (_saving || _summary?.isRecording != false) return;
    final result = await Navigator.of(context).push<AddSpeciesResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => AddSpeciesOverlay(
              sessionStart: _session.startTime,
              positionSec: 0,
              existingDetections: _session.detections,
              initialMode: AddSpeciesInsertMode.global,
              initialEvidence: DetectionEvidence.seen,
              lockMode: true,
              titleOverride:
                  AppLocalizations.of(context)!.forkSummaryAddObservation,
            ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _saving = true;
      _savingObservation = true;
    });
    try {
      await _saveChanges((session) {
        session.detections.add(
          DetectionRecord(
            scientificName: result.scientificName,
            commonName: result.commonName,
            confidence: 1,
            timestamp: session.startTime,
            source:
                result.userSpecified
                    ? DetectionSource.userSpecified
                    : DetectionSource.manualGlobal,
            evidence: result.evidence,
            latitude: session.latitude,
            longitude: session.longitude,
            reviewStatus: ReviewStatus.confirmed,
            reviewedAt: DateTime.now().toUtc(),
          ),
        );
      });
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.sessionSaved)),
        );
      }
    } catch (error) {
      debugPrint('Could not save the observed bird: $error');
      if (mounted) _showSaveFailure();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _savingObservation = false;
        });
      }
    }
  }

  void _showSaveFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.forkSummaryObservationSaveFailed,
        ),
      ),
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _reload();
  }

  void _done() {
    if (!_saving) Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
    // J6e: a new status plays here, after « Arrêter », once the index knows
    // the session.
    ref.listen(gameProgressProvider, (_, next) {
      if (next.value case final progress?) {
        unawaited(maybeCelebrateStatus(context, ref, progress));
      }
    });
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
        onDone: _saving ? null : _done,
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
        onCheck:
            _saving ? null : (keys) => _push(QuickReviewScreen(onlyKeys: keys)),
        onDetails:
            _saving
                ? null
                : () => _push(SessionReviewScreen(session: _session)),
        onAddObservation:
            summary.isRecording || _saving ? null : _addObservation,
        savingObservation: _savingObservation,
        // A file analysis never counts: nothing to mark.
        onMarkRecording:
            _session.type == SessionType.fileUpload || _saving
                ? null
                : _markRecording,
        footer: LpoSendButton(session: _session),
      ),
    );
  }
}
