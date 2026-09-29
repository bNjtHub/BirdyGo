/// « Bilan de l'écoute »: opens after « Arrêter » (fork/PLAN.md J6c), whether
/// the session was saved or not (J6g-e). Wires [ListeningSummaryView] to the index, the
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
import '../lpo/lpo_send_screen.dart';
import '../map/contact_map_screen.dart';
import '../practice/practice.dart';
import '../reliability/quick_review_screen.dart';
import 'listening_summary.dart';
import 'listening_summary_loader.dart';
import 'listening_summary_view.dart';
import 'summary_text.dart';

class ListeningSummaryScreen extends ConsumerStatefulWidget {
  const ListeningSummaryScreen({
    super.key,
    required this.session,
    this.saved = true,
    this.fromLive = true,
  });

  /// The session to sum up.
  final LiveSession session;

  /// False when the user turned off automatic saving (J6g-e): the Bilan then
  /// shows what was heard with a « non enregistrée » note, offers to save it,
  /// asks before leaving, and keeps the session out of the index and the
  /// library until it is saved.
  final bool saved;

  /// Opened right after « Arrêter »: closing goes back to the first route.
  /// False when opened from elsewhere (see `openListeningSummary`): closing
  /// pops one level, back to where the user came from.
  final bool fromLive;

  @override
  ConsumerState<ListeningSummaryScreen> createState() =>
      _ListeningSummaryScreenState();
}

class _ListeningSummaryScreenState
    extends ConsumerState<ListeningSummaryScreen> {
  late LiveSession _session = widget.session;
  late var _saved = widget.saved;
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
    if (_place == null && _saved) unawaited(_resolvePlace());
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    final session = _session;
    ListeningSummary summary;
    try {
      // An unsaved session stays out of the index: nothing counts yet.
      summary =
          _saved
              ? await ref.read(listeningSummaryLoaderProvider)(session)
              : ListeningSummary.of(
                session,
                verifiedBefore: {
                  for (final d in session.detections) d.scientificName,
                },
              );
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
    if (!_saved) {
      // The review may have saved it meanwhile.
      if (saved == null) return;
      _saved = true;
    }
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

  void _close() {
    final navigator = Navigator.of(context);
    if (widget.fromLive) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      navigator.pop();
    }
  }

  void _done() {
    if (_saving) return;
    if (_saved) {
      _close();
    } else {
      unawaited(_confirmLeaveUnsaved());
    }
  }

  /// Same choice as the session review's exit for a never-saved session.
  Future<void> _confirmLeaveUnsaved() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.forkSummaryUnsavedTitle),
            content: Text(l10n.sessionUnsavedSession),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop('discard'),
                child: Text(l10n.sessionDiscard),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('save'),
                child: Text(l10n.sessionSave),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (result == 'save') {
      if (await _saveSession() && mounted) _close();
    } else if (result == 'discard') {
      // Never saved, but the recordings are on disk already.
      await ref.read(sessionRepositoryProvider).delete(_session.id);
      ref.invalidate(sessionListProvider);
      if (mounted) _close();
    }
  }

  /// Keeps an unsaved session: same write as the session review's save.
  Future<bool> _saveSession() async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await ref.read(sessionRepositoryProvider).save(_session);
      ref.invalidate(sessionListProvider);
      _saved = true;
      if (mounted) {
        await _load();
        if (_place == null && mounted) unawaited(_resolvePlace());
      }
      return true;
    } catch (error) {
      debugPrint('Could not save the listening: $error');
      if (mounted) _showSaveFailure();
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        // The quick review reads the index and the edits below write the
        // session: none of them before it is saved.
        onCheck:
            _saving || !_saved
                ? null
                : (keys) => _push(QuickReviewScreen(onlyKeys: keys)),
        onDetails:
            _saving
                ? null
                : () => _push(
                  SessionReviewScreen(session: _session, autoSaved: _saved),
                ),
        onAddObservation:
            summary.isRecording || _saving || !_saved ? null : _addObservation,
        savingObservation: _savingObservation,
        // A file analysis never counts: nothing to mark.
        onMarkRecording:
            _session.type == SessionType.fileUpload || _saving || !_saved
                ? null
                : _markRecording,
        notice:
            _saved
                ? null
                : UnsavedListeningNotice(
                  onSave: _saving ? null : () => unawaited(_saveSession()),
                ),
        // A recording is not an observation (J5c): nothing to send.
        onSendToFauneFrance:
            _saved && countsAsObservation(_session)
                ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LpoSendScreen(session: _session),
                  ),
                )
                : null,
      ),
    );
  }
}
